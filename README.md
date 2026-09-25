# Datebook

A calendar for the Omarchy bar, built to a mockup: a rolling grid of the week
you are in and the two ahead, a year view, a day agenda with detail and compose
pages, and your own events in a plain JSON file. No accounts, no network, no sync
daemon — the store is a file you can read, edit and back up yourself.

The grid rolls rather than paging months: past weeks are gone, not greyed, so
what you see is the days still in front of you. The furthest week sits back at
half opacity.

```
┌─ Datebook ─────────────────────────────────────────────────┐
│  ▣  September 26             2026 ────────────────── 73%   │
│                                        ┌─────────┬───────┐ │
│                                        │  WEEKS  │ YEAR  │ │
│         MO    TU    WE    TH    FR    SA    SU   └───────┘ │
│  ───────────────────────────────────────────────────────── │
│   39 │ 21  │ 22  │ 23  │ 24  │ 25  │[26]·│ 27      ← now   │
│   40 │ 28 ·│ 29 ··│ 30 │  1  │  2 ·│  3  │  4              │
│   41 │  5 ·│  6 · │  7 │  8  │  9  │ 10  │ 11      ← faded │
│  ───────────────────────────────────────────────────────── │
│  SATURDAY, SEPTEMBER 26                                ┌─┐ │
│  1 event                                               │+│ │
│  ───────────────────────────────────────────────────── └─┘ │
│  Design review                                           ›  │
│   14:00 – 15:00 · Studio 2                                  │
│  ───────────────────────────────────────────────────────── │
│  ‹               SEP – OCT 2026                          ›  │
│  ┌──────────────┐ ┌───────┐                                 │
│  │ + NEW EVENT  │ │ TODAY │                                 │
│  └──────────────┘ └───────┘                                 │
└─────────────────────────────────────────────────────────────┘
```

Four pages, all inside the one popup:

| Page      | Reached by                        | What it is                                        |
|-----------|-----------------------------------|---------------------------------------------------|
| `month`   | the default, or WEEKS             | the rolling weeks above, plus the selected day's agenda |
| `year`    | the YEAR half of the switch       | twelve miniatures, a mark per day, events brighter |
| `detail`  | the chevron on an event           | one event's facts, with edit and delete            |
| `compose` | `+`, NEW EVENT, or EDIT           | title, date, time, length, place and a repeat      |

## Install

It is a plain plugin directory, so it is already where it needs to be:

```bash
omarchy-shell shell rescanPlugins
omarchy plugin enable datebook center     # or left / right
omarchy restart shell
```

## Layout

| File                | What lives there                                                        |
|---------------------|-------------------------------------------------------------------------|
| `manifest.json`     | Plugin id, entry points, the settings schema the bar's settings UI renders |
| `Model.js`          | All date and event logic, pure ES5, no QML — shared with the node tests  |
| `Service.qml`       | The one shared instance: event file, today's clock, view state, IPC target |
| `Chrome.qml`        | The design tokens — every ink level is the theme foreground at a fixed alpha |
| `Panel.qml`         | Bar widget plus popup: masthead, page routing, keyboard                  |
| `CalendarHeader.qml`| The masthead: glyph slab, month set large, year meter, the view switch   |
| `MonthGrid.qml`     | The month grid: week gutter, hairlines, day numbers, dots                |
| `YearGrid.qml`      | The year page's twelve miniatures                                        |
| `EventCard.qml`     | One event band: title, time and place, chevron                           |
| `EventDetail.qml`   | The detail page                                                          |
| `EventCompose.qml`  | The new/edit form, built from `FormField` and `SegmentedToggle`          |
| `FormField.qml`     | A labelled input closed by a rule rather than a box                      |
| `SegmentedToggle.qml`, `OutlineButton.qml` | The two controls the design uses everywhere      |
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
      "durationMin": 60, "location": "Studio 2" },
    { "id": "20260101-8b11", "title": "Rent", "date": "2026-01-01", "repeat": "monthly" },
    { "id": "20260405-01cd", "title": "Standup", "date": "2026-04-05", "time": "09:00",
      "repeat": "weekly", "until": "2026-12-18", "notes": "room 2" }
  ]
}
```

- `date` and `time` are local; the file holds no timezones.
- `time` omitted or `""` means all day, and sorts ahead of timed events.
- `durationMin` gives the card its "14:00 – 15:00"; `location` its place.
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
| `‹` `›`      | Roll the window one week; a day picked outside it re-anchors the grid |
| WEEKS / YEAR | Switch the grid for twelve months; click a month to open it |
| Event band   | Click anywhere on it for the detail page, then EDIT or DELETE |
| `+` / NEW EVENT | The compose form: title, date, time, minutes, place, repeat |

Keys while the popup has focus: arrows walk days and weeks (months on the year
page), `Return`/`a` opens the compose form, `t` today, `n`/`p` roll the window a
week forward and back (a year on the year page), `y` toggles the year page, `o`
opens `events.json`. `Esc` steps back a page, or closes the popup from the
calendar.

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
omarchy-shell datebook week 1           # roll the window forward a week
omarchy-shell datebook month 1          # jump to the next month
omarchy-shell datebook today
omarchy-shell datebook page year ""          # month | year | detail <id> | compose [id]
omarchy-shell datebook event 20261002-3f2a   # one event, as the detail page sees it
omarchy-shell datebook compose "" '{"title":"Sprint planning","date":"2026-09-28","time":"10:30","durationMin":90,"location":"Room 4","repeat":"weekly"}'
omarchy-shell datebook remove 20261002-3f2a
omarchy-shell datebook setOption showWeekNumbers false
omarchy-shell datebook toggle           # open/close the popup
omarchy-shell datebook path
```

## Where this differs from the mockup

- The grid **rolls three weeks from the current one** rather than showing a whole
  month — which is what the mockup itself shows (weeks 39, 40, 41), and the
  pager under it moves by a week, not a month.
- The **WEEKS / YEAR switch sits under the year meter**, not in the weekday row.
  In the mockup it shares that row with the weekday letters, which pushes them
  off the columns they head; with the switch moved, they line up.
- The **year meter is a meter**: a dim track with the elapsed part lit. The
  mockup draws it fully lit at 73%.
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
