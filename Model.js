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
// The mockup's header row: two letters, upper case.
var WEEKDAY_PAIR = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
var WEEKDAY_LONG = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

// Headline faces to try, in order, before falling back to the theme font. The
// mockup is set in a tight grotesque, which no monospace can stand in for.
var DISPLAY_FAMILIES = ["Inter", "Inter Display", "InterVariable", "Archivo", "Helvetica Neue",
                        "Neue Haas Grotesk Display Pro", "SF Pro Display", "Noto Sans", "Liberation Sans"]

// Event colours are *categorical*, not semantic. Mainstream calendars colour an
// event by which calendar it came from, and let you override per event from a
// fixed palette whose names ("Tomato", "Basil", "Peacock") mean nothing on
// purpose — the bucket is yours to define. So these names are labels, not
// promises about hue: what each one renders as depends on the theme.
//
// `token` is the theme slot it takes in "theme" mode; `slot` is its position on
// the hue wheel in "spread" mode, where the palette is derived from the theme's
// accent so the six stay far enough apart to tell at dot size.
var EVENT_COLORS = [
  { key: "none", token: "", fallback: "", slot: -1 },
  { key: "clay", token: "red", fallback: "#c07a6a", slot: 0 },
  { key: "sand", token: "yellow", fallback: "#c7a76a", slot: 1 },
  { key: "moss", token: "green", fallback: "#7fa87f", slot: 2 },
  { key: "sky", token: "cyan", fallback: "#6fa8b0", slot: 3 },
  { key: "slate", token: "blue", fallback: "#7f95c0", slot: 4 },
  { key: "plum", token: "magenta", fallback: "#a98bbd", slot: 5 }
]

// Stores written before the palette was named this way.
var COLOR_ALIASES = {
  red: "clay", yellow: "sand", green: "moss",
  cyan: "sky", blue: "slate", magenta: "plum", accent: "clay"
}

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

function weekdayPairs(mondayFirst) {
  var base = WEEKDAY_PAIR
  return mondayFirst ? base.slice(1).concat(base.slice(0, 1)) : base.slice(0)
}

// ------------------------------------------------------------------ the grid

// One row per week: { week: 39, days: [cell x7] }, which is how the grid draws
// (a week-number gutter, then seven cells). A cell carries everything the
// delegate needs so no date arithmetic happens in QML:
//   { iso, day, inMonth, today, weekend, count }
// `counts` is an iso -> number map (see countsInRange); omit it for a bare grid.
function monthWeeks(year, month, options) {
  var o = options || {}
  var mondayFirst = o.mondayFirst !== false
  var withAdjacent = o.showAdjacentMonths !== false
  var today = o.todayISO || todayISO()
  var marks = o.marks || {}

  var first = new Date(year, month, 1)
  var total = daysInMonth(year, month)
  var firstDow = first.getDay()
  var lead = mondayFirst ? (firstDow + 6) % 7 : firstDow
  var rows = Math.ceil((lead + total) / 7)

  var weeks = []
  for (var r = 0; r < rows; r++) {
    var days = []
    // Anchor the week number on a real day of this month in the row: the first
    // row can open with days from the previous month, whose week may differ.
    var anchor = null
    for (var c = 0; c < 7; c++) {
      var n = r * 7 + c - lead + 1
      if (anchor === null && n >= 1 && n <= total) anchor = n

      var inMonth = n >= 1 && n <= total
      if (!inMonth && !withAdjacent) {
        days.push({ iso: "", day: 0, inMonth: false, today: false, weekend: false, count: 0, colors: [] })
        continue
      }
      var date = new Date(year, month, n)   // rolls into the neighbouring month
      var iso = toISO(date)
      var dow = date.getDay()
      var mark = marks[iso]
      days.push({
        iso: iso,
        day: date.getDate(),
        inMonth: inMonth,
        today: iso === today,
        weekend: dow === 0 || dow === 6,
        count: mark ? mark.count : 0,
        colors: mark ? mark.colors : []
      })
    }
    var rowStart = days.length > 0 && days[0].iso !== ""
      ? days[0].iso
      : toISO(new Date(year, month, r * 7 - lead + 1))
    weeks.push({
      week: anchor === null ? 0 : isoWeek(new Date(year, month, anchor)),
      start: rowStart,
      days: days,
      segments: o.events ? weekSegments(o.events, rowStart) : []
    })
  }
  return weeks
}

// The same day of the month, `delta` months along, clamped to the length of the
// month it lands in: 31 Jan + 1 month is 28 Feb, not 3 March.
function addMonthsToISO(iso, delta) {
  var date = fromISO(iso)
  if (!date) return iso
  var moved = addMonths(date.getFullYear(), date.getMonth(), Math.round(delta))
  var day = Math.min(date.getDate(), daysInMonth(moved.year, moved.month))
  return toISO(new Date(moved.year, moved.month, day))
}

// The runs crossing one week, as bars the grid can draw: a multi-day event
// clipped to the week it is passing through, with caps telling you whether it
// began here and whether it ends here.
//
//   { id, title, color, startCol, endCol, continuesBefore, continuesAfter, lane }
//
// `lane` is the stacking row inside the week, assigned greedily: each segment
// takes the lowest lane it does not collide in, which is how every calendar
// keeps two overlapping runs from drawing over each other.
function weekSegments(events, weekStartISO, options) {
  var o = options || {}
  var weekStart = weekStartISO
  var weekEnd = shiftISO(weekStart, 6)
  var found = []

  for (var i = 0; i < events.length; i++) {
    var e = events[i]
    var span = Math.max(1, Math.round(e.days || 1))
    if (span < 2) continue                       // single days are dots

    // A run can have begun before this week, so walk back its own length.
    for (var d = -(span - 1); d <= 6; d++) {
      var start = shiftISO(weekStart, d)
      if (start < e.date) continue
      if (!startsOn(e, start)) continue
      var end = shiftISO(start, span - 1)
      if (end < weekStart || start > weekEnd) continue
      found.push({
        id: e.id,
        title: e.title,
        color: e.color,
        startISO: start,
        endISO: end,
        startCol: Math.max(0, daysBetween(weekStart, start)),
        endCol: Math.min(6, daysBetween(weekStart, end)),
        continuesBefore: start < weekStart,
        continuesAfter: end > weekEnd,
        lane: 0
      })
    }
  }

  // Longest first at the same start, so the run that shapes the week sits on top.
  found.sort(function(a, b) {
    if (a.startCol !== b.startCol) return a.startCol - b.startCol
    var lena = a.endCol - a.startCol, lenb = b.endCol - b.startCol
    if (lena !== lenb) return lenb - lena
    return a.title < b.title ? -1 : (a.title > b.title ? 1 : 0)
  })

  var lanes = []                                  // lanes[n] = last column used
  for (var j = 0; j < found.length; j++) {
    var seg = found[j]
    var lane = 0
    while (lanes[lane] !== undefined && lanes[lane] >= seg.startCol) lane++
    lanes[lane] = seg.endCol
    seg.lane = lane
  }
  return found
}

// The Monday (or Sunday) that opens the week `iso` falls in.
function startOfWeek(iso, mondayFirst) {
  var date = fromISO(iso)
  if (!date) return iso
  var dow = date.getDay()
  var back = mondayFirst !== false ? (dow + 6) % 7 : dow
  return shiftISO(iso, -back)
}

// The rolling grid: `count` weeks running forward from the week `startISO`
// opens. Same row shape as monthWeeks() — { week, days: [cell x7] } — so the
// grid delegate does not care which of the two built it. `inMonth` is measured
// against the month the window starts in, which is what dims the days that have
// rolled over into the next one.
function weeksFrom(startISO, count, options) {
  var o = options || {}
  var mondayFirst = o.mondayFirst !== false
  var today = o.todayISO || todayISO()
  var marks = o.marks || {}
  var total = Math.max(1, Math.min(12, Math.round(count || 3)))

  var first = startOfWeek(startISO, mondayFirst)
  var anchorDate = fromISO(o.monthOf || first)
  var anchorMonth = anchorDate ? anchorDate.getMonth() : -1
  var anchorYear = anchorDate ? anchorDate.getFullYear() : -1

  var weeks = []
  for (var w = 0; w < total; w++) {
    var days = []
    for (var d = 0; d < 7; d++) {
      var iso = shiftISO(first, w * 7 + d)
      var date = fromISO(iso)
      if (!date) continue
      var dow = date.getDay()
      var mark = marks[iso]
      days.push({
        iso: iso,
        day: date.getDate(),
        inMonth: date.getMonth() === anchorMonth && date.getFullYear() === anchorYear,
        today: iso === today,
        weekend: dow === 0 || dow === 6,
        count: mark ? mark.count : 0,
        colors: mark ? mark.colors : []
      })
    }
    var weekStart = shiftISO(first, w * 7)
    weeks.push({
      week: isoWeek(fromISO(weekStart)),
      start: weekStart,
      days: days,
      segments: o.events ? weekSegments(o.events, weekStart) : []
    })
  }
  return weeks
}

// What the pager under a rolling window says: one month when the window sits
// inside one, otherwise the two it spans.
function windowLabel(startISO, endISO) {
  var from = fromISO(startISO), to = fromISO(endISO)
  if (!from) return ""
  if (!to) return upperMonth(from.getFullYear(), from.getMonth())
  if (from.getFullYear() === to.getFullYear() && from.getMonth() === to.getMonth())
    return upperMonth(from.getFullYear(), from.getMonth())
  var left = MONTH_SHORT[from.getMonth()].toUpperCase()
  var right = MONTH_SHORT[to.getMonth()].toUpperCase()
  if (from.getFullYear() !== to.getFullYear())
    return left + " " + from.getFullYear() + " – " + right + " " + to.getFullYear()
  return left + " – " + right + " " + to.getFullYear()
}

// The year view: twelve months, each with its own weeks, for the mini grids.
function yearMonths(year, options) {
  var months = []
  for (var m = 0; m < 12; m++) {
    months.push({
      month: m,
      name: MONTH_NAMES[m],
      short: MONTH_SHORT[m],
      weeks: monthWeeks(year, m, {
        mondayFirst: (options || {}).mondayFirst !== false,
        showAdjacentMonths: false,
        todayISO: (options || {}).todayISO,
        marks: (options || {}).marks || {}
      })
    })
  }
  return months
}

// How far through the year `todayIso` stands, as 0..1. A year already over
// reads 1, one not yet begun reads 0, so the meter is honest while browsing.
function yearProgress(year, todayIso) {
  var today = fromISO(todayIso || todayISO())
  if (!today) return 0
  if (today.getFullYear() > year) return 1
  if (today.getFullYear() < year) return 0
  var startOfYear = new Date(year, 0, 1)
  var days = Math.round((Date.UTC(today.getFullYear(), today.getMonth(), today.getDate())
                       - Date.UTC(year, 0, 1)) / 86400000)
  var total = (new Date(year, 11, 31).getTime() - startOfYear.getTime()) / 86400000 + 1
  return Math.max(0, Math.min(1, days / total))
}

// The theme's colors.toml, as { token: "#rrggbb" }.
function parsePalette(text) {
  var out = {}
  var re = /^\s*([a-z_]+)\s*=\s*"(#[0-9a-fA-F]{6})(?:[0-9a-fA-F]{2})?"/gm
  var m
  while ((m = re.exec(String(text || ""))) !== null) out[m[1]] = m[2].toLowerCase()
  return out
}

function normalizeColor(value) {
  var key = trim(value).toLowerCase()
  for (var i = 0; i < EVENT_COLORS.length; i++) if (EVENT_COLORS[i].key === key) return key
  return COLOR_ALIASES[key] || "none"
}

function colorEntry(key) {
  var wanted = normalizeColor(key)
  for (var i = 0; i < EVENT_COLORS.length; i++) if (EVENT_COLORS[i].key === wanted) return EVENT_COLORS[i]
  return null
}

// --- hue maths ----------------------------------------------------------------

function hexToHsl(hex) {
  var clean = trim(hex).replace("#", "")
  if (!/^[0-9a-fA-F]{6}/.test(clean)) return null
  var r = parseInt(clean.slice(0, 2), 16) / 255
  var g = parseInt(clean.slice(2, 4), 16) / 255
  var b = parseInt(clean.slice(4, 6), 16) / 255
  var max = Math.max(r, g, b), min = Math.min(r, g, b)
  var l = (max + min) / 2
  if (max === min) return { h: 0, s: 0, l: l }
  var d = max - min
  var s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
  var h
  if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6
  else if (max === g) h = ((b - r) / d + 2) / 6
  else h = ((r - g) / d + 4) / 6
  return { h: h * 360, s: s, l: l }
}

function hslToHex(h, s, l) {
  var hue = ((h % 360) + 360) % 360 / 360
  function channel(p, q, t) {
    if (t < 0) t += 1
    if (t > 1) t -= 1
    if (t < 1 / 6) return p + (q - p) * 6 * t
    if (t < 1 / 2) return q
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6
    return p
  }
  var r, g, b
  if (s === 0) { r = g = b = l }
  else {
    var q = l < 0.5 ? l * (1 + s) : l + s - l * s
    var p = 2 * l - q
    r = channel(p, q, hue + 1 / 3)
    g = channel(p, q, hue)
    b = channel(p, q, hue - 1 / 3)
  }
  function hex2(v) {
    var n = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16)
    return n.length < 2 ? "0" + n : n
  }
  return "#" + hex2(r) + hex2(g) + hex2(b)
}

// Six hues spread evenly from the theme's accent, at a saturation and lightness
// that keep them legible on the panel. A near-grey accent still yields colours:
// without a floor on saturation the "palette" would be six greys.
function spreadHex(accentHex, slot, count, dark) {
  var base = hexToHsl(accentHex) || { h: 210, s: 0.35, l: 0.62 }
  var total = Math.max(1, Math.round(count || 6))
  var sat = Math.max(0.34, Math.min(0.68, base.s))
  var lum = dark === false
    ? Math.max(0.36, Math.min(0.52, base.l))
    : Math.max(0.56, Math.min(0.74, base.l))
  return hslToHex(base.h + (360 / total) * slot, sat, lum)
}

// What an event's colour resolves to, or "" for an uncoloured event, which the
// view then draws in its ordinary ink.
//   mode "spread" (default) — derived from the accent, maximally distinct
//   mode "theme"            — the theme's own red/green/blue/... slots
function colorHex(palette, key, mode, dark) {
  var entry = colorEntry(key)
  if (!entry || entry.key === "none") return ""
  if (String(mode) === "theme") {
    var themed = palette ? palette[entry.token] : ""
    return themed || entry.fallback
  }
  var accent = (palette && palette.accent) ? palette.accent : ""
  if (accent === "") return entry.fallback
  return spreadHex(accent, entry.slot, 6, dark !== false)
}

// ------------------------------------------------------------------- events// ------------------------------------------------------------------- events

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
  // `days` is the span, counting the first day. `endDate` is accepted as sugar
  // for hand-edited files and folded into it, because a repeat has to carry a
  // length rather than a fixed end: each occurrence gets the same span.
  var days = Math.round(Number(raw.days) || 0)
  if (days < 1 && isISODate(raw.endDate) && fromISO(raw.endDate)) {
    var spanned = daysBetween(date, raw.endDate) + 1
    if (spanned > 1) days = spanned
  }
  return {
    id: trim(raw.id),
    title: title,
    date: date,
    days: Math.max(1, Math.min(366, days || 1)),
    time: normalizeTime(raw.time),
    durationMin: Math.max(0, Math.round(Number(raw.durationMin) || 0)),
    notes: trim(raw.notes),
    location: trim(raw.location),
    color: normalizeColor(raw.color),
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
      id: id, title: e.title, date: e.date, days: e.days, time: e.time,
      durationMin: e.durationMin, notes: e.notes, location: e.location,
      color: e.color, repeat: e.repeat, until: e.until
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
    if (e.days > 1) out.days = e.days
    if (e.time !== "") out.time = e.time
    if (e.durationMin > 0) out.durationMin = e.durationMin
    if (e.notes !== "") out.notes = e.notes
    if (e.location !== "") out.location = e.location
    if (e.color !== "none") out.color = e.color
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

// Does an occurrence *begin* on `iso`? The first is always event.date; a repeat
// then walks forward only, and stops after `until` when one is set.
function startsOn(event, iso) {
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

// The day an occurrence covering `iso` began, or "" when none does. A one-day
// event only covers its own start; a span reaches back up to days-1.
function occurrenceStart(event, iso) {
  if (!event || !isISODate(iso)) return ""
  var span = Math.max(1, Math.round(event.days || 1))
  for (var back = 0; back < span; back++) {
    var candidate = shiftISO(iso, -back)
    if (candidate < event.date) break        // before the series began
    if (startsOn(event, candidate)) return candidate
  }
  return ""
}

function occursOn(event, iso) {
  return occurrenceStart(event, iso) !== ""
}

// Occurrences on one day, in display order. Each is a copy of the event with
// `iso` set to the day asked for and `recurring` telling it apart from the
// original, so the UI can label a repeat without re-deriving anything.
function eventsOn(events, iso) {
  var out = []
  for (var i = 0; i < events.length; i++) {
    var e = events[i]
    var start = occurrenceStart(e, iso)
    if (start === "") continue
    var span = Math.max(1, Math.round(e.days || 1))
    var index = daysBetween(start, iso)
    out.push({
      id: e.id, title: e.title, date: e.date, iso: iso, time: e.time,
      durationMin: e.durationMin, notes: e.notes, location: e.location, color: e.color,
      repeat: e.repeat, until: e.until,
      // Where this day sits in the run: the grid draws caps from it, and the
      // agenda says "day 2 of 4" rather than repeating the start time.
      days: span,
      startISO: start,
      endISO: shiftISO(start, span - 1),
      dayIndex: index,
      isStart: index === 0,
      isEnd: index === span - 1,
      spans: span > 1,
      recurring: e.repeat !== "none" && e.date !== start
    })
  }
  return sortOccurrences(out)
}

// A day reads top down: runs that pass through it first (they are the day's
// shape), then all-day events, then the timed ones in order.
function sortOccurrences(list) {
  return list.slice(0).sort(function(a, b) {
    if (a.spans !== b.spans) return a.spans ? -1 : 1
    if (a.spans && b.spans && a.days !== b.days) return b.days - a.days
    var ma = minutesOfDay(a.time), mb = minutesOfDay(b.time)
    if (ma !== mb) return ma - mb
    return a.title < b.title ? -1 : (a.title > b.title ? 1 : 0)
  })
}

// iso -> { count, colors: [key, ...] } over an inclusive date range. The grid
// draws one dot per event in the day's own colours, so it needs the keys in
// display order, not just a tally. `days` caps the walk.
function marksInRange(events, fromIso, days) {
  var marks = {}
  var span = Math.max(0, Math.min(400, Math.round(days)))
  var iso = fromIso
  for (var d = 0; d < span; d++) {
    var onDay = eventsOn(events, iso)
    if (onDay.length > 0) {
      // Only single-day events become dots; a run is drawn as a bar across the
      // days it covers, so a dot under it would say the same thing twice.
      var colors = []
      for (var i = 0; i < onDay.length; i++) if (!onDay[i].spans) colors.push(onDay[i].color)
      marks[iso] = { count: onDay.length, colors: colors }
    }
    iso = shiftISO(iso, 1)
  }
  return marks
}

// The same walk when only the tally matters (the year page's miniatures).
function countsInRange(events, fromIso, days) {
  var marks = marksInRange(events, fromIso, days)
  var counts = {}
  for (var iso in marks) counts[iso] = marks[iso].count
  return counts
}

// Marks for a month plus the adjacent-month days the grid shows.
function marksForMonth(events, year, month) {
  var start = shiftISO(toISO(new Date(year, month, 1)), -7)
  return marksInRange(events, start, daysInMonth(year, month) + 14)
}

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

// "15:00" from a start and a length; "" when either is missing.
function endTime(time, durationMin) {
  var start = minutesOfDay(time)
  var length = Math.round(Number(durationMin) || 0)
  if (start < 0 || length <= 0) return ""
  var end = (start + length) % 1440
  return pad2(Math.floor(end / 60)) + ":" + pad2(end % 60)
}

// "28 Sep → 2 Oct" for a run, with "Day 3/5" in front once you are inside it and
// the time appended when it has one. A run's shape matters more than its clock.
function spanLabel(occurrence, use24) {
  if (!occurrence || !occurrence.spans) return ""
  var from = fromISO(occurrence.startISO), to = fromISO(occurrence.endISO)
  if (!from || !to) return ""
  var range = from.getDate() + " " + MONTH_SHORT[from.getMonth()]
             + " → " + to.getDate() + " " + MONTH_SHORT[to.getMonth()]
  var parts = []
  if (!occurrence.isStart) parts.push("Day " + (occurrence.dayIndex + 1) + "/" + occurrence.days)
  parts.push(range)
  var time = formatTime(occurrence.time, use24)
  if (time !== "") parts.push(time)
  return parts.join("  ·  ")
}

// "14:00 – 15:00", "14:00", or "All day" — the event card's time line.
function timeRange(occurrence, use24) {
  if (!occurrence) return ""
  var start = formatTime(occurrence.time, use24)
  if (start === "") return "All day"
  var end = formatTime(endTime(occurrence.time, occurrence.durationMin), use24)
  return end === "" ? start : start + " – " + end
}

// "SATURDAY, SEPTEMBER 26" — the day heading over the agenda.
function dayHeading(iso) {
  var date = fromISO(iso)
  if (!date) return ""
  return (WEEKDAY_LONG[date.getDay()] + ", " + MONTH_NAMES[date.getMonth()] + " " + date.getDate()).toUpperCase()
}

// "SEPTEMBER 2026" — the footer's month label.
function upperMonth(year, month) {
  return (MONTH_NAMES[month] + " " + year).toUpperCase()
}

// "No events" / "1 event" / "3 events".
function countLabel(n) {
  var count = Math.max(0, Math.round(Number(n) || 0))
  if (count === 0) return "No events"
  return count + (count === 1 ? " event" : " events")
}

// Percent, for the year meter's label.
function percentLabel(fraction) {
  return Math.round(Math.max(0, Math.min(1, Number(fraction) || 0)) * 100) + "%"
}

// The headline face: the first of `preferred` that is actually installed, else
// the theme's family. Qt.fontFamilies() is passed in so this stays pure.
function pickFamily(available, preferred, fallback) {
  var list = available || []
  var wanted = preferred || DISPLAY_FAMILIES
  var have = {}
  for (var i = 0; i < list.length; i++) have[String(list[i]).toLowerCase()] = String(list[i])
  for (var j = 0; j < wanted.length; j++) {
    var hit = have[String(wanted[j]).toLowerCase()]
    if (hit) return hit
  }
  return fallback || ""
}

if (typeof module !== "undefined") {
  module.exports = {
    MONTH_NAMES: MONTH_NAMES,
    MONTH_SHORT: MONTH_SHORT,
    WEEKDAY_SHORT: WEEKDAY_SHORT,
    WEEKDAY_LONG: WEEKDAY_LONG,
    DISPLAY_FAMILIES: DISPLAY_FAMILIES,
    REPEATS: REPEATS,
    EVENT_COLORS: EVENT_COLORS,
    COLOR_ALIASES: COLOR_ALIASES,
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
    weekdayPairs: weekdayPairs,
    monthWeeks: monthWeeks,
    startOfWeek: startOfWeek,
    weekSegments: weekSegments,
    startsOn: startsOn,
    occurrenceStart: occurrenceStart,
    addMonthsToISO: addMonthsToISO,
    weeksFrom: weeksFrom,
    windowLabel: windowLabel,
    yearMonths: yearMonths,
    yearProgress: yearProgress,
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
    marksInRange: marksInRange,
    marksForMonth: marksForMonth,
    parsePalette: parsePalette,
    normalizeColor: normalizeColor,
    colorHex: colorHex,
    colorEntry: colorEntry,
    hexToHsl: hexToHsl,
    hslToHex: hslToHex,
    spreadHex: spreadHex,
    upcoming: upcoming,
    nextOccurrence: nextOccurrence,
    parseAddInput: parseAddInput,
    formatTime: formatTime,
    endTime: endTime,
    timeRange: timeRange,
    spanLabel: spanLabel,
    dayHeading: dayHeading,
    upperMonth: upperMonth,
    countLabel: countLabel,
    percentLabel: percentLabel,
    pickFamily: pickFamily,
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
