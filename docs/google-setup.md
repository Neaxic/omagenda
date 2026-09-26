# Connecting Google Calendar

Datebook talks to Google directly, two-way: your Google events show in the bar,
and events you create here land in Google. That needs an OAuth client, which
Google only issues per project — so there is a one-off setup in the Cloud
console. It takes about five minutes and you never have to touch it again.

Nothing here costs money: the Calendar API is free at this volume.

## 1. A project with the Calendar API on

1. Open <https://console.cloud.google.com/> and create a project — call it
   `Datebook`, the name only ever shows on the consent screen.
2. **APIs & Services → Library**, search *Google Calendar API*, press **Enable**.

## 2. The consent screen, published

**APIs & Services → OAuth consent screen**

1. User type **External**, then fill in the app name, your email as both the
   support and developer contact. Nothing else is required.
2. **Publish the app** — move it from *Testing* to *In production*.

That second step is the one that matters. A consent screen left in *Testing*
issues refresh tokens that **expire after seven days**, so sync would quietly
stop every week and you would have to sign in again. Published, they last until
you revoke them.

You do **not** need Google's verification review. An unverified app still works
for its own author; it just shows a warning screen the first time you sign in
(*"Google hasn't verified this app" → Advanced → Go to Datebook*). Verification
only matters for shipping an app to strangers.

## 3. A desktop OAuth client

**APIs & Services → Credentials → Create credentials → OAuth client ID**

- Application type: **Desktop app**
- Name: `Datebook`

Copy the client ID and client secret, and write them to
`~/.config/datebook/google-client.json`:

```json
{
  "client_id": "1234567890-abcdefg.apps.googleusercontent.com",
  "client_secret": "GOCSPX-xxxxxxxxxxxxxxxx"
}
```

The JSON the console offers for download works as-is too — save it under that
name and the `installed` wrapper is understood.

A desktop client's secret is not really a secret (it ships inside every copy of
such an app), but the file is still written and read at `0600`, as are the
tokens beside it.

## 4. Sign in

```bash
~/.config/omarchy/plugins/datebook/bin/gcal login
```

A browser opens, you allow the two scopes, and the tab says it is done. The
tokens land in `~/.config/datebook/google-tokens.json` (`0600`).

The scopes asked for are deliberately narrow:

| Scope | What it allows |
|---|---|
| `calendar.events` | read and write events on your calendars |
| `calendar.calendarlist.readonly` | see which calendars exist |

Not the blanket `calendar` scope: Datebook cannot create, rename or delete a
calendar, only the events inside one.

## 5. Add the calendars you want

```bash
bin/gcal calendars                       # ids, names and access roles
omarchy-shell datebook sourceAdd "you@gmail.com" "Personal" sky
omarchy-shell datebook sourceAdd "family123@group.calendar.google.com" "Family" moss
omarchy-shell datebook sync true
```

The third argument is the colour its events take (`clay`, `sand`, `moss`, `sky`,
`slate`, `plum`) unless an event sets its own — which is the usual calendar
convention: colour tells you *which calendar*.

Each calendar becomes a source in `~/.config/datebook/sources.json`, and its
events are cached in `cache.json` beside it. The cache is never merged into your
local `events.json`: a sync cannot touch what you wrote locally, and editing a
local event cannot touch Google.

## How syncing behaves

- Every ten minutes, and on demand with `omarchy-shell datebook sync`.
- Incremental: Google is asked only for what changed since the last pass, using
  the sync token it hands back. When a token gets too old Google says so, and
  Datebook silently retakes that calendar in full.
- The first pass asks for a window — 120 days back, 400 forward — rather than
  your entire history.
- Recurring Google events arrive already expanded into instances, so a Google
  rule Datebook could not model still shows up correctly.
- Writes go straight to Google and the affected calendar is re-synced right
  after, so what you see is what Google stored.

## Turning it off

```bash
omarchy-shell datebook sourceRemove google:you@gmail.com   # one calendar
bin/gcal logout                                            # forget and revoke the tokens
```

`logout` also revokes the grant at Google's end. You can double-check at
<https://myaccount.google.com/permissions>.

## When something breaks

| What you see | What it means |
|---|---|
| `not signed in: run gcal login` | no tokens yet, or `logout` was run |
| `Google rejected the refresh token` | the consent screen is still in *Testing* (step 2), or access was revoked |
| `no client credentials` | `google-client.json` missing or empty (step 3) |
| `Google API 403` | the Calendar API is not enabled on the project (step 1) |

`omarchy-shell datebook syncStatus` prints the last error, when the last pass
finished and how many calendars are configured.
