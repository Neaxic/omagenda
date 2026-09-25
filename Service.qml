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
  readonly property bool showAdjacentMonths: setting("showAdjacentMonths", true) !== false
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
      todayISO = iso
      // A day that rolls over while the popup sits open should follow along.
      if (viewYear === now.getFullYear() && viewMonth === now.getMonth() && selectedISO !== iso)
        selectedISO = iso
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
  // Which month the grid is showing and which day the agenda is for. Shared, so
  // paging the calendar on one monitor pages it on the other too.
  property int viewYear: new Date().getFullYear()
  property int viewMonth: new Date().getMonth()
  property string selectedISO: Model.todayISO()

  function showMonth(year, month) {
    viewYear = year
    viewMonth = month
  }

  function stepMonth(delta) {
    var next = Model.addMonths(viewYear, viewMonth, delta)
    showMonth(next.year, next.month)
  }

  function select(iso) {
    if (!Model.isISODate(iso)) return false
    selectedISO = iso
    var date = Model.fromISO(iso)
    if (date) showMonth(date.getFullYear(), date.getMonth())
    return true
  }

  function goToday() {
    tick()
    select(todayISO)
  }

  // --- events -----------------------------------------------------------------
  property var events: []
  property bool loaded: false
  property string lastError: ""

  readonly property var monthCounts: Model.countsForMonth(events, viewYear, viewMonth)
  readonly property var selectedEvents: Model.eventsOn(events, selectedISO)
  readonly property var todayEvents: Model.eventsOn(events, todayISO)
  readonly property var upcomingEvents: Model.upcoming(events, todayISO, upcomingDays)
  readonly property var next: Model.nextOccurrence(events, todayISO, nowMinutes)

  readonly property var cells: Model.monthCells(viewYear, viewMonth, {
    mondayFirst: weekStartsMonday,
    showWeekNumbers: showWeekNumbers,
    showAdjacentMonths: showAdjacentMonths,
    todayISO: todayISO,
    counts: monthCounts
  })

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

  function remove(id) {
    var before = events.length
    save(Model.removeEvent(events, id))
    return events.length < before
  }

  function openEventsFile() { Quickshell.execDetached(["xdg-open", eventsPath]) }

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

    function today(): string { root.goToday(); return root.todayISO }

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

    function reload(): string { eventsFile.reload(); return "ok" }

    function path(): string { return root.eventsPath }
  }
}
