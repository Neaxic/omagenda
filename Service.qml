import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Headless data layer for Datebook, mounted once by the shell as this plugin's
// service: it owns the event file, the "today" clock and the IPC target. Every
// bar widget (one per monitor) reads this same instance through
// shell.serviceFor("datebook"), so the two never disagree about what day it is.
// All date and event logic lives in Model.js.
Item {
  id: root

  // Injected by the shell.
  property var shell: null
  property var manifest: null

  // The widget's inline shell.json entry, pushed in by the bar widgets.
  property var settings: ({})

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function persistSettings(values) {
    var entry = { id: "datebook" }
    for (var key in settings) if (key !== "id") entry[key] = settings[key]
    for (var name in values) entry[name] = values[name]
    settings = entry
    if (shell && typeof shell.updateEntryInline === "function") shell.updateEntryInline("datebook", entry)
  }

  // --- settings ---------------------------------------------------------------
  readonly property string barMode: Model.normalizeBarMode(setting("barMode", "next"))
  readonly property string barIcon: String(setting("barIcon", "calendar"))
  readonly property int barMaxTitle: Math.round(setting("barMaxTitle", 18))
  readonly property bool weekStartsMonday: setting("weekStartsMonday", true) !== false
  readonly property bool showWeekNumbers: setting("showWeekNumbers", true) !== false
  // How many weeks the rolling grid shows, counting the one we are standing in.
  // spread | theme — see Chrome.paletteMode.
  readonly property string eventPalette: String(setting("eventPalette", "spread")) === "theme" ? "theme" : "spread"
  readonly property int weeksShown: Math.max(1, Math.min(8, Math.round(setting("weeksShown", 3))))
  readonly property bool use24Hour: setting("use24Hour", true) !== false
  readonly property int upcomingDays: Math.max(1, Math.round(setting("upcomingDays", 14)))

  // --- paths ------------------------------------------------------------------
  readonly property string home: Quickshell.env("HOME")
  readonly property string configDir: home + "/.config/datebook"
  readonly property string eventsPath: configDir + "/events.json"

  // --- clock ------------------------------------------------------------------
  // One ticker drives every date-dependent binding. The minute matters for the
  // bar's "next up" label; the day rollover has to move the today ring too.
  property string todayISO: Model.todayISO()
  property int nowMinutes: 0

  function tick() {
    var now = new Date()
    var iso = Model.toISO(now)
    var minutes = now.getHours() * 60 + now.getMinutes()
    if (iso !== todayISO) {
      // Midnight: a window that was sitting on today rolls forward with it.
      var wasOnToday = selectedISO === todayISO
      todayISO = iso
      if (wasOnToday) {
        showWeekOf(iso)
        selectedISO = iso
      }
    }
    if (minutes !== nowMinutes) nowMinutes = minutes
  }

  Timer {
    interval: 20000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.tick()
  }

  // --- view state -------------------------------------------------------------
  // The grid rolls: it opens on the week `anchorISO` falls in and runs forward.
  // Past weeks are gone rather than greyed, so the window is always the days
  // still ahead of you. Both this and the selected day are shared, so paging on
  // one monitor pages the other too.
  property string anchorISO: Model.startOfWeek(Model.todayISO(), true)
  property string selectedISO: Model.todayISO()

  // "weeks" is the rolling window; "month" expands it to the whole month the
  // selected day sits in. Not persisted: the popup opens on the window again,
  // which is the view that answers "what is coming".
  property string gridMode: "weeks"    // weeks | month

  function setGridMode(mode) {
    var next = String(mode) === "month" ? "month" : "weeks"
    gridMode = next
    // Leaving the month view, re-anchor on the selected day so the window opens
    // where the eye already is rather than back on today.
    if (next === "weeks") showWeekOf(selectedISO)
    return next
  }

  function toggleGridMode() { return setGridMode(gridMode === "month" ? "weeks" : "month") }

  // What the year page does: open a month in full, not as a rolling window.
  function openMonth(year, month) {
    gridMode = "month"
    showMonth(year, month)
  }

  readonly property string windowEndISO: Model.shiftISO(anchorISO, weeksShown * 7 - 1)

  // The masthead, the year page and the meter all follow the selected day.
  readonly property var selectedDate: Model.fromISO(selectedISO)
  readonly property int viewYear: selectedDate ? selectedDate.getFullYear() : new Date().getFullYear()
  readonly property int viewMonth: selectedDate ? selectedDate.getMonth() : new Date().getMonth()

  function inWindow(iso) {
    return Model.isISODate(iso) && iso >= anchorISO && iso <= windowEndISO
  }

  function showWeekOf(iso) {
    if (!Model.isISODate(iso)) return false
    anchorISO = Model.startOfWeek(iso, weekStartsMonday)
    return true
  }

  // Paging carries the selection with it, so the masthead never names a day the
  // grid has scrolled past.
  function stepWeeks(delta) {
    var steps = Math.round(delta) * 7
    anchorISO = Model.shiftISO(anchorISO, steps)
    selectedISO = Model.shiftISO(selectedISO, steps)
  }

  function stepYear(delta) {
    showMonth(viewYear + Math.round(delta), viewMonth)
  }

  // The week opens on a different day now, so the anchor has to follow.
  onWeekStartsMondayChanged: anchorISO = Model.startOfWeek(anchorISO, weekStartsMonday)

  // Which page the popup is on. It lives here with the rest of the view state so
  // both monitors agree, and so the pages can be driven over IPC for testing.
  property string uiPage: "month"      // month | year | detail | compose
  property string uiEventId: ""

  function showPage(name, id) {
    var page = String(name || "month")
    if (["month", "year", "detail", "compose"].indexOf(page) === -1) return false
    uiEventId = id === undefined || id === null ? "" : String(id)
    uiPage = page
    return true
  }

  function showMonth(year, month) {
    select(Model.toISO(new Date(year, month, 1)))
  }

  // Keeps the day of the month where it can, so paging months from the 26th
  // lands on the 26th rather than snapping to the 1st.
  function stepMonth(delta) {
    select(Model.addMonthsToISO(selectedISO, delta))
  }

  function select(iso) {
    if (!Model.isISODate(iso)) return false
    selectedISO = iso
    // Only re-anchor when the day is off the window; clicking inside it must
    // not make the grid jump under the pointer.
    if (!inWindow(iso)) showWeekOf(iso)
    return true
  }

  function goToday() {
    tick()
    showWeekOf(todayISO)
    selectedISO = todayISO
  }

  // --- events -----------------------------------------------------------------
  property var events: []
  property bool loaded: false
  property string lastError: ""

  readonly property var windowMarks: Model.marksInRange(events, anchorISO, weeksShown * 7)
  readonly property var monthMarks: Model.marksForMonth(events, viewYear, viewMonth)
  readonly property var yearMarks: Model.marksInRange(events, viewYear + "-01-01", 366)
  readonly property var selectedEvents: Model.eventsOn(events, selectedISO)
  readonly property var todayEvents: Model.eventsOn(events, todayISO)
  readonly property var upcomingEvents: Model.upcoming(events, todayISO, upcomingDays)
  readonly property var next: Model.nextOccurrence(events, todayISO, nowMinutes)

  readonly property var weeks: gridMode === "month"
    ? Model.monthWeeks(viewYear, viewMonth, {
        mondayFirst: weekStartsMonday,
        showAdjacentMonths: true,
        todayISO: todayISO,
        marks: monthMarks
      })
    : Model.weeksFrom(anchorISO, weeksShown, {
        mondayFirst: weekStartsMonday,
        todayISO: todayISO,
        marks: windowMarks
      })

  // "SEPTEMBER 2026" for a month, or "SEP – OCT 2026" once a window straddles two.
  readonly property string gridLabel: gridMode === "month"
    ? Model.upperMonth(viewYear, viewMonth)
    : Model.windowLabel(anchorISO, windowEndISO)

  readonly property var yearMonths: Model.yearMonths(viewYear, {
    mondayFirst: weekStartsMonday,
    todayISO: todayISO,
    marks: yearMarks
  })

  // How much of the year on screen has gone, for the masthead meter.
  readonly property real yearProgress: Model.yearProgress(viewYear, todayISO)

  readonly property string barText: Model.barLabel({
    mode: barMode, next: next, todayISO: todayISO,
    todayCount: todayEvents.length, use24: use24Hour, maxTitle: barMaxTitle
  })

  readonly property string tooltip: Model.tooltipText({
    todayISO: todayISO, todayCount: todayEvents.length, next: next, use24: use24Hour
  })

  // Texts we wrote ourselves. The watcher reports every one of our own writes
  // back to us, sometimes after a newer edit is already in memory; reloading
  // those would roll the newer edit back, so only outside edits are loaded.
  property var recentWrites: []

  function loadEvents(raw) {
    var i = recentWrites.indexOf(raw)
    if (i !== -1) { recentWrites = recentWrites.slice(i + 1); return }
    events = Model.parseStore(raw)
    loaded = true
  }

  function save(next) {
    events = next
    var text = Model.serializeStore(next)
    recentWrites = recentWrites.concat([text]).slice(-10)
    eventsFile.setText(text)
  }

  // Returns "" on success, or a short message for the add field.
  function addFromInput(text, dateISO) {
    var parsed = Model.parseAddInput(text, dateISO || selectedISO)
    if (!parsed) return "Use: [date] [HH:MM] title [!weekly]"
    var event = Model.normalizeEvent(parsed)
    if (!event) return "Could not read that date"
    event.id = Model.newId(event.date)
    save(Model.upsertEvent(events, event))
    select(event.date)
    return ""
  }

  function addEvent(title, dateISO, time, repeat) {
    var event = Model.normalizeEvent({
      title: title, date: dateISO, time: time, repeat: repeat
    })
    if (!event) return ""
    event.id = Model.newId(event.date)
    save(Model.upsertEvent(events, event))
    return event.id
  }

  function updateEvent(id, values) {
    for (var i = 0; i < events.length; i++) {
      if (events[i].id !== id) continue
      var merged = {}
      for (var key in events[i]) merged[key] = events[i][key]
      for (var name in values) merged[name] = values[name]
      var event = Model.normalizeEvent(merged)
      if (!event) return false
      event.id = id
      save(Model.upsertEvent(events, event))
      return true
    }
    return false
  }

  // The event behind an id, as an occurrence: on `preferISO` when the series
  // lands there, otherwise on its own date. The detail page needs the day it is
  // standing on, not just the series head.
  function occurrenceById(id, preferISO) {
    for (var i = 0; i < events.length; i++) {
      if (events[i].id !== id) continue
      var onPreferred = Model.isISODate(preferISO) ? Model.eventsOn([events[i]], preferISO) : []
      if (onPreferred.length > 0) return onPreferred[0]
      var own = Model.eventsOn([events[i]], events[i].date)
      return own.length > 0 ? own[0] : null
    }
    return null
  }

  // Create or update from the compose form. Returns "" or a short message.
  function saveEvent(id, values) {
    var raw = {
      title: values.title,
      date: values.date,
      time: values.time,
      durationMin: values.durationMin,
      location: values.location,
      color: values.color,
      repeat: values.repeat
    }
    if (String(values.title || "").replace(/^\s+|\s+$/g, "") === "") return "Give it a title"
    if (!Model.fromISO(String(values.date || ""))) return "Use a date like " + todayISO
    if (String(values.time || "") !== "" && Model.normalizeTime(values.time) === "")
      return "Use a time like 14:00, or leave it blank"

    if (id !== "") {
      // Keep what the form does not ask about (notes, an until bound).
      for (var i = 0; i < events.length; i++) {
        if (events[i].id !== id) continue
        raw.notes = events[i].notes
        raw.until = events[i].until
        break
      }
    }

    var event = Model.normalizeEvent(raw)
    if (!event) return "Could not read that event"
    event.id = id !== "" ? id : Model.newId(event.date)
    save(Model.upsertEvent(events, event))
    select(event.date)
    return ""
  }

  function remove(id) {
    var before = events.length
    save(Model.removeEvent(events, id))
    return events.length < before
  }

  function openEventsFile() { Quickshell.execDetached(["xdg-open", eventsPath]) }

  // Event colours are theme palette slots, so they change with the theme rather
  // than sitting on top of it.
  // Named themePalette, not palette: QQuickItem already has one.
  property var themePalette: ({})

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.themePalette = Model.parsePalette(text())
  }

  FileView {
    id: eventsFile
    path: root.eventsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadEvents(text())
    onLoadFailed: mkdirProc.running = true
    onFileChanged: reload()
  }

  // First run: create ~/.config/datebook and write an empty store, so the file
  // the user is told about actually exists before they go looking for it.
  Process {
    id: mkdirProc
    command: ["mkdir", "-p", root.configDir]
    onExited: function(code) {
      if (code !== 0) { root.lastError = "Could not create " + root.configDir; return }
      root.loaded = true
      root.save([])
    }
  }

  // --- IPC --------------------------------------------------------------------
  // `omarchy-shell datebook <method> [args]`. Handy for testing without
  // clicking, and for scripting the store from outside the shell.
  IpcHandler {
    target: "datebook"

    function toggle(): string { return root.shell && root.shell.toggle("datebook", "") ? "ok" : "no bar widget" }

    function status(): string {
      return JSON.stringify({
        today: root.todayISO,
        selected: root.selectedISO,
        grid: root.gridMode,
        window: root.anchorISO + ".." + root.windowEndISO,
        view: root.viewYear + "-" + Model.pad2(root.viewMonth + 1),
        loaded: root.loaded,
        events: root.events.length,
        todayCount: root.todayEvents.length,
        next: root.next ? { iso: root.next.iso, time: root.next.time, title: root.next.title } : null,
        bar: root.barText,
        error: root.lastError
      })
    }

    // A day ("2026-09-26"), or nothing for the selected day.
    function list(day: string): string {
      var iso = Model.isISODate(day) ? day : root.selectedISO
      return JSON.stringify(Model.eventsOn(root.events, iso))
    }

    function upcoming(days: string): string {
      var n = parseInt(days, 10)
      return JSON.stringify(Model.upcoming(root.events, root.todayISO, isFinite(n) ? n : root.upcomingDays))
    }

    // One line, same grammar as the add field: "2026-10-02 09:00 Standup !weekly".
    function add(line: string): string {
      var error = root.addFromInput(line, root.selectedISO)
      return error === "" ? "ok" : error
    }

    function remove(id: string): string { return root.remove(id) ? "ok" : "unknown id" }

    function select(day: string): string { return root.select(day) ? root.selectedISO : "expected YYYY-MM-DD" }

    function month(delta: string): string {
      var n = parseInt(delta, 10)
      root.stepMonth(isFinite(n) ? n : 0)
      return root.viewYear + "-" + Model.pad2(root.viewMonth + 1)
    }

    // Opens a month whole, the way clicking one on the year page does.
    function showMonth(year: string, month: string): string {
      var y = parseInt(year, 10), m = parseInt(month, 10)
      if (!isFinite(y) || !isFinite(m) || m < 1 || m > 12) return "expected <year> <1-12>"
      root.openMonth(y, m - 1)
      return root.gridMode + " " + root.viewYear + "-" + Model.pad2(root.viewMonth + 1)
    }

    // weeks | month, or nothing to flip between them.
    function grid(mode: string): string {
      return mode === "" ? root.toggleGridMode() : root.setGridMode(mode)
    }

    // Rolls the grid by whole weeks, which is what the pager under it does.
    function week(delta: string): string {
      var n = parseInt(delta, 10)
      root.stepWeeks(isFinite(n) ? n : 0)
      return root.anchorISO + ".." + root.windowEndISO
    }

    function today(): string { root.goToday(); return root.todayISO }

    // month | year | detail <id> | compose [id]
    function page(name: string, id: string): string {
      return root.showPage(name, id) ? root.uiPage : "expected month|year|detail|compose"
    }

    function barMode(value: string): string {
      root.persistSettings({ barMode: Model.normalizeBarMode(value) })
      return root.barMode
    }

    function setOption(key: string, value: string): string {
      if (key === "") return "expected a key"
      var parsed = value
      if (value === "true") parsed = true
      else if (value === "false") parsed = false
      else if (/^-?\d+$/.test(value)) parsed = parseInt(value, 10)
      var values = {}
      values[key] = parsed
      root.persistSettings(values)
      return JSON.stringify(root.settings)
    }

    function event(id: string): string {
      var occurrence = root.occurrenceById(id, root.selectedISO)
      return occurrence ? JSON.stringify(occurrence) : "unknown id"
    }

    // The compose form's own path: {"title","date","time","durationMin","location","repeat"}
    function compose(id: string, json: string): string {
      var values
      try { values = JSON.parse(json) } catch (e) { return "expected JSON" }
      var error = root.saveEvent(id, values)
      return error === "" ? "ok" : error
    }

    function reload(): string { eventsFile.reload(); return "ok" }

    function path(): string { return root.eventsPath }
  }
}
