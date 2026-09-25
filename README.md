# Datebook

A calendar for the Omarchy bar: a month view with ISO week numbers, a day
agenda, and your own events in a plain JSON file. No accounts, no network, no
sync daemon — the store is a file you can read, edit and back up yourself.

```
┌─ Datebook ────────────────────────────────┐
│  September 2026          ‹  Today  ›      │
│  Sat 26 September · 2 events              │
│                                           │
│      M  T  W  T  F  S  S                  │
│  36  31  1  2  3  4  5  6                 │
│  37   7  8  9 10 11 12 13                 │
│  38  14 15 16 17 18 19 20                 │
│  39  21 22 23 24 25 (26) 27               │
│  40  28 29 30  1  2  3  4                 │
│                                           │
│  Sat 26 September 2026                    │
│  All day   Release day                    │
│  14:30     Dentist                        │
│  ─────────────────────────────────────    │
│  Add: [date] [HH:MM] title [!weekly]      │
└───────────────────────────────────────────┘
```

## Install

It is a plain plugin directory, so it is already where it needs to be:

```bash
omarchy-shell shell rescanPlugins
omarchy plugin enable datebook center     # or left / right
omarchy restart shell
```

## Layout

| File           | What lives there                                                            |
|----------------|-----------------------------------------------------------------------------|
| `manifest.json`| Plugin id, entry points, the settings schema the bar's settings UI renders   |
| `Model.js`     | All date and event logic, pure ES5, no QML — shared with the node tests      |
| `Service.qml`  | The one shared instance: event file, today's clock, view state, IPC target   |
| `Panel.qml`    | Bar widget plus popup: heading, month/upcoming views, add field, footer      |
| `MonthGrid.qml`| The month grid; renders the flat cell list `Model.monthCells()` builds       |
| `EventRow.qml` | One event line: time, title, repeat marker, delete on hover                 |
| `tests/`       | `node --test tests/` over `Model.js`                                        |

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
    { "id": "20260926-3f2a", "title": "Dentist", "date": "2026-09-26", "time": "14:30" },
    { "id": "20260101-8b11", "title": "Rent", "date": "2026-01-01", "repeat": "monthly" },
    { "id": "20260405-01cd", "title": "Standup", "date": "2026-04-05", "time": "09:00",
      "repeat": "weekly", "until": "2026-12-18", "notes": "room 2" }
  ]
}
```

- `date` and `time` are local; the file holds no timezones.
- `time` omitted or `""` means all day, and sorts ahead of timed events.
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
| Bar          | Left click opens, right click jumps to today, middle click toggles the upcoming list |
| Grid         | Click a day to select it                             |
| Add field    | `Dentist`, `14:30 Dentist`, `2026-10-02 09:00 Standup`, `tomorrow 08:15 Flight`, `Standup !weekly` |
| Event row    | Hover to reveal delete (a repeat deletes the whole series) |

Keys while the popup has focus: arrows walk days and weeks, `Return`/`a` focus
the add field, `t` today, `n`/`p` next and previous month, `u` upcoming, `o`
opens `events.json`, `Esc` closes.

## Settings

Inline on the plugin's entry in `~/.config/omarchy/shell.json`, as the manifest
schema describes:

| Key                  | Default    | Meaning                                        |
|----------------------|------------|------------------------------------------------|
| `barMode`            | `next`     | `next` (next event), `date`, `count`, `icon`   |
| `barIcon`            | `calendar` | `calendar`, `month`, `today`, `blank`, `clock`, `none` |
| `barMaxTitle`        | `18`       | Longest event title in the bar                 |
| `weekStartsMonday`   | `true`     | Monday-first grid                              |
| `showWeekNumbers`    | `true`     | ISO week column                                |
| `showAdjacentMonths` | `true`     | Dim days from the neighbouring months          |
| `use24Hour`          | `true`     | 24-hour times                                  |
| `upcomingDays`       | `14`       | Window the upcoming list covers                |

## IPC

`omarchy-shell datebook <method> [args]` — the same surface the UI uses, which
makes it the quick way to test without clicking:

```bash
omarchy-shell datebook status
omarchy-shell datebook add "2026-10-02 09:00 Standup !weekly"
omarchy-shell datebook list 2026-10-02
omarchy-shell datebook upcoming 30
omarchy-shell datebook select 2026-10-02
omarchy-shell datebook month 1          # page forward a month
omarchy-shell datebook today
omarchy-shell datebook remove 20261002-3f2a
omarchy-shell datebook setOption showWeekNumbers false
omarchy-shell datebook toggle           # open/close the popup
omarchy-shell datebook path
```

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
