# Where to pick this up

Last touched **26 September 2026**. Everything in the code is done and tested; what
is left is registration work in Google's console and one purchase, none of which can
be done from here.

## The state of it

Datebook syncs Google Calendar both ways at **one button press** — CALENDARS → SYNC
WITH GOOGLE CALENDAR. No API keys, no Cloud project for the user: the OAuth client is
the plugin's, shipped in `google-app.json`.

**`google-app.json` is empty**, so right now the CALENDARS page says this build has no
Google client and offers no button. That is deliberate and honest, not a bug. Fill it
in and the button appears.

Everything was verified against a stubbed `bin/gcal` — all four page states, connect,
auto-adding the primary calendar, colour allocation, read-only calendars, disconnect.
**It has still never talked to real Google.** That is the first thing below.

## Next actions, in order

### 1. Make it work (about an hour, do this first)

You need a working flow before anything else, because the demo video in step 4 is a
recording of it.

- [ ] Cloud console: new project `Datebook`, enable the **Google Calendar API**
- [ ] OAuth consent screen: External, app name `Datebook`, your email twice
- [ ] Credentials → OAuth client ID → **Desktop app**
- [ ] `bin/set-google-client '<id>.apps.googleusercontent.com' 'GOCSPX-<secret>'`
      (or `--from ~/Downloads/client_secret_*.json`)
- [ ] `bin/gcal connect` — real browser, real Google, first time ever
- [ ] Open the popup → CALENDARS, confirm your calendars list and sync
- [ ] **Publish app → In production.** Not optional: in *Testing* Google expires
      refresh tokens after seven days and sync breaks weekly
- [ ] Commit `google-app.json` with the values in it

At this point it works for anyone, behind Google's "hasn't verified this app" screen.
Shippable if you are willing to document that.

### 2. Buy the domain

You chose a new domain over `javel.dk` and `neaxic.github.io`. Nothing else in step 3
can start until it exists.

- [ ] Register it
- [ ] `cd site && ./configure <domain> <contact-email>`
- [ ] Deploy `site/` so `https://<domain>/` and `https://<domain>/privacy/` both load
      (see `site/README.md` — static, no build step)

### 3. Two things only you can make

- [ ] **A logo.** Square PNG, 120×120 or larger, for the consent screen. Not written.
- [ ] **Decide the public contact address.** The site currently has the literal
      placeholder `CONTACT_EMAIL`; `site/configure` replaces it.

### 4. Submit for verification

Full walkthrough with the exact field values and the text to paste:
**[docs/google-verification.md](docs/google-verification.md)**. The short of it:

- [ ] Verify the domain in **Search Console**, using the same Google account that owns
      the Cloud project. This is the step people forget and submissions bounce on
- [ ] Branding: name, logo, homepage, privacy link, authorized domain
- [ ] Data Access: exactly the two scopes, nothing more
- [ ] **Record the demo video**, unlisted on YouTube. The part most first submissions
      fail is showing each scope *being used* — not just the sign-in. Shot list is in
      the doc
- [ ] Paste the scope justifications from the doc, submit
- [ ] Wait. Google quotes 3–5 business days; calendar scopes often run to weeks. Do
      not change scopes, app name or domain mid-review — it restarts

> Record the video on a clean desktop. It goes to Google.

## Housekeeping, whenever

- [ ] `rm ~/.config/datebook/events.json` — the store still holds the eight demo
      events added to photograph the grid; the service writes a fresh empty one
- [ ] Not built, if you ever want them: notifications before an event, editing a
      single occurrence of a repeat, repeats on a synced calendar, a general settings
      page, any provider other than Google

## Gotchas that cost time last session

- **Nothing hot-reloads.** The shell logs "Local plugin changed, reloading" and then
  renders a blank page from stale QML. `omarchy restart shell` before believing any
  visual bug.
- Driving the popup for screenshots: `omarchy-shell datebook toggle`, then
  `page month|year|detail <id>|compose|calendars`. Check it actually opened with
  `hyprctl layers | grep "namespace: omarchy-keyboard-panel,"` — a bare `toggle`
  closes it if it was already open, which silently gives you a blank capture.
