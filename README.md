<img width="811" height="962" alt="preview" src="https://github.com/user-attachments/assets/f7b8e6ec-2c0f-4400-a0f3-32c2136769d2" />




# Omagenda

A calendar for the Omarchy bar - expanding the design already provided by DHH, this "upgrade" allows syncing with mail clients (only google calendar currently), and a greater overview.
The app has had a short life, but im already getting benefits from this overhaul, so figured id share it.

For the google syncing to work, i need various setup on google cloud. You may come across "Google hasn't verified this app", you can safely proceed and chose Advanced → Go to Omagenda.
**There is no server, there is no db, this is all ran locally.**
Because of the google project limitations, the plugin (currently) only allows for 100 users, ill expand if demand comes, and naturally i might care for the setup a bit more.

**What it asks for:** `calendar.events` (read and write events) and
`calendar.calendarlist.readonly` (see which calendars exist). Deliberately *not*
the blanket `calendar` scope — Omagenda cannot create, rename or delete a
calendar, only the events inside one. Revoke any time with **DISCONNECT**, or at
<https://myaccount.google.com/permissions>.

## What you get

- **A grid that rolls.** The week you are in and the two ahead, so the calendar
  shows the days still in front of you. MONTH expands it when you want the
  shape of a whole one, YEAR gives you twelve miniatures to jump from.
- **A day agenda.** Click a day, get its events under the grid — time, length
  and place — then the chevron for the full event, with edit and delete.
- **Events that are yours.** A plain JSON file at
  `~/.config/omagenda/events.json` you can read, edit in a text editor and back
  up. The calendar follows the file while you type in it.
- **Google Calendar, both ways, at one button.** No API keys, no Cloud console.
  Press it, allow it in the browser, and your calendars are there — every one
  on the account is a row you can switch on, each with its own colour.
- **Multi-day events draw as bars.** A trip or a sprint runs across the days it
  covers, stacked in lanes when they overlap, cut flush at the week's edge when
  it carries on.
- **Six event colours** that follow your theme, picked in the compose form and
  drawn as the day's dots and a rail on the event band.
- **Your bar, your way.** Show the next event, the date, a count, a full clock,
  or just an icon.
- **Keyboard driven.** Every page has a key, and `Esc` always steps back.

## Install

```bash
omarchy plugin add https://github.com/Neaxic/omagenda.git --enable
```

Or by hand: copy this folder to `~/.config/omarchy/plugins/io.github.neaxic.omagenda/`, then

```bash
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.neaxic.omagenda center   # or left / right
omarchy restart shell
```

Nothing to install for the calendar itself. **Google sync needs `python3`**,
standard library only — no `pip`, no SDK, no daemon. Arch has it already.

Omagenda has a clock mode, so it can stand in for the built-in clock: disable
`omarchy.clock` and set `bar.centerAnchor` to `io.github.neaxic.omagenda` in
`~/.config/omarchy/shell.json`.

## Uninstall

```bash
omarchy plugin disable io.github.neaxic.omagenda
omarchy plugin remove io.github.neaxic.omagenda
```

Your events stay in `~/.config/omagenda/` until you delete that folder. If you
had Google sync on, hit **DISCONNECT** on the calendars page first.

## Using it

| Where         | Action                                                              |
|---------------|---------------------------------------------------------------------|
| Bar           | Left click opens, right click jumps to today, middle click starts a new event |
| Grid          | Click a day to select it, double click to add one there             |
| `‹` `›`       | Roll the window a week                                              |
| `«` `»`       | Page a month, keeping the day of the month                          |
| WEEKS / MONTH | Roll three weeks, or expand to the whole month                      |
| YEAR          | Twelve miniatures; click a month to open it whole                   |
| Event band    | Click it for the detail page, then EDIT or DELETE                   |
| NEW EVENT     | Title, date, days, time, length, place, colour, calendar, repeat    |
| ▣ in DATE     | A month under the row; pick a day, or keep typing — both work       |
| ⚙ SETTINGS    | Everything the widget can be told, and the way on to your calendars |

Keys while the popup is open: arrows walk days and weeks, `Return` or `a` opens
the compose form, `t` today, `n`/`p` step the grid, `,`/`.` page a month, `m`
expands or collapses it, `y` the year page, `s` settings, `c` calendars, `o`
opens `events.json`. `Esc` steps back a page, or closes the popup.

## Turning Google on

**SETTINGS → Calendars → SYNC WITH GOOGLE CALENDAR**, allow it in the browser,
and your primary calendar starts syncing. Every other calendar on the account
becomes a row on the same page — click one to add or drop it, and give it a
colour. Edits go both ways. Read-only calendars (a subscribed feed, someone
else's shared calendar) show their events and hide EDIT and DELETE.

If you would rather answer to your own Google Cloud project than the one that
ships here, put it in `~/.config/omagenda/google-client.json` and it takes
precedence — that also sidesteps the hundred-account cap, since you would then
be the only user of your own app.

## Your data

Everything lives in `~/.config/omagenda/`, which Omagenda creates for your
account only:

| File                 | What it is                                            |
|----------------------|-------------------------------------------------------|
| `events.json`        | Your own events. Plain, documented, hand-editable.    |
| `sources.json`       | Which calendars you sync, and their colours.          |
| `cache.json`         | A local copy of synced events, so the calendar draws offline. |
| `google-tokens.json` | Your Google token, readable only by you.              |

Omagenda talks to Google and to nothing else — no analytics, no telemetry. With
sync off it makes no network connection at all.

An event is `{"title", "date", "time", "durationMin", "location", "days",
"color", "repeat", "until"}`; `time` left out means all day, `repeat` is
`daily`, `weekly`, `monthly` or `yearly`, and `days` is how long it runs.
Defaults are left out of the file, so editing it by hand stays pleasant.

## Settings

**SETTINGS** in the footer, or `s`. What the bar shows and which icon it wears,
where the week starts, week numbers, how many weeks the grid rolls, 12- or
24-hour times, where event colours come from, and the face that sets the
headlines. Everything is also inline on the plugin's entry in
`~/.config/omarchy/shell.json` if you would rather type it:

| Key                | Default    | Meaning                                           |
|--------------------|------------|---------------------------------------------------|
| `barMode`          | `next`     | `next`, `date`, `count`, `clock`, `icon`          |
| `barIcon`          | `calendar` | `calendar`, `month`, `today`, `blank`, `clock`, `none` |
| `barMaxTitle`      | `18`       | Longest event title in the bar                    |
| `displayFont`      | `auto`     | `auto` picks an installed grotesque, `theme` keeps the bar's font, or name a family |
| `weekStartsMonday` | `true`     | Monday-first grid                                 |
| `showWeekNumbers`  | `true`     | ISO week column                                   |
| `weeksShown`       | `3`        | Weeks the grid rolls, counting yours (1–8)        |
| `use24Hour`        | `true`     | 24-hour times                                     |
| `eventPalette`     | `spread`   | `spread` rotates six hues off your theme's accent; `theme` uses its literal colours |

## Not yet

- Notifications or alerts before an event.
- Repeats on a synced calendar — the compose form refuses them, since Google
  models recurrence in ways this store does not. Local repeats are unaffected.
- Editing one occurrence of a local repeat: edit and delete act on the series.
- Any provider but Google. ICS and CalDAV would slot in beside it.

## License

MIT — see [LICENSE](LICENSE). The terms the plugin is published under, including
the warranty and liability disclaimers, are at <https://gaard.dev/terms/>.
