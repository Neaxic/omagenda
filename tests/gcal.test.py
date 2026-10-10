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
import urllib.error
import urllib.parse
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


def printed(call):
    """Run `call`, returning the JSON it emitted on the way out."""
    buffer = io.StringIO()
    saved, sys.stdout = sys.stdout, buffer
    try:
        call()
    finally:
        sys.stdout = saved
    lines = buffer.getvalue().strip().splitlines()
    return json.loads(lines[-1]) if lines else None


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

    def test_a_trickling_reply_runs_out_of_clock(self):
        """A reply that never stalls long enough to time out, but never ends.

        This is the case a socket timeout cannot catch: every chunk arrives
        well inside it, so the far end can hold the read open for as long as it
        keeps dribbling. The walk's deadline has to be what stops it.
        """
        budget = gcal.Budget("that calendar", max_bytes=1 << 30, seconds=0)
        code, payload = refusal(
            lambda: gcal.read_capped(Trickle(), 1 << 20, budget))
        self.assertEqual(code, 7)
        self.assertIn("longer to read", payload["error"])
        # Stopped partway, not after swallowing the whole megabyte.
        self.assertLessEqual(Trickle.served, gcal.READ_CHUNK)

    def test_a_trickling_reply_is_bounded_without_a_budget_too(self):
        # The token endpoint reads with no walk behind it, so it carries its
        # own clock rather than none at all.
        code, payload = refusal(
            lambda: gcal.read_capped(Trickle(), 1 << 20, seconds=0))
        self.assertEqual(code, 7)
        self.assertIn("longer to read", payload["error"])

    def test_a_real_socket_trickle_is_stopped_on_time(self):
        """The same over HTTP, where a buffered read would wait out the chunk.

        One byte every 0.1 s never trips the socket timeout. The clock must
        stop it near its one second, not once 64 KB has dribbled in.
        """
        import socket
        import urllib.request
        listener = socket.socket()
        listener.bind(("127.0.0.1", 0))
        listener.listen(1)
        done = threading.Event()

        def serve():
            conn, _ = listener.accept()
            conn.recv(4096)
            conn.sendall(b"HTTP/1.1 200 OK\r\nContent-Length: 1000000\r\n\r\n")
            try:
                while not done.is_set():
                    conn.sendall(b"x")
                    time.sleep(0.1)
            except OSError:
                pass
            finally:
                conn.close()

        threading.Thread(target=serve, daemon=True).start()
        try:
            reply = urllib.request.urlopen(
                "http://127.0.0.1:%d/" % listener.getsockname()[1], timeout=45)
            started = time.monotonic()
            code, payload = refusal(lambda: gcal.read_capped(reply, 1 << 20, seconds=1))
            took = time.monotonic() - started
        finally:
            done.set()
            listener.close()
        self.assertEqual(code, 7)
        self.assertIn("longer to read", payload["error"])
        self.assertLess(took, 2)

    def test_a_chunked_read_still_returns_the_whole_body(self):
        # The body is now taken in pieces; it must come back joined and intact.
        body = bytes(range(256)) * ((gcal.READ_CHUNK // 256) * 3)
        self.assertEqual(gcal.read_capped(io.BytesIO(body), len(body)), body)


class Trickle:
    """A stream that always has one more chunk and never finishes."""

    served = 0

    def __init__(self):
        Trickle.served = 0

    def read(self, size):
        Trickle.served += size
        return b"x" * size


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


class ConfigDir(unittest.TestCase):
    """The directory everything private lands in, whoever creates it first."""

    def setUp(self):
        import tempfile
        self.root = tempfile.mkdtemp()
        self.saved = gcal.CONFIG_DIR, gcal.TOKEN_FILE
        gcal.CONFIG_DIR = os.path.join(self.root, "omagenda")
        gcal.TOKEN_FILE = os.path.join(gcal.CONFIG_DIR, "google-tokens.json")
        self.umask = os.umask(0o022)

    def tearDown(self):
        import shutil
        os.umask(self.umask)
        gcal.CONFIG_DIR, gcal.TOKEN_FILE = self.saved
        shutil.rmtree(self.root)

    def mode(self, path):
        return os.stat(path).st_mode & 0o777

    def test_created_private_under_an_ordinary_umask(self):
        gcal.write_private(gcal.TOKEN_FILE, {"refresh_token": "r"})
        self.assertEqual(self.mode(gcal.CONFIG_DIR), 0o700)
        self.assertEqual(self.mode(gcal.TOKEN_FILE), 0o600)

    def test_an_existing_open_directory_is_tightened(self):
        # `gcal connect` before the shell's first start, or an older build,
        # leaves a 0755 directory behind; mkdir -m would not touch it.
        os.makedirs(gcal.CONFIG_DIR, mode=0o755)
        os.chmod(gcal.CONFIG_DIR, 0o755)
        gcal.write_private(gcal.TOKEN_FILE, {"refresh_token": "r"})
        self.assertEqual(self.mode(gcal.CONFIG_DIR), 0o700)

    def test_concurrent_writers_never_collide(self):
        # Several helpers can refresh the token at once. Each must land a
        # whole file, and none may die on the other's temp file.
        failures = []

        def writer(n):
            for _ in range(200):
                try:
                    gcal.write_private(gcal.TOKEN_FILE, {"refresh_token": "r" * 4000, "n": n})
                except Exception as exc:  # noqa: BLE001 - any failure is the bug
                    failures.append(exc)

        threads = [threading.Thread(target=writer, args=(n,)) for n in range(4)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join()
        self.assertEqual(failures, [])
        with open(gcal.TOKEN_FILE, encoding="utf-8") as handle:
            self.assertEqual(json.load(handle)["refresh_token"], "r" * 4000)
        self.assertEqual(self.mode(gcal.TOKEN_FILE), 0o600)
        # Nothing left lying about next to it.
        self.assertEqual(os.listdir(gcal.CONFIG_DIR), ["google-tokens.json"])

    def test_logout_forgets_the_tokens_even_offline(self):
        gcal.write_private(gcal.TOKEN_FILE, {"refresh_token": "r"})
        saved = gcal.REVOKE_URL
        # A closed port: the revoke cannot reach anyone.
        gcal.REVOKE_URL = "http://127.0.0.1:9/revoke"
        try:
            out = printed(gcal.logout)
        finally:
            gcal.REVOKE_URL = saved
        self.assertFalse(os.path.exists(gcal.TOKEN_FILE))
        self.assertEqual(out, {"ok": True, "revoked": False})

    def test_logout_clears_an_unreadable_token_file(self):
        gcal.ensure_config_dir()
        with open(gcal.TOKEN_FILE, "w", encoding="utf-8") as handle:
            handle.write("{not json")
        out = printed(gcal.logout)
        self.assertFalse(os.path.exists(gcal.TOKEN_FILE))
        self.assertTrue(out["ok"])


class Callback(unittest.TestCase):
    """The loopback the browser is redirected to during login."""

    def setUp(self):
        self.saved = gcal.CallbackHandler.timeout
        gcal.CallbackHandler.timeout = 0.5
        gcal.CallbackHandler.expected_state = "the-state"
        gcal.CallbackHandler.result = {}
        self.server = socketserver.TCPServer(("127.0.0.1", 0), gcal.CallbackHandler)
        self.port = self.server.server_address[1]
        self.waiter = threading.Thread(
            target=gcal.wait_for_callback, args=(self.server, 10), daemon=True)
        self.waiter.start()

    def tearDown(self):
        gcal.CallbackHandler.timeout = self.saved
        gcal.CallbackHandler.result = {"code": "stop"}
        self.waiter.join(timeout=5)
        self.server.server_close()

    def get(self, query):
        import urllib.request
        try:
            with urllib.request.urlopen("http://127.0.0.1:%d/?%s" % (self.port, query),
                                        timeout=5) as reply:
                return reply.status, reply.read().decode()
        except urllib.error.HTTPError as exc:
            return exc.code, ""

    def test_strays_do_not_end_the_wait(self):
        import socket
        # A connection that never speaks, then requests without the state.
        silent = socket.create_connection(("127.0.0.1", self.port))
        try:
            self.assertEqual(self.get("")[0], 404)
            self.assertEqual(self.get("code=forged&state=wrong")[0], 404)
            self.assertEqual(gcal.CallbackHandler.result, {})
            status, _ = self.get("code=real&state=the-state")
        finally:
            silent.close()
        self.assertEqual(status, 200)
        self.waiter.join(timeout=5)
        self.assertFalse(self.waiter.is_alive())
        self.assertEqual(gcal.CallbackHandler.result["code"], "real")

    def test_the_error_is_shown_as_text(self):
        status, body = self.get("state=the-state&error=" +
                                urllib.parse.quote("<script>alert(1)</script>"))
        self.assertEqual(status, 200)
        self.assertNotIn("<script>", body)
        self.assertIn("&lt;script&gt;", body)


class FakeGoogle(http.server.BaseHTTPRequestHandler):
    """Serves whatever `FakeGoogle.page` currently holds, forever.

    `reject_next` makes it answer 401 once first, the way Google answers a
    token it has stopped honouring.
    """

    page = b"{}"
    reject_next = 0
    requests = 0

    def do_GET(self):  # noqa: N802 - http.server's naming
        FakeGoogle.requests += 1
        if FakeGoogle.reject_next > 0:
            FakeGoogle.reject_next -= 1
            body = json.dumps({"error": {"code": 401, "message": "Invalid Credentials"}}).encode()
            self.send_response(401)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
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
        cls.forced = []
        gcal.access_token = lambda force=False: (cls.forced.append(force) or "test-token")

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

    def test_a_rejected_token_is_refreshed_and_the_request_retried(self):
        """The case a wrong clock creates: a live-looking token Google refuses.

        `expires_at` is wall clock, so an ntp step backwards leaves a dead
        token looking valid. One forced refresh has to rescue it, or sync stays
        broken until the clock catches up.
        """
        FakeGoogle.page = json.dumps({"items": [{"id": "e1", "summary": "Lunch"}]}).encode()
        FakeGoogle.requests = 0
        type(self).forced = []
        FakeGoogle.reject_next = 1
        out = printed(self.sync)
        self.assertEqual([e["id"] for e in out["items"]], ["e1"])
        # Asked twice: once with the stale token, once with a forced refresh.
        self.assertEqual(FakeGoogle.requests, 2)
        self.assertIn(True, type(self).forced)

    def test_a_second_rejection_is_reported_rather_than_looped_on(self):
        FakeGoogle.page = json.dumps({"items": []}).encode()
        FakeGoogle.requests = 0
        FakeGoogle.reject_next = 2
        code, payload = refusal(self.sync)
        self.assertNotEqual(code, 0)
        self.assertIn("401", payload["error"])
        self.assertEqual(FakeGoogle.requests, 2)

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


class Recorder(http.server.BaseHTTPRequestHandler):
    """Records every request; answers with `Recorder.status` and `Recorder.reply`."""

    seen = []
    status = 200
    reply = {}

    def answer(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else b""
        Recorder.seen.append({
            "method": self.command, "path": self.path,
            "if_match": self.headers.get("If-Match"),
            "body": json.loads(body) if body else None,
        })
        out = json.dumps(Recorder.reply).encode()
        self.send_response(Recorder.status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out)))
        self.end_headers()
        self.wfile.write(out)

    do_GET = do_POST = do_PATCH = do_DELETE = answer  # noqa: N815

    def log_message(self, *args):
        pass


class Requests(unittest.TestCase):
    """The "-" forms the plugin uses: everything on stdin, nothing in argv."""

    @classmethod
    def setUpClass(cls):
        cls.server = socketserver.TCPServer(("127.0.0.1", 0), Recorder)
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()
        cls.api, cls.token = gcal.API, gcal.access_token
        gcal.API = "http://127.0.0.1:%d" % cls.server.server_address[1]
        gcal.access_token = lambda force=False: "test-token"

    @classmethod
    def tearDownClass(cls):
        gcal.API, gcal.access_token = cls.api, cls.token
        cls.server.shutdown()
        cls.server.server_close()

    def setUp(self):
        Recorder.seen, Recorder.status, Recorder.reply = [], 200, {}

    def run_gcal(self, command, request):
        saved = sys.stdin
        sys.stdin = io.StringIO(json.dumps(request))
        try:
            return refusal(lambda: gcal.main(["gcal", command, "-"]))
        finally:
            sys.stdin = saved

    def test_events_takes_the_calendar_and_token_off_stdin(self):
        Recorder.reply = {"items": [], "nextSyncToken": "next"}
        self.run_gcal("events", {"calendarId": "me@example.com", "syncToken": "tok"})
        path = Recorder.seen[0]["path"]
        self.assertTrue(path.startswith("/calendars/me%40example.com/events?"))
        self.assertIn("syncToken=tok", path)

    def test_events_takes_a_window_when_there_is_no_token(self):
        Recorder.reply = {"items": []}
        self.run_gcal("events", {"calendarId": "c", "from": "2026-01-01T00:00:00Z",
                                 "to": "2027-01-01T00:00:00Z"})
        self.assertIn("timeMin=2026-01-01", Recorder.seen[0]["path"])

    def test_insert_patch_and_delete(self):
        self.run_gcal("insert", {"calendarId": "c", "body": {"summary": "Lunch"}})
        self.run_gcal("patch", {"calendarId": "c", "eventId": "e1", "body": {"summary": "Tea"}})
        self.run_gcal("delete", {"calendarId": "c", "eventId": "e1"})
        self.assertEqual([(r["method"], r["path"]) for r in Recorder.seen], [
            ("POST", "/calendars/c/events"),
            ("PATCH", "/calendars/c/events/e1"),
            ("DELETE", "/calendars/c/events/e1"),
        ])
        self.assertEqual(Recorder.seen[0]["body"], {"summary": "Lunch"})
        self.assertEqual(Recorder.seen[1]["body"], {"summary": "Tea"})

    def test_a_patch_carries_the_etag_it_was_based_on(self):
        self.run_gcal("patch", {"calendarId": "c", "eventId": "e1", "etag": '"v1"',
                                "body": {"summary": "Tea"}})
        self.assertEqual(Recorder.seen[0]["if_match"], '"v1"')

    def test_a_patch_over_a_newer_version_is_reported_as_a_conflict(self):
        Recorder.status = 412
        Recorder.reply = {"error": {"code": 412, "message": "Precondition Failed"}}
        code, payload = self.run_gcal("patch", {"calendarId": "c", "eventId": "e1",
                                                "etag": '"v1"', "body": {}})
        self.assertNotEqual(code, 0)
        self.assertTrue(payload["conflict"])
        self.assertIn("not saved", payload["error"])

    def test_an_id_with_a_slash_stays_one_segment(self):
        self.run_gcal("delete", {"calendarId": "a/../b", "eventId": "e"})
        self.assertEqual(Recorder.seen[0]["path"], "/calendars/a%2F..%2Fb/events/e")

    def test_a_malformed_request_is_refused_before_anything_is_sent(self):
        for request in ({}, {"calendarId": ""}, {"calendarId": "c"},
                        {"calendarId": "c", "eventId": "e", "body": "not an object"}):
            code, payload = self.run_gcal("patch", request)
            self.assertNotEqual(code, 0)
            self.assertIn("error", payload)
        self.assertEqual(Recorder.seen, [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
