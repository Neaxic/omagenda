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

test("monthWeeks lays out a month Monday-first with week numbers", () => {
  const weeks = M.monthWeeks(2026, 8, { mondayFirst: true, todayISO: "2026-09-26" })
  // September 2026 starts on a Tuesday and has 30 days: five rows.
  assert.equal(weeks.length, 5)
  assert.deepEqual(weeks.map(w => w.week), [36, 37, 38, 39, 40])
  assert.equal(weeks[0].days.length, 7)
  // One leading day from August fills the Monday slot.
  assert.equal(weeks[0].days[0].iso, "2026-08-31")
  assert.equal(weeks[0].days[0].inMonth, false)
  assert.equal(weeks[0].days[1].iso, "2026-09-01")
  assert.equal(weeks[0].days[1].inMonth, true)
  const today = weeks[3].days.find(d => d.today)
  assert.equal(today.iso, "2026-09-26")
  assert.equal(today.weekend, true)
})

test("monthWeeks blanks the neighbours when adjacent months are off", () => {
  const weeks = M.monthWeeks(2026, 8, { mondayFirst: true, showAdjacentMonths: false })
  assert.equal(weeks[0].days[0].iso, "")
  assert.equal(weeks[0].days[0].day, 0)
  assert.equal(weeks[0].days[1].iso, "2026-09-01")
})

test("monthWeeks carries per-day marks", () => {
  const events = [ev({ date: "2026-09-10" }), ev({ id: "y", date: "2026-09-10", title: "Other" })]
  const marks = M.marksForMonth(events, 2026, 8)
  const weeks = M.monthWeeks(2026, 8, { marks })
  const all = weeks.reduce((acc, w) => acc.concat(w.days), [])
  assert.equal(all.find(d => d.iso === "2026-09-10").count, 2)
  assert.equal(all.find(d => d.iso === "2026-09-11").count, 0)
})

test("marks carry each day's event colours in display order", () => {
  const events = [
    ev({ id: "a", date: "2026-09-29", time: "14:00", title: "PM", color: "moss" }),
    ev({ id: "b", date: "2026-09-29", time: "09:00", title: "AM", color: "plum" }),
    ev({ id: "c", date: "2026-09-29", time: "11:00", title: "Plain" })
  ]
  const marks = M.marksInRange(events, "2026-09-29", 1)
  assert.equal(marks["2026-09-29"].count, 3)
  // Sorted by time, so the colours arrive in the order the day reads.
  assert.deepEqual(marks["2026-09-29"].colors, ["plum", "none", "moss"])
  assert.deepEqual(M.countsInRange(events, "2026-09-29", 1), { "2026-09-29": 3 })
})

test("an event colour is a palette slot that survives the store", () => {
  assert.equal(M.normalizeEvent({ title: "T", date: "2026-09-26", color: "MOSS" }).color, "moss")
  assert.equal(M.normalizeEvent({ title: "T", date: "2026-09-26", color: "puce" }).color, "none")
  assert.equal(M.normalizeEvent({ title: "T", date: "2026-09-26" }).color, "none")
  // Stores written with the old terminal-colour names still read.
  assert.equal(M.normalizeEvent({ title: "T", date: "2026-09-26", color: "green" }).color, "moss")
  const back = M.parseStore(M.serializeStore([ev({ color: "sky" })]))
  assert.equal(back[0].color, "sky")
  // An uncoloured event writes no colour key at all.
  assert.equal(M.serializeStore([ev()]).includes("color"), false)
})

test("theme mode takes the theme's own slots, spread derives from the accent", () => {
  const pal = { accent: "#b59790", green: "#87a9b0" }
  assert.equal(M.colorHex(pal, "moss", "theme"), "#87a9b0")
  assert.equal(M.colorHex({}, "moss", "theme"), "#7fa87f")   // the built-in fallback
  assert.equal(M.colorHex(pal, "none", "spread"), "")
  assert.equal(M.colorHex(pal, "nonsense", "spread"), "")
  // Spread keeps the accent's character but pushes the hues apart.
  const spread = M.EVENT_COLORS.slice(1).map(c => M.colorHex(pal, c.key, "spread"))
  assert.equal(new Set(spread).size, 6)
  const hues = spread.map(hex => Math.round(M.hexToHsl(hex).h))
  for (let i = 1; i < hues.length; i++) {
    const gap = Math.abs(hues[i] - hues[i - 1])
    assert.ok(gap > 40, `hues ${hues[i - 1]} and ${hues[i]} are too close`)
  }
})

test("a near-grey accent still yields colours, not six greys", () => {
  const spread = M.EVENT_COLORS.slice(1).map(c => M.colorHex({ accent: "#888888" }, c.key, "spread"))
  assert.equal(new Set(spread).size, 6)
  spread.forEach(hex => assert.ok(M.hexToHsl(hex).s >= 0.33, hex + " is too grey"))
})

test("hsl round-trips through hex", () => {
  const hsl = M.hexToHsl("#87a9b0")
  assert.equal(M.hslToHex(hsl.h, hsl.s, hsl.l), "#87a9b0")
  assert.equal(M.hexToHsl("nope"), null)
})

test("parsePalette reads the theme's colors.toml", () => {
  const pal = M.parsePalette('mode = "dark"\naccent = "#b59790"\nred = "#c38b7b"\nbad = 3\n')
  assert.equal(pal.accent, "#b59790")
  assert.equal(pal.red, "#c38b7b")
  assert.equal(pal.bad, undefined)
})

test("startOfWeek finds the day the week opens on", () => {
  // 2026-09-26 is a Saturday.
  assert.equal(M.startOfWeek("2026-09-26", true), "2026-09-21")
  assert.equal(M.startOfWeek("2026-09-26", false), "2026-09-20")
  assert.equal(M.startOfWeek("2026-09-21", true), "2026-09-21")
  // A Sunday belongs to the week that opened the Monday before it.
  assert.equal(M.startOfWeek("2026-09-27", true), "2026-09-21")
})

test("weeksFrom rolls forward from the week it is given", () => {
  const weeks = M.weeksFrom("2026-09-26", 3, { todayISO: "2026-09-26" })
  assert.equal(weeks.length, 3)
  assert.deepEqual(weeks.map(w => w.week), [39, 40, 41])
  assert.equal(weeks[0].days[0].iso, "2026-09-21")
  assert.equal(weeks[2].days[6].iso, "2026-10-11")
  // Every cell is a real day — a rolling window has no blanks to pad.
  const all = weeks.reduce((acc, w) => acc.concat(w.days), [])
  assert.equal(all.length, 21)
  assert.equal(all.filter(d => d.iso === "").length, 0)
  assert.equal(all.filter(d => d.today).length, 1)
})

test("weeksFrom dims the days that have rolled into the next month", () => {
  const weeks = M.weeksFrom("2026-09-26", 3, {})
  assert.equal(weeks[0].days.every(d => d.inMonth), true)
  assert.equal(weeks[2].days.every(d => !d.inMonth), true)   // all October
  assert.equal(weeks[1].days.find(d => d.iso === "2026-09-30").inMonth, true)
  assert.equal(weeks[1].days.find(d => d.iso === "2026-10-01").inMonth, false)
})

test("weeksFrom carries marks and clamps its length", () => {
  const events = [ev({ date: "2026-09-29" }), ev({ id: "b", date: "2026-09-29", title: "Other" })]
  const marks = M.marksInRange(events, "2026-09-21", 21)
  const weeks = M.weeksFrom("2026-09-26", 3, { marks })
  assert.equal(weeks[1].days.find(d => d.iso === "2026-09-29").count, 2)
  // A missing or zero count means "the default window", and the length is capped.
  assert.equal(M.weeksFrom("2026-09-26", 0, {}).length, 3)
  assert.equal(M.weeksFrom("2026-09-26", undefined, {}).length, 3)
  assert.equal(M.weeksFrom("2026-09-26", 99, {}).length, 12)
})

test("windowLabel names one month, or the two it spans", () => {
  assert.equal(M.windowLabel("2026-09-01", "2026-09-21"), "SEPTEMBER 2026")
  assert.equal(M.windowLabel("2026-09-21", "2026-10-11"), "SEP – OCT 2026")
  assert.equal(M.windowLabel("2026-12-28", "2027-01-17"), "DEC 2026 – JAN 2027")
})

test("yearMonths returns twelve self-contained months", () => {
  const months = M.yearMonths(2026, { todayISO: "2026-09-26" })
  assert.equal(months.length, 12)
  assert.equal(months[8].short, "Sep")
  // No adjacent-month days leak into a mini grid.
  const stray = months[8].weeks.reduce((acc, w) => acc.concat(w.days), [])
                              .filter(d => d.iso !== "" && !d.inMonth)
  assert.equal(stray.length, 0)
})

test("yearProgress tracks the year and clamps outside it", () => {
  assert.equal(M.percentLabel(M.yearProgress(2026, "2026-09-26")), "73%")
  assert.equal(M.yearProgress(2026, "2026-01-01"), 0)
  assert.equal(M.percentLabel(M.yearProgress(2026, "2026-12-31")), "100%")
  assert.equal(M.yearProgress(2027, "2026-09-26"), 0)
  assert.equal(M.yearProgress(2025, "2026-09-26"), 1)
})

test("weekdayLabels rotates for a Monday start", () => {
  assert.deepEqual(M.weekdayLabels(true), ["M", "T", "W", "T", "F", "S", "S"])
  assert.deepEqual(M.weekdayLabels(false), ["S", "M", "T", "W", "T", "F", "S"])
  assert.deepEqual(M.weekdayPairs(true), ["MO", "TU", "WE", "TH", "FR", "SA", "SU"])
  assert.deepEqual(M.weekdayPairs(false), ["SU", "MO", "TU", "WE", "TH", "FR", "SA"])
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

test("an event keeps its location through the store", () => {
  const e = M.normalizeEvent({ title: "Design review", date: "2026-09-26", time: "14:00",
                               durationMin: 60, location: " Studio 2 " })
  assert.equal(e.location, "Studio 2")
  const back = M.parseStore(M.serializeStore([Object.assign({ id: "a" }, e)]))
  assert.equal(back[0].location, "Studio 2")
  assert.equal(M.eventsOn(back, "2026-09-26")[0].location, "Studio 2")
})

test("timeRange reads the way the card prints it", () => {
  assert.equal(M.timeRange({ time: "14:00", durationMin: 60 }, true), "14:00 – 15:00")
  assert.equal(M.timeRange({ time: "14:00", durationMin: 0 }, true), "14:00")
  assert.equal(M.timeRange({ time: "", durationMin: 0 }, true), "All day")
  assert.equal(M.timeRange({ time: "14:00", durationMin: 60 }, false), "2:00pm – 3:00pm")
  // Past midnight wraps rather than printing 25:00.
  assert.equal(M.endTime("23:30", 60), "00:30")
})

test("the headings match the mockup's wording", () => {
  assert.equal(M.dayHeading("2026-09-26"), "SATURDAY, SEPTEMBER 26")
  assert.equal(M.upperMonth(2026, 8), "SEPTEMBER 2026")
  assert.equal(M.countLabel(0), "No events")
  assert.equal(M.countLabel(1), "1 event")
  assert.equal(M.countLabel(3), "3 events")
})

test("pickFamily takes the first installed headline face", () => {
  assert.equal(M.pickFamily(["Noto Sans", "Liberation Sans"], ["Inter", "Noto Sans"], "mono"), "Noto Sans")
  assert.equal(M.pickFamily(["liberation sans"], ["Liberation Sans"], "mono"), "liberation sans")
  assert.equal(M.pickFamily(["DejaVu Sans"], ["Inter"], "monospace"), "monospace")
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

// --- multi-day runs ---------------------------------------------------------

test("a span covers every day it runs through", () => {
  const trip = ev({ id: "t", date: "2026-09-28", days: 5 })
  assert.equal(M.occursOn(trip, "2026-09-27"), false)
  assert.equal(M.occursOn(trip, "2026-09-28"), true)
  assert.equal(M.occursOn(trip, "2026-10-02"), true)     // the fifth day
  assert.equal(M.occursOn(trip, "2026-10-03"), false)
  const middle = M.eventsOn([trip], "2026-09-30")[0]
  assert.equal(middle.dayIndex, 2)
  assert.equal(middle.isStart, false)
  assert.equal(middle.isEnd, false)
  assert.equal(middle.startISO, "2026-09-28")
  assert.equal(middle.endISO, "2026-10-02")
  assert.equal(middle.spans, true)
})

test("endDate is folded into a span on the way in", () => {
  assert.equal(M.normalizeEvent({ title: "T", date: "2026-09-28", endDate: "2026-09-30" }).days, 3)
  // A backwards or equal endDate is simply a one-day event.
  assert.equal(M.normalizeEvent({ title: "T", date: "2026-09-28", endDate: "2026-09-27" }).days, 1)
  assert.equal(M.normalizeEvent({ title: "T", date: "2026-09-28" }).days, 1)
  // days survives the store; a one-day event writes no span.
  assert.equal(M.parseStore(M.serializeStore([ev({ days: 4 })]))[0].days, 4)
  assert.equal(M.serializeStore([ev()]).includes("days"), false)
})

test("a repeat carries its span to every occurrence", () => {
  const shift = ev({ id: "s", date: "2026-09-28", days: 3, repeat: "weekly" })
  assert.equal(M.occursOn(shift, "2026-09-30"), true)    // day 3 of the first
  assert.equal(M.occursOn(shift, "2026-10-01"), false)   // the gap
  assert.equal(M.occursOn(shift, "2026-10-05"), true)    // the next week's day 1
  assert.equal(M.eventsOn([shift], "2026-10-07")[0].dayIndex, 2)
})

test("runs sort above the rest of the day, longest first", () => {
  const list = M.eventsOn([
    ev({ id: "a", date: "2026-09-28", time: "09:00", title: "Standup" }),
    ev({ id: "b", date: "2026-09-27", days: 4, title: "Trip" }),
    ev({ id: "c", date: "2026-09-28", days: 2, title: "Workshop" })
  ], "2026-09-28")
  assert.deepEqual(list.map(e => e.title), ["Trip", "Workshop", "Standup"])
})

test("a run is a bar, not dots", () => {
  const events = [ev({ id: "t", date: "2026-09-28", days: 3, color: "sky" }),
                  ev({ id: "d", date: "2026-09-28", color: "clay" })]
  const marks = M.marksInRange(events, "2026-09-28", 1)
  assert.equal(marks["2026-09-28"].count, 2)             // both are on that day
  assert.deepEqual(marks["2026-09-28"].colors, ["clay"]) // only the single day dots
})

test("weekSegments clips a run to the week and flags the open ends", () => {
  const events = [ev({ id: "s", date: "2026-09-21", days: 14, title: "Sprint" })]
  const first = M.weekSegments(events, "2026-09-21")[0]
  assert.equal(first.startCol, 0)
  assert.equal(first.endCol, 6)
  assert.equal(first.continuesBefore, false)
  assert.equal(first.continuesAfter, true)
  const second = M.weekSegments(events, "2026-09-28")[0]
  assert.equal(second.continuesBefore, true)
  assert.equal(second.continuesAfter, false)
  assert.equal(second.endCol, 6)
  assert.equal(M.weekSegments(events, "2026-10-05").length, 0)
})

test("weekSegments stacks overlapping runs into lanes", () => {
  const events = [
    ev({ id: "s", date: "2026-09-21", days: 14, title: "Sprint" }),
    ev({ id: "t", date: "2026-09-28", days: 5, title: "Trip" }),
    ev({ id: "c", date: "2026-09-30", days: 2, title: "Conference" })
  ]
  const segs = M.weekSegments(events, "2026-09-28")
  assert.deepEqual(segs.map(s => s.title + ":" + s.lane), ["Sprint:0", "Trip:1", "Conference:2"])
  // Runs that do not overlap share a lane.
  const apart = M.weekSegments([
    ev({ id: "a", date: "2026-09-28", days: 2, title: "A" }),
    ev({ id: "b", date: "2026-10-01", days: 2, title: "B" })
  ], "2026-09-28")
  assert.deepEqual(apart.map(s => s.lane), [0, 0])
})

test("a single-day event never becomes a segment", () => {
  assert.equal(M.weekSegments([ev({ date: "2026-09-28" })], "2026-09-28").length, 0)
})

test("the grid rows carry their own segments", () => {
  const events = [ev({ id: "t", date: "2026-09-28", days: 5, title: "Trip" })]
  const weeks = M.weeksFrom("2026-09-26", 3, { events })
  assert.equal(weeks[0].segments.length, 0)              // the run starts next week
  assert.equal(weeks[1].segments[0].title, "Trip")
  assert.equal(weeks[1].start, "2026-09-28")
  // No events passed in means no bars, which is what the year miniatures want.
  assert.deepEqual(M.weeksFrom("2026-09-26", 3, {})[1].segments, [])
})

test("spanLabel says the shape of the run", () => {
  const trip = [ev({ id: "t", date: "2026-09-28", days: 5 })]
  assert.equal(M.spanLabel(M.eventsOn(trip, "2026-09-28")[0], true), "28 Sep → 2 Oct")
  assert.equal(M.spanLabel(M.eventsOn(trip, "2026-09-30")[0], true), "Day 3/5  ·  28 Sep → 2 Oct")
  const timed = M.eventsOn([ev({ id: "x", date: "2026-09-28", days: 2, time: "09:00" })], "2026-09-28")[0]
  assert.equal(M.spanLabel(timed, true), "28 Sep → 29 Sep  ·  09:00")
  assert.equal(M.spanLabel(M.eventsOn([ev()], "2026-09-26")[0], true), "")
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
