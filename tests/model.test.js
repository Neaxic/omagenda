const test = require("node:test")
const assert = require("node:assert/strict")
const M = require("../Model.js")

function ev(over) {
  return M.normalizeEvent(Object.assign({ id: "x", title: "Thing", date: "2026-09-26" }, over || {}))
}

// --- dates ------------------------------------------------------------------

test("fromISO rejects days that do not exist", () => {
  assert.equal(M.fromISO("2026-02-30"), null)
  assert.equal(M.fromISO("2026-13-01"), null)
  assert.equal(M.fromISO("26-01-01"), null)
  assert.equal(M.toISO(M.fromISO("2026-02-28")), "2026-02-28")
})

test("isoWeek follows the first-Thursday rule", () => {
  assert.equal(M.isoWeek(new Date(2026, 0, 1)), 1)
  assert.equal(M.isoWeek(new Date(2026, 8, 26)), 39)
  // 2027-01-01 is a Friday, so it belongs to the last week of 2026.
  assert.equal(M.isoWeek(new Date(2027, 0, 1)), 53)
})

test("shiftISO and daysBetween cross month and year ends", () => {
  assert.equal(M.shiftISO("2026-09-30", 1), "2026-10-01")
  assert.equal(M.shiftISO("2027-01-01", -1), "2026-12-31")
  assert.equal(M.daysBetween("2026-09-26", "2026-10-03"), 7)
  assert.equal(M.daysBetween("2026-10-03", "2026-09-26"), -7)
})

test("addMonths wraps the year in both directions", () => {
  assert.deepEqual(M.addMonths(2026, 11, 1), { year: 2027, month: 0 })
  assert.deepEqual(M.addMonths(2026, 0, -1), { year: 2025, month: 11 })
})

// --- the grid ---------------------------------------------------------------

test("monthCells lays out a month Monday-first with week numbers", () => {
  const cells = M.monthCells(2026, 8, { mondayFirst: true, todayISO: "2026-09-26" })
  // September 2026 starts on a Tuesday and has 30 days: 5 rows of 7 + 5 week cells.
  assert.equal(cells.length, 5 * 8)
  assert.equal(cells[0].kind, "week")
  assert.equal(cells[0].week, 36)
  const first = cells.find(c => c.iso === "2026-09-01")
  assert.equal(first.inMonth, true)
  // One leading day from August fills the Monday slot.
  assert.equal(cells[1].iso, "2026-08-31")
  assert.equal(cells[1].inMonth, false)
  const today = cells.find(c => c.today)
  assert.equal(today.iso, "2026-09-26")
  assert.equal(today.weekend, true)
})

test("monthCells blanks the neighbours when adjacent months are off", () => {
  const cells = M.monthCells(2026, 8, { mondayFirst: true, showWeekNumbers: false, showAdjacentMonths: false })
  assert.equal(cells.length, 35)
  assert.equal(cells[0].kind, "blank")
  assert.equal(cells[1].iso, "2026-09-01")
})

test("monthCells carries per-day counts", () => {
  const events = [ev({ date: "2026-09-10" }), ev({ id: "y", date: "2026-09-10", title: "Other" })]
  const counts = M.countsForMonth(events, 2026, 8)
  const cells = M.monthCells(2026, 8, { counts })
  assert.equal(cells.find(c => c.iso === "2026-09-10").count, 2)
  assert.equal(cells.find(c => c.iso === "2026-09-11").count, 0)
})

test("weekdayLabels rotates for a Monday start", () => {
  assert.deepEqual(M.weekdayLabels(true), ["M", "T", "W", "T", "F", "S", "S"])
  assert.deepEqual(M.weekdayLabels(false), ["S", "M", "T", "W", "T", "F", "S"])
})

// --- the store --------------------------------------------------------------

test("normalizeEvent drops the unusable and cleans the rest", () => {
  assert.equal(M.normalizeEvent({ title: "No date" }), null)
  assert.equal(M.normalizeEvent({ title: "  ", date: "2026-09-26" }), null)
  const e = M.normalizeEvent({ id: " a ", title: " Dentist ", date: "2026-09-26", time: "9.5", repeat: "WEEKLY" })
  assert.equal(e.title, "Dentist")
  assert.equal(e.repeat, "weekly")
  assert.equal(e.time, "")          // 9.5 is not a time
  const t = M.normalizeEvent({ title: "T", date: "2026-09-26", time: "9:05" })
  assert.equal(t.time, "09:05")
})

test("parseStore survives junk and fills in missing ids", () => {
  assert.deepEqual(M.parseStore("not json"), [])
  assert.deepEqual(M.parseStore(""), [])
  const events = M.parseStore(JSON.stringify({
    version: 1,
    events: [{ title: "B", date: "2026-09-27" }, { title: "A", date: "2026-09-26" }, { nope: true }]
  }))
  assert.equal(events.length, 2)
  assert.equal(events[0].date, "2026-09-26")     // sorted
  assert.ok(events[0].id.length > 0)
  assert.notEqual(events[0].id, events[1].id)
})

test("a store round-trips through serialize and parse", () => {
  const events = [ev({ time: "14:30", repeat: "weekly", notes: "bring x", durationMin: 45 })]
  const back = M.parseStore(M.serializeStore(events))
  assert.deepEqual(back, events)
  // Defaults stay out of the file so hand-editing it is pleasant.
  assert.equal(M.serializeStore([ev()]).includes("repeat"), false)
})

test("sortEvents puts all-day first, then by time", () => {
  const list = M.sortEvents([
    ev({ id: "1", time: "14:30", title: "PM" }),
    ev({ id: "2", time: "", title: "Allday" }),
    ev({ id: "3", time: "09:00", title: "AM" })
  ])
  assert.deepEqual(list.map(e => e.title), ["Allday", "AM", "PM"])
})

test("upsertEvent replaces by id and removeEvent drops by id", () => {
  const base = [ev({ id: "a" }), ev({ id: "b", date: "2026-09-27" })]
  const edited = M.upsertEvent(base, ev({ id: "b", date: "2026-09-27", title: "Renamed" }))
  assert.equal(edited.length, 2)
  assert.equal(edited.find(e => e.id === "b").title, "Renamed")
  const added = M.upsertEvent(base, ev({ id: "c", date: "2026-09-20" }))
  assert.equal(added.length, 3)
  assert.equal(added[0].id, "c")                  // re-sorted
  assert.deepEqual(M.removeEvent(base, "a").map(e => e.id), ["b"])
})

// --- recurrence -------------------------------------------------------------

test("repeats only ever walk forward from their own date", () => {
  const weekly = ev({ date: "2026-09-26", repeat: "weekly" })
  assert.equal(M.occursOn(weekly, "2026-09-26"), true)
  assert.equal(M.occursOn(weekly, "2026-10-03"), true)
  assert.equal(M.occursOn(weekly, "2026-10-02"), false)
  assert.equal(M.occursOn(weekly, "2026-09-19"), false)   // before the start
})

test("a monthly repeat on the 31st skips the short months", () => {
  const monthly = ev({ date: "2026-01-31", repeat: "monthly" })
  assert.equal(M.occursOn(monthly, "2026-03-31"), true)
  assert.equal(M.occursOn(monthly, "2026-02-28"), false)
})

test("yearly repeats match month and day; until ends a series", () => {
  const yearly = ev({ date: "2026-09-26", repeat: "yearly" })
  assert.equal(M.occursOn(yearly, "2031-09-26"), true)
  const bounded = ev({ date: "2026-09-26", repeat: "daily", until: "2026-09-28" })
  assert.equal(M.occursOn(bounded, "2026-09-28"), true)
  assert.equal(M.occursOn(bounded, "2026-09-29"), false)
})

test("eventsOn marks later occurrences as recurring", () => {
  const events = [ev({ id: "w", date: "2026-09-26", repeat: "weekly" })]
  assert.equal(M.eventsOn(events, "2026-09-26")[0].recurring, false)
  const later = M.eventsOn(events, "2026-10-03")[0]
  assert.equal(later.recurring, true)
  assert.equal(later.iso, "2026-10-03")
  assert.equal(later.date, "2026-09-26")          // the series still points home
})

test("nextOccurrence skips what is already over today", () => {
  const events = [
    ev({ id: "a", date: "2026-09-26", time: "09:00", title: "Morning" }),
    ev({ id: "b", date: "2026-09-26", time: "17:00", title: "Evening" })
  ]
  assert.equal(M.nextOccurrence(events, "2026-09-26", 12 * 60).title, "Evening")
  assert.equal(M.nextOccurrence(events, "2026-09-26", -1).title, "Morning")
  assert.equal(M.nextOccurrence(events, "2026-09-27", 0), null)
  // An all-day event today is never "past".
  const allday = [ev({ id: "c", date: "2026-09-26", time: "", title: "Holiday" })]
  assert.equal(M.nextOccurrence(allday, "2026-09-26", 23 * 60).title, "Holiday")
})

test("upcoming walks a window and keeps day order", () => {
  const events = [ev({ id: "d", date: "2026-09-26", repeat: "daily" })]
  assert.equal(M.upcoming(events, "2026-09-26", 3).length, 3)
  assert.deepEqual(M.upcoming(events, "2026-09-26", 2).map(e => e.iso),
                   ["2026-09-26", "2026-09-27"])
})

// --- the add field ----------------------------------------------------------

test("parseAddInput reads a bare title", () => {
  assert.deepEqual(M.parseAddInput("Dentist", "2026-09-26"),
                   { title: "Dentist", date: "2026-09-26", time: "", repeat: "none" })
  assert.equal(M.parseAddInput("   ", "2026-09-26"), null)
  assert.equal(M.parseAddInput("14:30", "2026-09-26").title, "14:30")  // a time alone is a title
})

test("parseAddInput picks up a time, a date and a repeat", () => {
  assert.deepEqual(M.parseAddInput("14:30 Dentist", "2026-09-26"),
                   { title: "Dentist", date: "2026-09-26", time: "14:30", repeat: "none" })
  assert.deepEqual(M.parseAddInput("2026-10-02 9.00 Standup", "2026-09-26"),
                   { title: "Standup", date: "2026-10-02", time: "09:00", repeat: "none" })
  assert.deepEqual(M.parseAddInput("Standup !weekly", "2026-09-26"),
                   { title: "Standup", date: "2026-09-26", time: "", repeat: "weekly" })
  const rel = M.parseAddInput("tomorrow 08:15 Flight", "2026-09-26", new Date(2026, 8, 26))
  assert.equal(rel.date, "2026-09-27")
  assert.equal(rel.time, "08:15")
})

test("parseAddInput leaves an unknown bang word in the title", () => {
  const e = M.parseAddInput("Ship !now", "2026-09-26")
  assert.equal(e.title, "Ship !now")
  assert.equal(e.repeat, "none")
})

// --- labels -----------------------------------------------------------------

test("formatTime honours the 12-hour setting", () => {
  assert.equal(M.formatTime("14:30", true), "14:30")
  assert.equal(M.formatTime("14:30", false), "2:30pm")
  assert.equal(M.formatTime("00:05", false), "12:05am")
  assert.equal(M.formatTime("", false), "")
})

test("relativeDay names the near days and dates the rest", () => {
  assert.equal(M.relativeDay("2026-09-26", "2026-09-26"), "Today")
  assert.equal(M.relativeDay("2026-09-27", "2026-09-26"), "Tomorrow")
  assert.equal(M.relativeDay("2026-09-25", "2026-09-26"), "Yesterday")
  assert.equal(M.relativeDay("2026-10-05", "2026-09-26"), "Mon 5 Oct")
  assert.equal(M.relativeDay("2027-01-04", "2026-09-26"), "Mon 4 Jan 2027")
})

test("barLabel reflects the mode it is given", () => {
  const next = M.eventsOn([ev({ time: "14:30", title: "Dentist" })], "2026-09-26")[0]
  assert.equal(M.barLabel({ mode: "next", next, todayISO: "2026-09-26" }), "14:30 Dentist")
  assert.equal(M.barLabel({ mode: "date", todayISO: "2026-09-26" }), "Sat 26 Sep")
  assert.equal(M.barLabel({ mode: "count", todayCount: 3, todayISO: "2026-09-26" }), "3 events")
  assert.equal(M.barLabel({ mode: "count", todayCount: 0, todayISO: "2026-09-26" }), "Clear")
  assert.equal(M.barLabel({ mode: "icon", next, todayISO: "2026-09-26" }), "")
  // Nothing coming up falls back to the date.
  assert.equal(M.barLabel({ mode: "next", next: null, todayISO: "2026-09-26" }), "Sat 26 Sep")
})

test("barLabel truncates a long title and dates a future one", () => {
  const long = M.eventsOn([ev({ title: "Quarterly planning workshop", time: "10:00" })], "2026-09-26")[0]
  assert.equal(M.barLabel({ mode: "next", next: long, todayISO: "2026-09-26", maxTitle: 10 }),
               "10:00 Quarterly…")
  const future = M.eventsOn([ev({ date: "2026-09-28", title: "Review", time: "10:00" })], "2026-09-28")[0]
  assert.equal(M.barLabel({ mode: "next", next: future, todayISO: "2026-09-26" }), "Mon 28 Sep Review")
})

test("barIconGlyph falls back to the calendar glyph", () => {
  assert.equal(M.barIconGlyph("none"), "")
  assert.equal(M.barIconGlyph("nope"), M.barIconGlyph("calendar"))
})
