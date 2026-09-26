# Where to pick this up

Last touched **27 September 2026**. Google sync works against real Google, on a
published client. What is left is Google's verification review, which removes the
warning screen and the 100-account cap — and the release itself.

## The state of it

Datebook syncs Google Calendar both ways at **one button press** — CALENDARS → SYNC
WITH GOOGLE CALENDAR. No API keys, no Cloud project for the user: the OAuth client is
the plugin's, shipped in `google-app.json`.

**It has talked to real Google**, on this machine, with three calendars syncing (one
writable, two read-only). The consent screen is **published to In production**, so
refresh tokens last instead of dying every seven days.

Everything below is optional in the sense that the plugin works without it. None of
it is optional if Datebook gets popular.

## 1. Release to omarchyplugins

- [ ] Merge `google-one-press` into `main`
- [ ] Make the repo public
- [ ] Submit to the omarchyplugins listing

The README now states the warning screen and the cap up front, so nobody meets them
as a surprise. Anyone who objects to the shipped client can point
`~/.config/datebook/google-client.json` at their own and is then exempt from both.

## 2. Watch the 100-account cap

This is the real ceiling, and it is **counted over the project's lifetime and cannot
be reset**. Account 101 simply cannot connect. Verification lifts it retroactively, so
nothing is lost by deferring — but start well before you are near it, because the
review runs to weeks.

There is no counter in the Cloud console that shows this directly; watch installs and
issue reports.

## 3. Verification, when it is worth it

Full walkthrough with the exact field values and the text to paste:
**[docs/google-verification.md](docs/google-verification.md)**. What it needs:

- [ ] **Deploy [gaard.dev](https://gaard.dev)** — homepage and `/privacy/` must both
      load. The pages are written; `site/` moved out to its own repo
- [ ] Verify the domain in **Search Console**, using the same Google account that owns
      the Cloud project. This is the step people forget and submissions bounce on
- [ ] **A logo.** Square PNG, 120x120 or larger, for the consent screen
- [ ] Branding: name, logo, homepage, privacy link, authorized domain
- [ ] Data Access: exactly the two scopes, nothing more
- [ ] **Record the demo video**, unlisted on YouTube. The part most first submissions
      fail is showing each scope *being used* — not just the sign-in. Shot list is in
      the doc. Record it on a clean desktop; it goes to Google
- [ ] Paste the scope justifications from the doc, submit
- [ ] Wait. Google quotes 3-5 business days; calendar scopes often run to weeks. Do
      not change scopes, app name or domain mid-review — it restarts

## Not built, if you ever want them

Notifications before an event, editing a single occurrence of a repeat, repeats on a
synced calendar, a general settings page, any provider other than Google.

## Gotchas that cost time

- **Nothing hot-reloads.** The shell logs "Local plugin changed, reloading" and then
  renders a blank page from stale QML. `omarchy restart shell` before believing any
  visual bug.
- Driving the popup for screenshots: `omarchy-shell datebook toggle`, then
  `page month|year|detail <id>|compose|calendars`. Check it actually opened with
  `hyprctl layers | grep "namespace: omarchy-keyboard-panel,"` — a bare `toggle`
  closes it if it was already open, which silently gives you a blank capture.
- `bin/gcal connect` blocks for five minutes waiting on the loopback callback, and
  each run mints a fresh port and PKCE verifier. Run it when you are actually at the
  browser; a stale URL from an earlier run is dead.
