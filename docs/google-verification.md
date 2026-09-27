# Getting Omagenda's Google client registered and verified

This is the one-off work that makes **SYNC WITH GOOGLE CALENDAR** work for everyone
else. Users do none of it. Do it once and it is done.

There are two finish lines, and the first one is much closer than the second:

1. **Working** — a client exists, you fill in `google-app.json`, sync works. An hour,
   most of it waiting for pages to load.
2. **Verified** — no scare screen, no user cap. Needs a domain, a site, a video and
   Google's review. Days to weeks, mostly waiting on them.

Do 1 first. You need a working flow anyway: the demo video for 2 is a recording of it.

> Google renames these console screens every so often. Where this says *APIs &
> Services → OAuth consent screen*, a newer console says *Google Auth Platform →
> Branding / Audience / Data Access*. Same settings, same order.

---

## Part 1 — Working (do this today)

### 1.1 A project with the Calendar API on

1. <https://console.cloud.google.com/> → **new project**, name it `Omagenda`. The name
   is what users see on the consent screen, so spell it the way you want it read.
2. **APIs & Services → Library** → search *Google Calendar API* → **Enable**.

Nothing here costs money. The Calendar API is free at any volume Omagenda will reach.

### 1.2 The consent screen

**APIs & Services → OAuth consent screen**

| Field | Value |
|---|---|
| User type | **External** |
| App name | `Omagenda` |
| User support email | your address |
| Developer contact | your address |

Leave the rest for now — the logo and the links belong to Part 2.

### 1.3 A Desktop OAuth client

**APIs & Services → Credentials → Create credentials → OAuth client ID**

- Application type: **Desktop app**
- Name: `Omagenda` (internal, users never see it)

Copy the client ID and secret straight into the plugin:

```bash
cd ~/.config/omarchy/plugins/omagenda
bin/set-google-client '<client-id>.apps.googleusercontent.com'
```

It prompts for the secret rather than taking it as an argument, so the secret stays
out of your shell history. `--from <console-download.json>` reads both straight from
the file Google gives you.

That writes `google-app.json` without disturbing the comment block, and tells you
whether it took. Then:

```bash
bin/gcal status      # client: true, clientOrigin: builtin
bin/gcal connect     # opens the browser; allow it
```

On the unverified-app screen choose **Advanced → Go to Omagenda**. That screen is
about the registration's review status, not about anything Omagenda does — it is
exactly what Part 2 removes.

Then open the bar popup → **SETTINGS → Calendars**. Your calendars should be listed.

### 1.4 Publish to production

**OAuth consent screen → Publish app** (newer consoles: **Audience → Publish app**).

Do this even before verification. In *Testing*, Google expires refresh tokens after
**seven days**, so sync would break every week. Published-but-unverified still shows
the warning screen and caps how many accounts may grant access, but the tokens last.

**You can ship at this point**, with the warning screen, if you are willing to explain
it in the README. Everything below removes it.

---

## Part 2 — Verified

### 2.1 The site

**Done.** The domain is **gaard.dev** and the site lives in its own repository,
[Neaxic/gaard.dev](https://github.com/Neaxic/gaard.dev) — static HTML, no build step,
serve the directory as the site root.

| Page | URL |
|---|---|
| Homepage | <https://gaard.dev/> |
| Privacy policy | <https://gaard.dev/privacy/> |
| Terms of service | <https://gaard.dev/terms/> |

It used to live in `site/` here; that folder is gone, because the policy has to be
served from the domain and keeping a second copy alongside the plugin only invited the
two to drift.

Requirements this satisfies, all of which are checked:

- the homepage is public, and is plainly about the app
- the privacy policy is on the **same domain** as the homepage
- the policy names each scope and says what happens to the data
- the policy carries the **Limited Use** disclosure

All four are satisfied by the pages as written. Do not strip the per-scope tables or
the Limited Use paragraph from them.

Do not point the homepage at a GitHub repo or an app-store listing. Reviewers reject
that; it has to be a site about the app.

### 2.2 Verify the domain in Search Console

<https://search.google.com/search-console> → add a property for the domain, using the
**same Google account that owns the Cloud project**. A domain-wide property (DNS TXT
record at your registrar) is the sturdiest; a URL-prefix property with the HTML file
or meta tag works too.

This is the step people forget, and the submission bounces without it.

### 2.3 Fill in the branding

**OAuth consent screen / Branding**

| Field | Value |
|---|---|
| App name | `Omagenda` — must match the site and the video |
| App logo | square PNG, 120×120 or larger, no rounded corners baked in |
| Application home page | `https://gaard.dev/` |
| Application privacy policy link | `https://gaard.dev/privacy/` |
| Application terms of service | `https://gaard.dev/terms/` |
| Authorized domains | `gaard.dev` — bare, no `https://`, no path |

### 2.4 Declare the scopes

**Data Access → Add or remove scopes.** Exactly these two, and nothing else — every
extra scope is another thing to justify:

```
https://www.googleapis.com/auth/calendar.events
https://www.googleapis.com/auth/calendar.calendarlist.readonly
```

### 2.5 Record the demo video

Unlisted on YouTube. Reviewers watch it. It has to show, in one continuous take:

1. **The OAuth client ID on screen.** Easiest honest way: start in a terminal running
   `bin/gcal connect`, which prints the full authorization URL — the `client_id=`
   parameter is right there. Let it sit on screen for a couple of seconds.
2. **The consent screen**, showing the app name *Omagenda* and both scopes as Google
   words them.
3. **Granting** access, and landing back in the app.
4. **Each scope actually being used**, which is the part most first submissions miss:
   - `calendar.calendarlist.readonly` → the CALENDARS page listing the account's
     calendars, and you clicking one to add it.
   - `calendar.events` → events from that calendar appearing in the grid and the
     agenda; then create an event in Omagenda and show it arriving in Google Calendar
     in a browser tab.
5. **Revoking**, via DISCONNECT. Not required, but it answers the question a reviewer
   is about to ask.

Narration is not needed. Four to six minutes. Do not cut between steps — an
uninterrupted take is what they are looking for.

> Record on a clean desktop. Whatever is on screen goes to Google, and this machine's
> other monitor usually has something on it you would not send.

### 2.6 Submit

**Verification Center → Prepare for verification.** Paste these when asked to justify
the scopes.

**Why `calendar.events`:**

> Omagenda is a calendar application for the Linux desktop. It displays the user's
> events in a status-bar widget and a calendar grid, and lets the user create, edit
> and delete events from that interface. Reading events is required to display them;
> writing is required because creating and editing events is the application's primary
> function. A narrower read-only scope would remove the ability to create or edit an
> event, which is the core of what the application is for. The broader `calendar`
> scope is deliberately not requested, as Omagenda has no need to create, rename or
> delete calendars themselves.

**Why `calendar.calendarlist.readonly`:**

> Omagenda lets the user choose which of their calendars to display and sync, each in
> its own colour. To present that choice, the application must list the calendars on
> the account together with their names and the user's access level — the access level
> is used to mark read-only calendars so the interface does not offer edit controls
> that would fail. This is the narrowest scope that provides the calendar list; it
> grants no access to calendar contents and no write access of any kind.

**Where the data goes**, if asked:

> Omagenda runs entirely on the user's own computer and communicates directly with
> Google's API over HTTPS. There is no server operated by the developer, no account
> system, and no analytics. Event data fetched from Google is cached in a file in the
> user's home directory so the calendar renders offline, and OAuth tokens are stored
> in the same directory with 0600 permissions. No Google user data is transmitted to
> the developer or to any third party.

### 2.7 While you wait

Google quotes 3–5 business days. Calendar scopes routinely take longer — several weeks
is common and does not mean anything is wrong.

- Watch the email on the Cloud project, and answer fast. A reply from you resets their
  clock, so a week's delay on your side costs a week.
- **Do not change the scopes, the app name or the domain mid-review.** It restarts.
- Ship in the meantime if you like. Published-unverified works; the warning screen is
  the cost.

---

## Checklist

- [ ] Project created, Calendar API enabled
- [ ] Desktop OAuth client created
- [ ] `bin/set-google-client` run; `bin/gcal status` says `clientOrigin: builtin`
- [ ] `bin/gcal connect` works end to end against real Google
- [ ] App published to **In production**
- [x] Domain registered (`gaard.dev`) and the site written
- [ ] `gaard.dev/`, `/privacy/` and `/terms/` all load over HTTPS
- [ ] Domain verified in Search Console, same Google account as the project
- [ ] Branding filled in: name, logo, homepage, privacy link, terms link,
      authorized domain
- [ ] Exactly the two scopes declared
- [ ] Demo video recorded and uploaded unlisted
- [ ] Justifications pasted, submitted
- [ ] `google-app.json` committed so the shipped build actually has the client

## If it comes back rejected

| What they say | What it usually means |
|---|---|
| "Homepage does not meet requirements" | It resolved to a repo or a redirect — it must be a page about the app, on the authorized domain |
| "Privacy policy not found / not on the same domain" | The link points somewhere else, or the domain in Branding does not match |
| "Domain ownership not verified" | Search Console property missing, or verified under a different Google account |
| "Video does not demonstrate scope usage" | The video showed the sign-in but not the app then reading and writing events — re-record step 4 |
| "Scope not justified" | Paste the justifications above; the common miss is not saying why read-only would not do |
