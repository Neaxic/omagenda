# Google Calendar

Two-way: your Google events show in the bar, and events you create here land in
Google.

## If you are using Omagenda

Open the popup, press **SETTINGS**, then **Calendars**, then **SYNC WITH GOOGLE CALENDAR**.

Your browser opens once, you allow it, and your primary calendar starts syncing.
Any other calendar on the account — shared ones, a partner's, a team's — is a row
on the same page; click it to add or drop it. Each gets its own colour.

There is nothing to copy and no key to find. Omagenda's own OAuth client ships
inside the plugin, so the Google project is the plugin's, not yours.

Two things worth knowing:

- **Google may warn you.** Until Google has finished reviewing the app
  registration, consent is fronted by *"Google hasn't verified this app"*. Choose
  **Advanced → Go to Omagenda**. That screen is about the registration's review
  status, not about anything Omagenda does.
- **What it asks for.** `calendar.events` (read and write events) and
  `calendar.calendarlist.readonly` (see which calendars exist). Not the blanket
  `calendar` scope: Omagenda cannot create, rename or delete a calendar, only the
  events inside one. Revoke any time from the page's **DISCONNECT**, or at
  <https://myaccount.google.com/permissions>.

Tokens are stored at `~/.config/omagenda/google-tokens.json`, `0600`. They never
leave the machine — there is no Omagenda server in the path, the plugin talks to
Google directly.

## If you are shipping Omagenda

`google-app.json` in the plugin root carries Omagenda's own client, so a clone syncs
out of the box. If you clear it (`bin/set-google-client --clear`), the calendars page
says the build has no Google client and offers no button — which is the honest state,
not a bug.

That client is registered and published, so sync works today. What is *not* done is
Google's verification review, which is what removes the "hasn't verified this app"
screen and the 100-account cap. It is walked start to finish, with the exact field
values and the text to paste into the submission, in
**[google-verification.md](google-verification.md)**.

The short form:

```bash
# console: new project, enable the Calendar API, create a Desktop OAuth client
bin/set-google-client '<id>.apps.googleusercontent.com' 'GOCSPX-<secret>'
bin/gcal status        # clientOrigin: builtin
bin/gcal connect       # browser consent, then the calendar list
```

Then **publish the consent screen to In production** — in *Testing*, Google expires
refresh tokens after seven days, so sync would break every week.

Commit `google-app.json` once it is filled in. A client shipped inside a desktop app is
not a secret — anyone can read it out of the package — and [RFC 8252
§8.5](https://datatracker.ietf.org/doc/html/rfc8252#section-8.5) says to expect exactly
that, which is why Google's *Desktop app* type exists and why PKCE is mandatory here.
The verifier, generated fresh per login and never stored, is what stops a stolen
authorization code from being redeemed.

## Bringing your own client

Anyone who would rather answer to their own Cloud project can. Make a project with
the Calendar API on and a **Desktop app** OAuth client — the first half of
[google-verification.md](google-verification.md) — then write the credentials to
`~/.config/omagenda/google-client.json`:

```json
{
  "client_id": "…",
  "client_secret": "…"
}
```

The file the console offers for download works as-is — save it under that name
and the `installed` wrapper is understood. It takes precedence over the shipped
client, and the calendars page then says *your own Google project*.

For a one-off or for testing, the environment wins over both:

```bash
OMAGENDA_GOOGLE_CLIENT_ID=… OMAGENDA_GOOGLE_CLIENT_SECRET=… bin/gcal status
```

A client of your own is in Testing mode unless you publish it, so **publish the
consent screen to In production** — in Testing, Google expires the refresh token
after seven days and sync stops weekly. Verification you do not need: an
unverified app still works for its own author, warning screen and all.

## The CLI, for scripting and debugging

```bash
bin/gcal status              # is there a client, where from, and a live grant?
bin/gcal connect             # consent if needed, then the calendar list
bin/gcal calendars           # ids, names, access roles
bin/gcal logout              # forget and revoke
```

and from the shell:

```bash
omarchy-shell omagenda connect
omarchy-shell omagenda calendarToggle "family123@group.calendar.google.com"
omarchy-shell omagenda sourceColor "google:you@gmail.com" moss
omarchy-shell omagenda sync true       # true = ignore sync tokens, take it all again
omarchy-shell omagenda syncStatus
omarchy-shell omagenda disconnect
```

## How syncing behaves

- Every ten minutes, and on demand from **SYNC NOW**.
- Incremental: Google is asked only for what changed, using the sync token it
  hands back. When a token gets too old Google says so, and Omagenda silently
  retakes that calendar in full.
- The first pass asks for a window — 120 days back, 400 forward — not your whole
  history.
- Recurring Google events arrive already expanded into instances, so a rule
  Omagenda could not model still shows up correctly.
- Writes go straight to Google and the affected calendar is re-synced right
  after, so what you see is what Google stored.
- Synced events are cached in `~/.config/omagenda/cache.json` and merged only for
  display. A sync cannot touch your local `events.json`, and a local edit cannot
  touch Google.

## When something breaks

| What you see | What it means |
|---|---|
| *This build has no Google client* | `google-app.json` is empty and you have no client of your own |
| `not signed in` | no tokens yet, or DISCONNECT was pressed |
| `Google rejected the refresh token` | the consent screen is in *Testing* (7-day tokens), or access was revoked |
| `Google API 403` | the Calendar API is not enabled on the project |
| *the browser never came back* | the consent tab was closed, or 5 minutes passed |

`omarchy-shell omagenda syncStatus` prints the last error, when the last pass
finished, and how many calendars are configured.
