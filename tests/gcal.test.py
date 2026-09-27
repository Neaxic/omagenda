#!/usr/bin/env python3
"""Ceilings on what bin/gcal will read from Google.

Run with `python3 tests/gcal.test.py` — stdlib only, like the helper itself.

The interesting case is not a well-behaved calendar; it is one shared with the
user by someone else, as large as that person cared to make it. These tests pin
the ceilings that keep such a calendar from growing the helper and the shell
that collects its output, and the local server below stands in for Google so
they can run offline.
"""

import http.server
import importlib.util
import io
import json
import os
import socketserver
import sys
import threading
import time
import unittest
from importlib.machinery import SourceFileLoader

# bin/gcal has no .py suffix, so it is loaded by path rather than imported.
HELPER = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                      "bin", "gcal")
_loader = SourceFileLoader("gcal", HELPER)
gcal = importlib.util.module_from_spec(importlib.util.spec_from_loader("gcal", _loader))
_loader.exec_module(gcal)


def refusal(call):
    """Run `call`, returning (exit code, the JSON die() printed).

    Every ceiling reports itself the way every other failure does — a JSON
    object on stdout and a non-zero exit — because that is all the QML side
    knows how to read.
    """
    buffer = io.StringIO()
    saved, sys.stdout = sys.stdout, buffer
    try:
        call()
        return 0, None
    except SystemExit as exc:
        printed = buffer.getvalue().strip().splitlines()
        return exc.code, json.loads(printed[-1]) if printed else None
    finally:
        sys.stdout = saved


class ReadCapped(unittest.TestCase):
    def test_reads_up_to_the_ceiling(self):
        self.assertEqual(gcal.read_capped(io.BytesIO(b"x" * 10), 100), b"x" * 10)
        # Exactly at the limit is a complete body, not a truncated one.
        self.assertEqual(gcal.read_capped(io.BytesIO(b"x" * 100), 100), b"x" * 100)

    def test_one_byte_over_is_refused(self):
        code, payload = refusal(lambda: gcal.read_capped(io.BytesIO(b"x" * 101), 100))
        self.assertEqual(code, 7)
        self.assertTrue(payload["oversize"])
        self.assertIn("larger than", payload["error"])

    def test_the_budget_is_charged_for_what_was_read(self):
        budget = gcal.Budget("that calendar")
        gcal.read_capped(io.BytesIO(b"x" * 64), 100, budget)
        self.assertEqual(budget.spent, 64)


class BudgetCeilings(unittest.TestCase):
    def test_page_count(self):
        budget = gcal.Budget("that calendar", max_pages=3)
        for _ in range(3):
            budget.page(0)
        code, payload = refusal(lambda: budget.page(0))
        self.assertEqual(code, 7)
        self.assertIn("pages", payload["error"])

    def test_items_held(self):
        budget = gcal.Budget("that calendar", max_items=5)
        budget.page(4)
        code, payload = refusal(lambda: budget.page(5))
        self.assertEqual(code, 7)
        self.assertIn("entries", payload["error"])

    def test_bytes_add_up_across_pages(self):
        # The point of a shared budget: each reply can sit under the per-reply
        # ceiling and still come to more than we will hold.
        budget = gcal.Budget("that calendar", max_bytes=100)
        budget.spend(60)
        code, payload = refusal(lambda: budget.spend(60))
        self.assertEqual(code, 7)
        self.assertIn("data", payload["error"])

    def test_the_walk_has_a_deadline(self):
        # urlopen's timeout bounds one request; this bounds the whole walk.
        budget = gcal.Budget("that calendar", seconds=0)
        time.sleep(0.01)
        code, payload = refusal(lambda: budget.page(0))
        self.assertEqual(code, 7)
        self.assertIn("longer", payload["error"])

    def test_a_refusal_says_the_store_was_left_alone(self):
        budget = gcal.Budget("that calendar")
        _, payload = refusal(lambda: budget.stop("went too far"))
        self.assertIn("Nothing was saved", payload["error"])


class FakeGoogle(http.server.BaseHTTPRequestHandler):
    """Serves whatever `FakeGoogle.page` currently holds, forever."""

    page = b"{}"

    def do_GET(self):  # noqa: N802 - http.server's naming
        body = FakeGoogle.page
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


class Pagination(unittest.TestCase):
    """events() against a server that always offers one more page."""

    @classmethod
    def setUpClass(cls):
        cls.server = socketserver.TCPServer(("127.0.0.1", 0), FakeGoogle)
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()
        cls.api, cls.token = gcal.API, gcal.access_token
        gcal.API = "http://127.0.0.1:%d" % cls.server.server_address[1]
        # No token file in a test run, and no request here needs a real one.
        gcal.access_token = lambda: "test-token"

    @classmethod
    def tearDownClass(cls):
        gcal.API, gcal.access_token = cls.api, cls.token
        cls.server.shutdown()
        cls.server.server_close()

    def sync(self):
        return gcal.events("primary", time_min="2026-01-01T00:00:00Z",
                           time_max="2027-01-01T00:00:00Z")

    def test_an_endless_calendar_is_refused_rather_than_accumulated(self):
        FakeGoogle.page = json.dumps({
            "items": [{"id": "e%d" % n, "summary": "x" * 200} for n in range(2500)],
            "nextPageToken": "more",
        }).encode()
        code, payload = refusal(self.sync)
        self.assertEqual(code, 7)
        self.assertTrue(payload["oversize"])
        # Refused for holding too much, which is the ceiling that should bite
        # first on a calendar of ordinary-looking events.
        self.assertIn("entries", payload["error"])

    def test_a_single_huge_page_is_refused_by_the_per_reply_ceiling(self):
        FakeGoogle.page = json.dumps({
            "items": [{"id": "big", "description": "x" * (2 * 1024 * 1024)}],
        }).encode()
        gcal.MAX_RESPONSE_BYTES, saved = 1024 * 1024, gcal.MAX_RESPONSE_BYTES
        try:
            code, payload = refusal(self.sync)
        finally:
            gcal.MAX_RESPONSE_BYTES = saved
        self.assertEqual(code, 7)
        self.assertIn("larger than", payload["error"])

    def test_a_calendar_that_fits_still_comes_back_whole(self):
        FakeGoogle.page = json.dumps({
            "items": [{"id": "a"}, {"id": "b"}], "nextSyncToken": "tok",
        }).encode()
        buffer = io.StringIO()
        saved, sys.stdout = sys.stdout, buffer
        try:
            self.sync()
        finally:
            sys.stdout = saved
        emitted = json.loads(buffer.getvalue())
        self.assertEqual([item["id"] for item in emitted["items"]], ["a", "b"])
        self.assertEqual(emitted["syncToken"], "tok")


if __name__ == "__main__":
    unittest.main(verbosity=2)
