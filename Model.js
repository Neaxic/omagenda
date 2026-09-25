// Pure date and event helpers for Datebook. ES5 only — this file is shared by
// QML (Qt's JS engine, via `import "Model.js" as Model`) and the node tests, so
// it must not touch QML, the DOM or anything Qt-specific.
//
// Dates are passed around as "YYYY-MM-DD" strings ("iso" below) and only turned
// into Date objects where arithmetic needs it. Times are "HH:MM" or "" for an
// all-day event. Everything is local time; the store holds no timezones.

var MONTH_NAMES = ["January", "February", "March", "April", "May", "June",
                   "July", "August", "September", "October", "November", "December"]
var MONTH_SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
// Sunday-first, the order Date.getDay() uses.
var WEEKDAY_SHORT = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
var WEEKDAY_INITIAL = ["S", "M", "T", "W", "T", "F", "S"]

var REPEATS = ["none", "daily", "weekly", "monthly", "yearly"]
var REPEAT_LABELS = {
  none: "once", daily: "every day", weekly: "every week",
  monthly: "every month", yearly: "every year"
}

// What the bar entry shows. "next" falls back to the date when nothing is due.
var BAR_MODES = ["next", "date", "count", "icon"]

var BAR_ICONS = [
  { key: "calendar", glyph: "\u{F00ED}", label: "Calendar" },
  { key: "month", glyph: "\u{F0E17}", label: "Month" },
  { key: "today", glyph: "\u{F00F6}", label: "Today" },
  { key: "blank", glyph: "\u{F0B66}", label: "Outline" },
  { key: "clock", glyph: "\u{F00F0}", label: "Date + clock" },
  { key: "none", glyph: "", label: "No icon" }
]

// ---------------------------------------------------------------- primitives

function pad2(n) { return (n < 10 ? "0" : "") + n }

function trim(s) { return String(s === undefined || s === null ? "" : s).replace(/^\s+|\s+$/g, "") }

function toISO(date) {
  return date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate())
}

function isISODate(value) { return /^\d{4}-\d{2}-\d{2}$/.test(String(value || "")) }

// Parses "YYYY-MM-DD" into a local Date at midnight, or null when the string is
// not a real date ("2026-02-30" is rejected rather than rolled into March).
function fromISO(iso) {
  if (!isISODate(iso)) return null
  var parts = String(iso).split("-")
  var y = parseInt(parts[0], 10), m = parseInt(parts[1], 10), d = parseInt(parts[2], 10)
  if (m < 1 || m > 12 || d < 1 || d > 31) return null
  var date = new Date(y, m - 1, d)
  if (date.getFullYear() !== y || date.getMonth() !== m - 1 || date.getDate() !== d) return null
  return date
}

function todayISO(now) { return toISO(now || new Date()) }

function sameDay(a, b) {
  return a.getFullYear() === b.getFullYear()
      && a.getMonth() === b.getMonth()
      && a.getDate() === b.getDate()
}

function daysInMonth(year, month) { return new Date(year, month + 1, 0).getDate() }

function shiftISO(iso, days) {
  var date = fromISO(iso)
  if (!date) return iso
  date.setDate(date.getDate() + days)
  return toISO(date)
}

function daysBetween(fromIso, toIso) {
  var a = fromISO(fromIso), b = fromISO(toIso)
  if (!a || !b) return 0
  // Compare UTC midnights so a DST boundary in between cannot bend the count.
  var ua = Date.UTC(a.getFullYear(), a.getMonth(), a.getDate())
  var ub = Date.UTC(b.getFullYear(), b.getMonth(), b.getDate())
  return Math.round((ub - ua) / 86400000)
}

// ISO-8601 week number: week 1 is the week holding the first Thursday.
function isoWeek(date) {
  var d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()))
  d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7))
  var yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1))
  return Math.ceil(((d - yearStart) / 86400000 + 1) / 7)
}

function addMonths(year, month, delta) {
  var total = year * 12 + month + delta
  return { year: Math.floor(total / 12), month: ((total % 12) + 12) % 12 }
}

function monthTitle(year, month) { return MONTH_NAMES[month] + " " + year }

function weekdayLabels(mondayFirst) {
  var base = WEEKDAY_INITIAL
  return mondayFirst ? base.slice(1).concat(base.slice(0, 1)) : base.slice(0)
}

// ------------------------------------------------------------------ the grid

// A flat cell list for a Grid of 7 columns (8 with week numbers). Cells carry
// everything the delegate needs so the QML side never does date arithmetic:
//   { kind: "week" | "day" | "blank", iso, day, inMonth, today, weekend, week, count }
// `counts` is an iso -> number map (see countsInRange); omit it for a bare grid.
function monthCells(year, month, options) {
  var o = options || {}
  var mondayFirst = o.mondayFirst !== false
  var withWeeks = o.showWeekNumbers !== false
  var withAdjacent = o.showAdjacentMonths !== false
  var today = o.todayISO || todayISO()
  var counts = o.counts || {}

  var first = new Date(year, month, 1)
  var total = daysInMonth(year, month)
  var firstDow = first.getDay()
  var lead = mondayFirst ? (firstDow + 6) % 7 : firstDow
  var rows = Math.ceil((lead + total) / 7)

  var cells = []
  for (var r = 0; r < rows; r++) {
    if (withWeeks) {
      // Anchor the number on a real day of this month in the row: the first row
      // can open with days from the previous month, whose week may differ.
      var anchor = null
      for (var c = 0; c < 7; c++) {
        var n = r * 7 + c - lead + 1
        if (n >= 1 && n <= total) { anchor = n; break }
      }
      cells.push({
        kind: "week", iso: "", day: 0, inMonth: false, today: false, weekend: false,
        week: anchor === null ? 0 : isoWeek(new Date(year, month, anchor)), count: 0
      })
    }

    for (var col = 0; col < 7; col++) {
      var dayNum = r * 7 + col - lead + 1
      var inMonth = dayNum >= 1 && dayNum <= total
      if (!inMonth && !withAdjacent) {
        cells.push({ kind: "blank", iso: "", day: 0, inMonth: false, today: false, weekend: false, week: 0, count: 0 })
        continue
      }
      var date = new Date(year, month, dayNum)   // rolls into the neighbour month
      var iso = toISO(date)
      var dow = date.getDay()
      cells.push({
        kind: "day",
        iso: iso,
        day: date.getDate(),
        inMonth: inMonth,
        today: iso === today,
        weekend: dow === 0 || dow === 6,
        week: 0,
        count: counts[iso] || 0
      })
    }
  }
  return cells
}

// ------------------------------------------------------------------- events

function normalizeTime(value) {
  var s = trim(value).replace(/\./g, ":")
  if (s === "") return ""
  var m = /^(\d{1,2}):?(\d{2})$/.exec(s)
  if (!m) return ""
  var h = parseInt(m[1], 10), min = parseInt(m[2], 10)
  if (h > 23 || min > 59) return ""
  return pad2(h) + ":" + pad2(min)
}

function minutesOfDay(time) {
  var t = normalizeTime(time)
  if (t === "") return -1
  return parseInt(t.slice(0, 2), 10) * 60 + parseInt(t.slice(3), 10)
}

function normalizeRepeat(value) {
  var s = trim(value).toLowerCase()
  return REPEATS.indexOf(s) === -1 ? "none" : s
}

// A stored event, or null when it is too broken to keep. The id is preserved so
// edits round-trip; missing ids are filled in by the caller through newId().
function normalizeEvent(raw) {
  if (!raw || typeof raw !== "object") return null
  var date = trim(raw.date)
  if (!isISODate(date) || !fromISO(date)) return null
  var title = trim(raw.title)
  if (title === "") return null
  return {
    id: trim(raw.id),
    title: title,
    date: date,
    time: normalizeTime(raw.time),
    durationMin: Math.max(0, Math.round(Number(raw.durationMin) || 0)),
    notes: trim(raw.notes),
    repeat: normalizeRepeat(raw.repeat),
    // "" = forever. Only meaningful with a repeat.
    until: isISODate(raw.until) && fromISO(raw.until) ? trim(raw.until) : ""
  }
}

// Ids only have to be unique inside one file, so the date plus a short random
// tail is plenty and stays readable when the user opens events.json by hand.
function newId(date, randomFn) {
  var rnd = randomFn || Math.random
  var tail = Math.floor(rnd() * 1679616).toString(36)
  while (tail.length < 4) tail = "0" + tail
  return trim(date).replace(/-/g, "") + "-" + tail
}

function ensureIds(events, randomFn) {
  var seen = {}
  var out = []
  for (var i = 0; i < events.length; i++) {
    var e = events[i]
    var id = e.id
    while (id === "" || seen[id]) id = newId(e.date, randomFn)
    seen[id] = true
    out.push({
      id: id, title: e.title, date: e.date, time: e.time,
      durationMin: e.durationMin, notes: e.notes, repeat: e.repeat, until: e.until
    })
  }
  return out
}

function sortEvents(events) {
  // All-day events (time "") sort ahead of timed ones on the same date.
  return events.slice(0).sort(function(a, b) {
    if (a.date !== b.date) return a.date < b.date ? -1 : 1
    var ma = minutesOfDay(a.time), mb = minutesOfDay(b.time)
    if (ma !== mb) return ma - mb
    return a.title < b.title ? -1 : (a.title > b.title ? 1 : 0)
  })
}

function parseStore(raw) {
  var data
  try { data = JSON.parse(String(raw || "")) } catch (e) { data = null }
  var list = data && data.events && data.events.length !== undefined ? data.events : []
  var out = []
  for (var i = 0; i < list.length; i++) {
    var e = normalizeEvent(list[i])
    if (e) out.push(e)
  }
  return sortEvents(ensureIds(out))
}

function serializeStore(events) {
  var list = []
  for (var i = 0; i < events.length; i++) {
    var e = events[i]
    var out = { id: e.id, title: e.title, date: e.date }
    if (e.time !== "") out.time = e.time
    if (e.durationMin > 0) out.durationMin = e.durationMin
    if (e.notes !== "") out.notes = e.notes
    if (e.repeat !== "none") out.repeat = e.repeat
    if (e.until !== "") out.until = e.until
    list.push(out)
  }
  return JSON.stringify({ version: 1, events: list }, null, 2) + "\n"
}

function upsertEvent(events, event) {
  var next = []
  var replaced = false
  for (var i = 0; i < events.length; i++) {
    if (events[i].id !== "" && events[i].id === event.id) { next.push(event); replaced = true }
    else next.push(events[i])
  }
  if (!replaced) next.push(event)
  return sortEvents(next)
}

function removeEvent(events, id) {
  var next = []
  for (var i = 0; i < events.length; i++) if (events[i].id !== id) next.push(events[i])
  return next
}

// ---------------------------------------------------------------- recurrence

// Does `event` land on `iso`? The first occurrence is always event.date; a
// repeat then walks forward only, and stops after `until` when one is set.
function occursOn(event, iso) {
  if (!event || !isISODate(iso)) return false
  if (event.date === iso) return true
  if (event.repeat === "none") return false
  if (iso < event.date) return false
  if (event.until !== "" && iso > event.until) return false

  var start = fromISO(event.date), day = fromISO(iso)
  if (!start || !day) return false

  if (event.repeat === "daily") return true
  if (event.repeat === "weekly") return start.getDay() === day.getDay()
  if (event.repeat === "monthly") {
    // The 31st simply has no occurrence in a 30-day month; it does not slide.
    return start.getDate() === day.getDate()
  }
  if (event.repeat === "yearly") {
    return start.getMonth() === day.getMonth() && start.getDate() === day.getDate()
  }
  return false
}

// Occurrences on one day, in display order. Each is a copy of the event with
// `iso` set to the day asked for and `recurring` telling it apart from the
// original, so the UI can label a repeat without re-deriving anything.
function eventsOn(events, iso) {
  var out = []
  for (var i = 0; i < events.length; i++) {
    if (!occursOn(events[i], iso)) continue
    var e = events[i]
    out.push({
      id: e.id, title: e.title, date: e.date, iso: iso, time: e.time,
      durationMin: e.durationMin, notes: e.notes, repeat: e.repeat, until: e.until,
      recurring: e.repeat !== "none" && e.date !== iso
    })
  }
  return sortEvents(out)
}

// iso -> number of occurrences, over an inclusive date range. The month grid
// uses it for its per-day dots; `days` caps the walk.
function countsInRange(events, fromIso, days) {
  var counts = {}
  var span = Math.max(0, Math.min(400, Math.round(days)))
  var iso = fromIso
  for (var d = 0; d < span; d++) {
    var n = eventsOn(events, iso).length
    if (n > 0) counts[iso] = n
    iso = shiftISO(iso, 1)
  }
  return counts
}

// Counts for a month plus the adjacent-month days the grid shows.
function countsForMonth(events, year, month) {
  var start = shiftISO(toISO(new Date(year, month, 1)), -7)
  return countsInRange(events, start, daysInMonth(year, month) + 14)
}

// The flat "what is coming up" list: occurrences from `fromIso` forward.
function upcoming(events, fromIso, days) {
  var out = []
  var span = Math.max(1, Math.min(400, Math.round(days || 14)))
  var iso = fromIso
  for (var d = 0; d < span; d++) {
    var onDay = eventsOn(events, iso)
    for (var i = 0; i < onDay.length; i++) out.push(onDay[i])
    iso = shiftISO(iso, 1)
  }
  return out
}

// The next occurrence at or after `fromIso`; today's events already past
// `nowMinutes` are skipped so the bar never advertises a finished meeting.
// Pass nowMinutes < 0 to keep every event today.
function nextOccurrence(events, fromIso, nowMinutes, horizonDays) {
  var list = upcoming(events, fromIso, horizonDays || 400)
  for (var i = 0; i < list.length; i++) {
    var e = list[i]
    if (e.iso === fromIso && e.time !== "" && nowMinutes >= 0 && minutesOfDay(e.time) < nowMinutes) continue
    return e
  }
  return null
}

// ------------------------------------------------------------------- parsing

// One line from the add field. Accepted, in any order at the front:
//   "Dentist"                      today, all day
//   "14:30 Dentist"                today at 14:30
//   "2026-10-02 09:00 Standup"     that date at 09:00
//   "tomorrow 09:00 Standup"       relative day
//   "Standup !weekly"              with a repeat anywhere in the line
// Returns { title, date, time, repeat } or null when there is no title left.
function parseAddInput(text, defaultISO, now) {
  var s = trim(text)
  if (s === "") return null

  var repeat = "none"
  s = s.replace(/(^|\s)!([a-z]+)/gi, function(match, space, word) {
    var candidate = normalizeRepeat(word)
    if (candidate === "none" && word.toLowerCase() !== "none") return match
    repeat = candidate
    return " "
  })

  var base = isISODate(defaultISO) ? defaultISO : todayISO(now)
  var date = base
  var time = ""
  var tokens = trim(s).split(/\s+/)

  while (tokens.length > 1) {
    var head = tokens[0]
    var lower = head.toLowerCase()
    if (isISODate(head) && fromISO(head)) { date = head; tokens.shift(); continue }
    if (lower === "today") { date = todayISO(now); tokens.shift(); continue }
    if (lower === "tomorrow") { date = shiftISO(todayISO(now), 1); tokens.shift(); continue }
    if (time === "" && /^\d{1,2}[:.]\d{2}$/.test(head)) {
      var t = normalizeTime(head)
      if (t !== "") { time = t; tokens.shift(); continue }
    }
    break
  }

  var title = trim(tokens.join(" "))
  if (title === "") return null
  return { title: title, date: date, time: time, repeat: repeat }
}

// ---------------------------------------------------------------- formatting

function formatTime(time, use24) {
  var t = normalizeTime(time)
  if (t === "") return ""
  if (use24 !== false) return t
  var h = parseInt(t.slice(0, 2), 10)
  var suffix = h < 12 ? "am" : "pm"
  var h12 = h % 12
  if (h12 === 0) h12 = 12
  return h12 + ":" + t.slice(3) + suffix
}

// "Today", "Tomorrow", "Yesterday", else "Mon 5 Oct" (with the year when it is
// not the year we are standing in).
function relativeDay(iso, todayIso) {
  var date = fromISO(iso)
  if (!date) return ""
  var delta = daysBetween(todayIso, iso)
  if (delta === 0) return "Today"
  if (delta === 1) return "Tomorrow"
  if (delta === -1) return "Yesterday"
  var label = WEEKDAY_SHORT[date.getDay()] + " " + date.getDate() + " " + MONTH_SHORT[date.getMonth()]
  var here = fromISO(todayIso)
  if (here && here.getFullYear() !== date.getFullYear()) label += " " + date.getFullYear()
  return label
}

function formatDayLong(iso) {
  var date = fromISO(iso)
  if (!date) return ""
  return WEEKDAY_SHORT[date.getDay()] + " " + date.getDate() + " " + MONTH_NAMES[date.getMonth()] + " " + date.getFullYear()
}

function eventLine(occurrence, use24) {
  var time = formatTime(occurrence.time, use24)
  return (time === "" ? "All day" : time) + "  " + occurrence.title
}

function barIconGlyph(key) {
  for (var i = 0; i < BAR_ICONS.length; i++) if (BAR_ICONS[i].key === key) return BAR_ICONS[i].glyph
  return BAR_ICONS[0].glyph
}

function normalizeBarMode(value) {
  var s = trim(value).toLowerCase()
  return BAR_MODES.indexOf(s) === -1 ? "next" : s
}

// The text beside the bar icon. `mode` is a BAR_MODES entry; "icon" returns ""
// so the widget falls back to its icon-only button.
//   next  -> "14:30 Dentist" / "Tue Standup", the date when nothing is due
//   date  -> "Mon 5 Oct"
//   count -> "3 today"
function barLabel(options) {
  var o = options || {}
  var mode = normalizeBarMode(o.mode)
  var today = o.todayISO || todayISO()
  if (mode === "icon") return ""
  if (mode === "date") return relativeDayOrDate(today, today)
  if (mode === "count") {
    var n = o.todayCount || 0
    return n === 0 ? "Clear" : n + (n === 1 ? " event" : " events")
  }
  var next = o.next
  if (!next) return relativeDayOrDate(today, today)
  var when = next.iso === today ? formatTime(next.time, o.use24) : relativeDay(next.iso, today)
  if (when === "") when = relativeDay(next.iso, today)
  var title = trim(next.title)
  var cap = Math.max(6, Math.round(o.maxTitle || 18))
  if (title.length > cap) title = title.slice(0, cap - 1) + "…"
  return when + " " + title
}

// The bar's plain-date form: never "Today", always a readable date.
function relativeDayOrDate(iso, todayIso) {
  var date = fromISO(iso)
  if (!date) return ""
  var label = WEEKDAY_SHORT[date.getDay()] + " " + date.getDate() + " " + MONTH_SHORT[date.getMonth()]
  var here = fromISO(todayIso)
  if (here && here.getFullYear() !== date.getFullYear()) label += " " + date.getFullYear()
  return label
}

function tooltipText(options) {
  var o = options || {}
  var today = o.todayISO || todayISO()
  var lines = [formatDayLong(today)]
  var n = o.todayCount || 0
  lines.push(n === 0 ? "Nothing today" : n + (n === 1 ? " event today" : " events today"))
  if (o.next && o.next.iso !== today)
    lines.push("Next: " + relativeDay(o.next.iso, today) + " " + eventLine(o.next, o.use24))
  return lines.join("\n")
}

if (typeof module !== "undefined") {
  module.exports = {
    MONTH_NAMES: MONTH_NAMES,
    MONTH_SHORT: MONTH_SHORT,
    WEEKDAY_SHORT: WEEKDAY_SHORT,
    REPEATS: REPEATS,
    REPEAT_LABELS: REPEAT_LABELS,
    BAR_MODES: BAR_MODES,
    BAR_ICONS: BAR_ICONS,
    pad2: pad2,
    toISO: toISO,
    isISODate: isISODate,
    fromISO: fromISO,
    todayISO: todayISO,
    sameDay: sameDay,
    daysInMonth: daysInMonth,
    shiftISO: shiftISO,
    daysBetween: daysBetween,
    isoWeek: isoWeek,
    addMonths: addMonths,
    monthTitle: monthTitle,
    weekdayLabels: weekdayLabels,
    monthCells: monthCells,
    normalizeTime: normalizeTime,
    minutesOfDay: minutesOfDay,
    normalizeRepeat: normalizeRepeat,
    normalizeEvent: normalizeEvent,
    newId: newId,
    ensureIds: ensureIds,
    sortEvents: sortEvents,
    parseStore: parseStore,
    serializeStore: serializeStore,
    upsertEvent: upsertEvent,
    removeEvent: removeEvent,
    occursOn: occursOn,
    eventsOn: eventsOn,
    countsInRange: countsInRange,
    countsForMonth: countsForMonth,
    upcoming: upcoming,
    nextOccurrence: nextOccurrence,
    parseAddInput: parseAddInput,
    formatTime: formatTime,
    relativeDay: relativeDay,
    relativeDayOrDate: relativeDayOrDate,
    formatDayLong: formatDayLong,
    eventLine: eventLine,
    barIconGlyph: barIconGlyph,
    normalizeBarMode: normalizeBarMode,
    barLabel: barLabel,
    tooltipText: tooltipText
  }
}
