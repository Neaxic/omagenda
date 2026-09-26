# Datebook

A calendar for the Omarchy bar, built to a mockup: a rolling grid of the week
you are in and the two ahead, a year view, a day agenda with detail and compose
pages, and your own events in a plain JSON file. No accounts, no network, no sync
daemon — the store is a file you can read, edit and back up yourself.

The grid rolls rather than paging months: past weeks are gone, not greyed, so
what you see is the days still in front of you. The furthest week sits back at
half opacity. MONTH expands it to the whole month when you want the shape of
one; the year page always opens a month that way.

```
┌─ Datebook ─────────────────────────────────────────────────┐
│  ▣  September 26                  ┌───────┬───────┬──────┐ │
│                                   │ WEEKS │ MONTH │ YEAR │ │
│         MO    TU    WE    TH    FR    SA    SU    └──────┘ │
│  ───────────────────────────────────────────────────────── │
│   39 │ 21  │ 22  │ 23  │ 24  │ 25  │[26]·│ 27      ← now   │
│      │ ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▶     ← a run   │
│   40 │ 28 ·│ 29 ··│ 30 │  1  │  2 ·│  3  │  4              │
│      │ ◀▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬     continued │
│      │     │     │ ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬     lane 2    │
│   41 │  5 ·│  6 · │  7 │  8  │  9  │ 10  │ 11      ← faded │
│  ───────────────────────────────────────────────────────── │
│  ───────────────────────────────────────────────────────── │
│ ▌Design review                                           ›  │
│   14:00 – 15:00 · Studio 2                                  │
│  ───────────────────────────────────────────────────────── │
│  «  ‹            SEP – OCT 2026                     ›   »   │
│  ┌──────────────┐ ┌───────┐                                 │
│  │ + NEW EVENT  │ │ TODAY │                                 │
│  └──────────────┘ └───────┘                                 │
└─────────────────────────────────────────────────────────────┘
```

The agenda states nothing the page has already said: no date heading (the
masthead names the day and the grid has it outlined), no count line (the bands
are the count). A day with nothing on it shows no agenda at all — the rule under
the grid closes it and the pager follows.

Four pages, all inside the one popup:

| Page      | Reached by                        | What it is                                        |
|-----------|-----------------------------------|---------------------------------------------------|
| `month`   | the default, or WEEKS / MONTH     | the grid above, plus the selected day's agenda      |
| `year`    | the YEAR half of the switch       | twelve miniatures, a mark per day, events brighter |
| `detail`  | the chevron on an event           | one event's facts, with edit and delete            |
| `compose` | NEW EVENT, or EDIT on an event    | title, date, days, time, length, place, colour, calendar, repeat |

## Where this stands

Written to a mockup over one session on **26 September 2026**, and installed:
the plugin is enabled in the centre of the bar and everything below works on
screen. 63 node assertions, `omarchy plugin validate` and `qmllint` clean.

**Working, seen on screen**

- The rolling grid (the week you are in plus two), MONTH expanding it to a whole
  month, and the YEAR page of twelve miniatures.
- The day agenda, the event detail page, and the compose form — create, edit and
  delete, including colours and multi-day runs.
- Events stored in `~/.config/datebook/events.json`, watched, hand-editable.

**Built but never run against the real service: Google sync**

The whole path exists — OAuth, token refresh, incremental pulls, write-through,
the sources model, the CALENDAR switch in compose — and was verified end to end
with a stubbed `bin/gcal` standing in for Google. It has **never talked to
Google**, because that needs credentials only you can create.

Picking it up is four steps, all in **[docs/google-setup.md](docs/google-setup.md)**:

```bash
# 1. Cloud console: new project, enable the Calendar API,
#    publish the OAuth consent screen, make a Desktop client,
#    write ~/.config/datebook/google-client.json      (see the doc)
bin/gcal login                                        # 2. browser consent, once
bin/gcal calendars                                    # 3. the ids you want
omarchy-shell datebook sourceAdd "you@gmail.com" "Personal" sky
omarchy-shell datebook sync true                      # 4. first full pass
omarchy-shell datebook syncStatus                     #    and what it made of it
```

If step 4 reports an error, the table at the end of the setup doc maps each one
to the step that was missed.

**The store currently holds eight demo events** — Design review, Standup, Ship
v0.2, Dinner, Sprint planning, and three runs (Berlin trip, Sprint 12, Design
workshop) — added to photograph the grid. Clear them whenever real use starts:

```bash
rm ~/.config/datebook/events.json     # the service writes a fresh empty one
```

**Not built**

- Repeats on a synced calendar — the compose form refuses them, since Google
  models recurrence in ways this store does not. Local repeats are unaffected.
- Editing a single occurrence of a repeat: edit and delete act on the series.
- Notifications or alerts before an event.
- An in-panel settings page; settings are the manifest schema plus
  `~/.config/omarchy/shell.json`, and calendars are added over IPC.
- Any provider other than Google. The sources model is provider-agnostic, so an
  ICS or CalDAV source would slot in beside `kind: "google"`.

## Install

Already done on this machine (see above). On a fresh one it is a plain plugin
directory, so it only needs discovering:

```bash
omarchy-shell shell rescanPlugins
omarchy plugin enable datebook center     # or left / right
omarchy restart shell
```

To take it back out: `omarchy plugin disable datebook`.

## Layout

| File                | What lives there                                                        |
|---------------------|-------------------------------------------------------------------------|
| `manifest.json`     | Plugin id, entry points, the settings schema the bar's settings UI renders |
| `Model.js`          | All date and event logic, pure ES5, no QML — shared with the node tests  |
| `Service.qml`       | The one shared instance: event file, today's clock, view state, IPC target |
| `Chrome.qml`        | The design tokens — every ink level is the theme foreground at a fixed alpha |
| `Panel.qml`         | Bar widget plus popup: masthead, page routing, keyboard                  |
| `CalendarHeader.qml`| The masthead: glyph slab, month set large, the view switch               |
| `MonthGrid.qml`     | The month grid: week gutter, hairlines, day numbers, dots                |
| `YearGrid.qml`      | The year page's twelve miniatures                                        |
| `EventCard.qml`     | One event band: title, time and place, chevron                           |
| `EventDetail.qml`   | The detail page                                                          |
| `EventCompose.qml`  | The new/edit form, built from `FormField` and `SegmentedToggle`          |
| `FormField.qml`     | A labelled input closed by a rule rather than a box                      |
| `SegmentedToggle.qml`, `OutlineButton.qml` | The two controls the design uses everywhere      |
| `bin/gcal`          | Everything Google: OAuth, token refresh, calendar and event calls        |
| `docs/google-setup.md` | The one-off Cloud console setup                                       |
| `tests/`            | `node --test tests/` over `Model.js`                                     |

`Service.qml` is mounted once per session; the bar widgets (one per monitor)
find it with `bar.shell.serviceFor("datebook")`. Because the selected day and
the visible month live on the service, paging the calendar on one monitor pages
it on the other too.

## The event store

`~/.config/datebook/events.json`, created on first run:

```json
{
  "version": 1,
  "events": [
    { "id": "20260926-3f2a", "title": "Design review", "date": "2026-09-26", "time": "14:00",
      "durationMin": 60, "location": "Studio 2", "color": "sky" },
    { "id": "20260101-8b11", "title": "Rent", "date": "2026-01-01", "repeat": "monthly" },
    { "id": "20260405-01cd", "title": "Standup", "date": "2026-04-05", "time": "09:00",
      "repeat": "weekly", "until": "2026-12-18", "notes": "room 2" }
  ]
}
```

- `date` and `time` are local; the file holds no timezones.
- `time` omitted or `""` means all day, and sorts ahead of timed events.
- `durationMin` gives the card its "14:00 – 15:00"; `location` its place.
- `days` is the span in days, counting the first (see **Multi-day events**).
- `source`, `remoteId` and `etag` appear on synced events; local events leave
  them empty.
- `color` is one of `clay`, `sand`, `moss`, `sky`, `slate`, `plum`; omitted means
  no colour. Older stores using terminal names (`green`, `magenta`, …) still read.
- `repeat` is `daily`, `weekly`, `monthly` or `yearly`, walking forward from
  `date` only. A monthly repeat on the 31st simply has no occurrence in a
  30-day month rather than sliding to the 30th.
- `until` (optional) ends a series, inclusive.
- Defaults are left out of the file, so hand-editing stays pleasant.

The file is watched: edit it in an editor and the calendar follows. Our own
writes are recognised and not re-read, so an outside edit can never roll back a
newer in-panel edit.

## Using it

| Where        | Action                                               |
|--------------|------------------------------------------------------|
| Bar          | Left click opens, right click jumps to today, middle click starts a new event |
| Grid         | Click a day to select it, double click to add one there |
| `‹` `›`      | Roll the window one week (rolling view only); a day picked outside it re-anchors the grid |
| WEEKS / MONTH | Roll three weeks, or expand to the whole month      |
| YEAR         | Twelve miniatures; click a month to open it whole   |
| `«` `»`      | Page a month, keeping the day of the month where it can |
| Event band   | Click anywhere on it for the detail page, then EDIT or DELETE |
| NEW EVENT    | The compose form: title, date, days, time, minutes, place, colour, repeat |

Keys while the popup has focus: arrows walk days and weeks (months on the year
page), `Return`/`a` opens the compose form, `t` today, `n`/`p` step the grid — a
week rolling, a month expanded, a year on the year page — `,`/`.` page a month,
`m` expands or collapses the grid, `y` toggles the year page, `o` opens
`events.json`. `Esc` steps back a page, or closes the popup from the
calendar.

## Multi-day events

An event with `days` greater than 1 stops being a dot and becomes a bar drawn
across the days it covers:

- It is **clipped to the week** it is passing through and redrawn on the next
  row, so a fortnight-long run appears on both. A clipped end runs flush to the
  edge of the grid; an end that really is the end is inset, which is what tells
  you whether the run stops there or carries on.
- Overlapping runs **stack in lanes**, assigned greedily — each run takes the
  lowest lane it does not collide in. That is how every calendar keeps two runs
  from drawing over each other.
- Every row grows by the same amount to make space, so the grid stays even and
  only gets taller when something actually runs across it.
- **Dots are for single-day events only.** A day inside a run does not also get
  a dot: the bar already says the event is there.
- In the agenda a run leads with its shape rather than its clock —
  `Day 6/14 · 21 Sep → 4 Oct` — and sorts above the day's timed events, longest
  first, which is the order the day actually reads in.

In the store it is one integer:

```json
{ "id": "20260921-a1b2", "title": "Sprint 12", "date": "2026-09-21", "days": 14, "color": "moss" }
```

`endDate` is accepted when reading and folded into `days`, so hand-editing the
file with an end date works; it is written back as `days`. The span is a length
rather than a fixed end because a repeat has to carry it: a three-day shift that
repeats weekly is three days *every* week.

## Syncing with Google Calendar

Datebook talks to Google directly, two-way: your Google events appear in the
bar, and an event created here lands in Google. Setup is a one-off five minutes
in the Cloud console — **[docs/google-setup.md](docs/google-setup.md)** walks
through it.

The shape of it:

- **Calendars are sources.** The local JSON store is one, each Google calendar
  is another, listed in `~/.config/datebook/sources.json`. A source has a name,
  a colour its events take, and an enabled flag.
- **Synced events live in their own cache** (`cache.json`), never merged into
  `events.json`. A sync cannot touch what you wrote locally, and a local edit
  cannot touch Google. They are only merged for display.
- **Colour says which calendar**, which is the convention everywhere else (see
  **Colour**): an event takes its source's colour unless it sets its own.
- **Incremental.** Google hands back a sync token and is then only asked what
  changed. When a token gets too old Google says so and Datebook retakes that
  calendar in full, silently.
- **Writes go where the event lives.** Editing a Google event PATCHes it in
  Google; editing a local one rewrites the JSON. The compose form's CALENDAR
  switch picks which, and moving an event between calendars removes and
  recreates it, since neither side can move it in place.
- **Read-only calendars** (a subscribed feed, someone else's shared calendar)
  show their events and hide EDIT and DELETE.

```bash
bin/gcal login                                           # once, opens a browser
bin/gcal calendars                                       # ids and access roles
omarchy-shell datebook sourceAdd "you@gmail.com" "Personal" sky
omarchy-shell datebook sync true                         # true = full, not incremental
omarchy-shell datebook syncStatus
```

Everything Google-facing is in `bin/gcal` — OAuth, token refresh, and the four
API calls the plugin makes — written against the standard library alone, so the
plugin stays a git clone with nothing to install. Tokens live in
`~/.config/datebook/google-tokens.json` at `0600` and are never logged.

One caveat worth repeating from the setup guide: **publish the OAuth consent
screen to *In production***. Left in *Testing*, Google expires refresh tokens
after seven days and sync stops until you sign in again.

## Colour

Events can carry a colour, and the day's dots take it, so a day with two events
shows two marks rather than two of the same.

Worth knowing what the colour actually means, because mainstream calendars are
less principled here than they look:

- **In Google, Apple and Outlook, colour means "which calendar"** — Personal,
  Work, a shared team calendar, a subscribed holidays feed. Every event inherits
  its calendar's colour. The colour answers *which bucket*, never *what kind of
  thing*.
- **Per-event overrides come from a fixed palette with meaningless names.**
  Google's are Tomato, Flamingo, Tangerine, Banana, Sage, Basil, Peacock,
  Blueberry, Lavender, Grape and Graphite. Outlook calls them Categories and
  ships them named "Red category" until you rename them. The names are
  deliberately empty: the meaning is whatever the user decides.
- **There is no shared semantics.** Red is not "urgent" and green is not "free"
  in any calendar worth the name. The only conventions that *are* near-universal
  are structural, not chromatic: today is marked, declined events render hollow
  or struck, tentative is hatched, all-day sits above timed.

So the single rule that matters is consistency — one bucket, one colour — plus
enough separation that the buckets are still distinct at dot size. Datebook
follows the same idea: six slots named `clay`, `sand`, `moss`, `sky`, `slate`
and `plum`, which are labels rather than promises about hue, plus `none` for an
event that takes the ordinary ink. Pick the meanings yourself.

Where the hues come from is a setting:

| `eventPalette` | What you get                                                    |
|----------------|-----------------------------------------------------------------|
| `spread` (default) | Six hues spread evenly from the theme's accent, at the accent's own saturation and lightness. Harmonises with the theme *and* stays distinguishable. |
| `theme`        | The theme's literal `red`/`yellow`/`green`/`cyan`/`blue`/`magenta` slots. Truest to the theme, but many themes leave these close together — this one defines `blue` identical to its accent and `yellow` at 41% lightness. |

`spread` exists because of exactly that: a muted theme's own palette can collapse
into three near-identical colours, which is worse than no colour coding at all.
A near-grey accent still yields six hues, since the derivation floors saturation
rather than handing back six greys.

## Settings

Inline on the plugin's entry in `~/.config/omarchy/shell.json`, as the manifest
schema describes:

| Key                  | Default    | Meaning                                        |
|----------------------|------------|------------------------------------------------|
| `barMode`            | `next`     | `next` (next event), `date`, `count`, `icon`   |
| `barIcon`            | `calendar` | `calendar`, `month`, `today`, `blank`, `clock`, `none` |
| `barMaxTitle`        | `18`       | Longest event title in the bar                 |
| `displayFont`        | `auto`     | Headline face: `auto` picks an installed grotesque, `theme` keeps the bar's font, or name a family |
| `weekStartsMonday`   | `true`     | Monday-first grid                              |
| `showWeekNumbers`    | `true`     | ISO week column                                |
| `weeksShown`         | `3`        | Weeks in the grid, counting the one you are in (1–8) |
| `use24Hour`          | `true`     | 24-hour times                                  |
| `upcomingDays`       | `14`       | Window the upcoming list covers                |
| `eventPalette`       | `spread`   | Where event colours come from (see **Colour**) |

## IPC

`omarchy-shell datebook <method> [args]` — the same surface the UI uses,
including page navigation and the compose form's own save path, which makes it
the quick way to drive the popup without clicking:

```bash
omarchy-shell datebook status
omarchy-shell datebook add "2026-10-02 09:00 Standup !weekly"
omarchy-shell datebook list 2026-10-02
omarchy-shell datebook upcoming 30
omarchy-shell datebook select 2026-10-02
omarchy-shell datebook grid month       # weeks | month, or "" to flip
omarchy-shell datebook showMonth 2027 3 # open a month whole, as the year page does
omarchy-shell datebook week 1           # roll the window forward a week
omarchy-shell datebook month 1          # jump a month, keeping the day
omarchy-shell datebook today
omarchy-shell datebook page year ""          # month | year | detail <id> | compose [id]
omarchy-shell datebook event 20261002-3f2a   # one event, as the detail page sees it
omarchy-shell datebook compose "" '{"title":"Sprint planning","date":"2026-09-28","time":"10:30","durationMin":90,"location":"Room 4","color":"moss","repeat":"weekly"}'
omarchy-shell datebook compose "" '{"title":"Berlin trip","date":"2026-09-30","days":5,"color":"sky"}'
omarchy-shell datebook remove 20261002-3f2a
omarchy-shell datebook setOption showWeekNumbers false
omarchy-shell datebook toggle           # open/close the popup
omarchy-shell datebook path
```

## Where this differs from the mockup

- The agenda **drops the mockup's day heading, its "1 event" line and its `+`**:
  the date is already in the masthead and the grid, the bands are their own
  count, and NEW EVENT at the foot does what the `+` did. An empty day drops the
  band altogether rather than reading "Nothing planned".
- Events can be **colour-coded** and can **run across days as bars**, neither of
  which the mockup shows at all.
- The grid **rolls three weeks from the current one** rather than showing a whole
  month — which is what the mockup itself shows (weeks 39, 40, 41), and the
  pager under it moves by a week, not a month.
- The **WEEKS / YEAR switch sits under the year meter**, not in the weekday row.
  In the mockup it shares that row with the weekday letters, which pushes them
  off the columns they head; with the switch moved, they line up.
- The mockup's **year meter is gone** — it measured the calendar year, not
  anything the calendar was being asked about.
- The **masthead runs smaller** than the mockup's 46px, which reads outsized on
  a bar popup.
- **Sunday-first** in the mockup; this defaults to Monday-first
  (`weekStartsMonday`), which is the local convention here.
- The mockup is set in one tight grotesque. `displayFont: auto` picks the first
  installed face from `Model.DISPLAY_FAMILIES`; Nerd Font glyphs stay on the
  bar's monospace, which is the only family that carries them.

## Developing

```bash
node --test tests/                                   # the date and event logic
omarchy plugin validate .                            # manifest against the schema
qmllint -I <dir-with-a-qs-symlink> Panel.qml         # ln -s /usr/share/omarchy/shell qs
omarchy restart shell                                # QML edits only take effect here
```

Note the last line: saving a file under `~/.config/omarchy/plugins/` logs
`Local plugin changed, reloading`, but a live bar widget keeps running the old
compile. If an edit seems to do nothing, restart the shell before debugging it.
`journalctl --user -f` shows QML errors; popup contents are only created when
the popup first opens, so errors in there surface on the first toggle.

## License

MIT.
