import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Headless data layer for Omagenda, mounted once by the shell as this plugin's
// service: it owns the event file, the "today" clock and the IPC target. Every
// bar widget (one per monitor) reads this same instance through
// shell.serviceFor("io.github.neaxic.omagenda"), so the two never disagree about what day it is.
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

  // The settings this widget actually declares, straight off the manifest so
  // the list cannot drift from the schema. The IPC setter is reachable by
  // anything on the user's Quickshell bus, and an unchecked key would write
  // arbitrary JSON into their shell.json entry.
  readonly property var knownSettings: {
    var out = []
    var schema = manifest && manifest.barWidget ? manifest.barWidget.schema : null
    if (schema)
      for (var i = 0; i < schema.length; i++)
        if (schema[i] && schema[i].key) out.push(String(schema[i].key))
    return out
  }

  function isKnownSetting(key) {
    // No manifest (a bare qmllint run, say) means nothing to check against;
    // refusing everything would be worse than the bar simply not offering IPC.
    return knownSettings.length === 0 || knownSettings.indexOf(String(key)) !== -1
  }

  function persistSettings(values) {
    var entry = { id: "io.github.neaxic.omagenda" }
    for (var key in settings) if (key !== "id") entry[key] = settings[key]
    // `id` is the bar's handle on this widget, not a setting. It is skipped on
    // the way in above, so skip it here too — otherwise the last writer wins
    // and a caller could rename the entry out from under the bar.
    for (var name in values) if (name !== "id") entry[name] = values[name]
    settings = entry
    if (shell && typeof shell.updateEntryInline === "function") shell.updateEntryInline("io.github.neaxic.omagenda", entry)
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
  readonly property string configDir: home + "/.config/omagenda"
  readonly property string eventsPath: configDir + "/events.json"
  readonly property string sourcesPath: configDir + "/sources.json"
  readonly property string cachePath: configDir + "/cache.json"

  function pluginFile(name) {
    return decodeURIComponent(Qt.resolvedUrl(name).toString().replace(/^file:\/\//, ""))
  }

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

  // In clock mode the bar is a wall clock, so the tick has to land just after
  // the minute turns rather than up to 20s later. Every other mode only needs
  // the minute to be roughly right, and a plain 20s beat keeps it cheap.
  function tickInterval() {
    if (barMode !== "clock") return 20000
    var now = new Date()
    return (60 - now.getSeconds()) * 1000 - now.getMilliseconds() + 200
  }

  Timer {
    id: ticker
    interval: 20000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      root.tick()
      interval = root.tickInterval()
    }
  }

  // Switching into or out of clock mode re-times the beat; assigning the
  // interval restarts the timer, which is what we want either way.
  onBarModeChanged: ticker.interval = root.tickInterval()

  // --- view state -------------------------------------------------------------
  // The grid rolls: it opens on the week `anchorISO` falls in and runs forward.
  // Past weeks are gone rather than greyed, so the window is always the days
  // still ahead of you. Both this and the selected day are shared, so paging on
  // one monitor pages the other too.
  property string anchorISO: Model.startOfWeek(Model.todayISO(), true)
  property string selectedISO: Model.todayISO()

  // Whether that day is one you actually picked. Paging keeps `selectedISO`
  // moving — the masthead needs a month, a new event needs a date — but a day
  // the pager merely landed on is not a selection, and is not drawn as one.
  property bool daySelected: true

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

  // Paging carries the day with it, so the masthead never names a day the grid
  // has scrolled past — but it does not carry the selection: arriving in
  // another month with one of its days already outlined claims a choice nobody
  // made.
  function stepWeeks(delta) {
    var steps = Math.round(delta) * 7
    anchorISO = Model.shiftISO(anchorISO, steps)
    selectedISO = Model.shiftISO(selectedISO, steps)
    daySelected = false
  }

  function stepYear(delta) {
    showMonth(viewYear + Math.round(delta), viewMonth)
  }

  // The week opens on a different day now, so the anchor has to follow.
  onWeekStartsMondayChanged: anchorISO = Model.startOfWeek(anchorISO, weekStartsMonday)

  // Which page the popup is on. It lives here with the rest of the view state so
  // both monitors agree, and so the pages can be driven over IPC for testing.
  property string uiPage: "month"      // month | year | detail | compose | calendars | settings
  property string uiEventId: ""
  // Where closing the current page goes back to. Calendars is reachable both
  // from the footer and from the settings page, and landing on the calendar
  // after coming from settings would throw away where you were.
  property string uiFrom: "month"

  function showPage(name, id, from) {
    var page = String(name || "month")
    if (["month", "year", "detail", "compose", "calendars", "settings"].indexOf(page) === -1) return false
    uiEventId = id === undefined || id === null ? "" : String(id)
    uiFrom = from === undefined || from === null || from === "" ? "month" : String(from)
    uiPage = page
    // Arriving on the calendars page re-asks Google what exists, so a calendar
    // shared with the account since last time is simply there. It belongs here
    // rather than in the panel's button handler: the page can also be reached
    // over IPC, and it would be a trap for that route to skip the refresh.
    if (page === "calendars") refreshCalendars()
    return true
  }

  function showMonth(year, month) {
    return moveTo(Model.toISO(new Date(year, month, 1)), false)
  }

  // Keeps the day of the month where it can, so paging months from the 26th
  // lands on the 26th rather than snapping to the 1st.
  function stepMonth(delta) {
    return moveTo(Model.addMonthsToISO(selectedISO, delta), false)
  }

  // Where everything else is measured from. `deliberate` is the whole
  // difference between a day you picked and a day the pager landed on.
  function moveTo(iso, deliberate) {
    if (!Model.isISODate(iso)) return false
    selectedISO = iso
    daySelected = deliberate !== false
    // Only re-anchor when the day is off the window; clicking inside it must
    // not make the grid jump under the pointer.
    if (!inWindow(iso)) showWeekOf(iso)
    return true
  }

  function select(iso) { return moveTo(iso, true) }

  function goToday() {
    tick()
    showWeekOf(todayISO)
    selectedISO = todayISO
    daySelected = true
  }

  // --- sources ------------------------------------------------------------------
  // The local JSON store is one calendar; each synced Google calendar is another.
  // Remote events live in their own cache so a sync can never touch local edits,
  // and each source carries the colour its events take unless they override it.
  //   { id, kind: "google", calendarId, name, color, enabled, writable }
  property var sources: []
  // sourceId -> { syncToken, events: [] }, persisted to cache.json.
  property var remote: ({})

  readonly property var localSource: ({ id: "local", kind: "local", name: "Local",
                                        color: "none", enabled: true, writable: true })

  function sourceById(id) {
    if (id === "local" || id === "") return localSource
    for (var i = 0; i < sources.length; i++) if (sources[i].id === id) return sources[i]
    return null
  }

  function sourceColor(id) {
    var source = sourceById(id)
    return source ? String(source.color || "none") : "none"
  }

  function sourceWritable(id) {
    var source = sourceById(id)
    return source ? source.writable !== false : false
  }

  // Every calendar's events in one list, which is what the whole view layer reads.
  readonly property var allEvents: {
    var lists = []
    for (var i = 0; i < sources.length; i++) {
      var source = sources[i]
      if (source.enabled === false) continue
      var entry = remote[source.id]
      if (!entry || !entry.events || !entry.events.length) continue
      // A synced event takes its calendar's colour unless it carries one of its
      // own — colour says which calendar, which is what it says everywhere else.
      var tint = String(source.color || "none")
      if (tint === "none") { lists.push(entry.events); continue }
      var painted = []
      for (var j = 0; j < entry.events.length; j++) {
        var event = entry.events[j]
        if (event.color !== "none") { painted.push(event); continue }
        var copy = {}
        for (var key in event) copy[key] = event[key]
        // What it is drawn in, without losing what it actually carries: the
        // compose form edits the event's own colour, not its calendar's.
        copy.ownColor = event.color
        copy.color = tint
        painted.push(copy)
      }
      lists.push(painted)
    }
    return Model.mergeSources(events, lists)
  }

  // --- events -----------------------------------------------------------------
  property var events: []
  property bool loaded: false
  property string lastError: ""

  readonly property var windowMarks: Model.marksInRange(allEvents, anchorISO, weeksShown * 7)
  readonly property var monthMarks: Model.marksForMonth(allEvents, viewYear, viewMonth)
  readonly property var yearMarks: Model.marksInRange(allEvents, viewYear + "-01-01", 366)
  readonly property var selectedEvents: Model.eventsOn(allEvents, selectedISO)
  readonly property var todayEvents: Model.eventsOn(allEvents, todayISO)
  readonly property var upcomingEvents: Model.upcoming(allEvents, todayISO, upcomingDays)
  readonly property var next: Model.nextOccurrence(allEvents, todayISO, nowMinutes)

  readonly property var weeks: gridMode === "month"
    ? Model.monthWeeks(viewYear, viewMonth, {
        mondayFirst: weekStartsMonday,
        showAdjacentMonths: true,
        todayISO: todayISO,
        marks: monthMarks,
        events: allEvents
      })
    : Model.weeksFrom(anchorISO, weeksShown, {
        mondayFirst: weekStartsMonday,
        todayISO: todayISO,
        marks: windowMarks,
        events: allEvents
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


  readonly property string barText: Model.barLabel({
    mode: barMode, next: next, todayISO: todayISO, nowMinutes: nowMinutes,
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
    var pool = allEvents
    for (var i = 0; i < pool.length; i++) {
      if (pool[i].id !== id) continue
      var onPreferred = Model.isISODate(preferISO) ? Model.eventsOn([pool[i]], preferISO) : []
      if (onPreferred.length > 0) return onPreferred[0]
      var own = Model.eventsOn([pool[i]], pool[i].date)
      return own.length > 0 ? own[0] : null
    }
    return null
  }

  // Create or update from the compose form. Returns "" or a short message.
  // `values.source` chooses the calendar; an event that changes calendar is
  // removed from the old one and created on the new, since neither Google nor
  // the local file can move it in place.
  function saveEvent(id, values) {
    var existing = id !== "" ? findEvent(id) : null
    var target = String(values.source || (existing ? existing.source : "local") || "local")

    var raw = {
      title: values.title,
      date: values.date,
      days: values.days,
      time: values.time,
      durationMin: values.durationMin,
      location: values.location,
      color: values.color,
      repeat: values.repeat,
      source: target
    }
    if (String(values.title || "").replace(/^\s+|\s+$/g, "") === "") return "Give it a title"
    if (!Model.fromISO(String(values.date || ""))) return "Use a date like " + todayISO
    if (String(values.time || "") !== "" && Model.normalizeTime(values.time) === "")
      return "Use a time like 14:00, or leave it blank"
    var span = Math.round(Number(values.days) || 1)
    if (span < 1 || span > 366) return "A run is between 1 and 366 days"
    if (target !== "local" && String(values.repeat || "none") !== "none")
      return "Repeats are local-only for now — save it to Local"

    if (existing) {
      // Keep what the form does not ask about (notes, an until bound).
      raw.notes = existing.notes
      raw.until = existing.until
      if (existing.source === target) {
        raw.remoteId = existing.remoteId
        // The colour id Google has on it, so the patch can tell "unchanged"
        // from "cleared" — without it, picking "no colour" wrote nothing.
        raw.colorId = existing.colorId
      }
    }

    var event = Model.normalizeEvent(raw)
    if (!event) return "Could not read that event"

    // Leaving a calendar behind: take it off the old one first.
    if (existing && existing.source !== target) {
      if (existing.source === "local") save(Model.removeEvent(events, existing.id))
      else remoteRemove(existing)
    }

    if (target === "local") {
      event.id = (existing && existing.source === "local") ? id : Model.newId(event.date)
      save(Model.upsertEvent(events, event))
    } else {
      var error = remoteSave(target, event)
      if (error !== "") return error
    }
    select(event.date)
    return ""
  }

  function findEvent(id) {
    var pool = allEvents
    for (var i = 0; i < pool.length; i++) if (pool[i].id === id) return pool[i]
    return null
  }

  function remove(id) {
    var event = findEvent(id)
    if (event && event.source !== "local") return remoteRemove(event) === ""
    var before = events.length
    save(Model.removeEvent(events, id))
    return events.length < before
  }

  function openEventsFile() { Quickshell.execDetached(["xdg-open", eventsPath]) }

  // --- syncing ------------------------------------------------------------------
  readonly property string gcalBin: pluginFile("bin/gcal")

  property bool syncing: false
  property string syncError: ""
  property double lastSynced: 0
  property var syncQueue: []
  property var googleState: ({ client: false, authorized: false })
  property var calendarList: []

  // The connect flow's own state. `connecting` stays true from the press until
  // Google is done with the user, which is however long they spend staring at a
  // consent screen — so the panel has something to say in the meantime.
  property bool connecting: false
  property string googleError: ""

  // Whether this copy of Omagenda has an OAuth client at all. Without one the
  // panel offers no button: a dead one that always errors is worse than saying
  // the build has no Google integration.
  readonly property bool googleAvailable: googleState ? googleState.client === true : false
  readonly property bool googleConnected: googleState ? googleState.authorized === true : false
  // env | user | builtin — "user" means they brought their own Cloud project.
  readonly property string googleClientOrigin: googleState ? String(googleState.clientOrigin || "") : ""

  // Google is asked for a window rather than everything: a decade of history is
  // not worth the round trip. An incremental pass ignores these and follows the
  // sync token instead.
  readonly property string syncFromISO: Model.shiftISO(todayISO, -120)
  readonly property string syncToISO: Model.shiftISO(todayISO, 400)

  function googleSources() {
    var out = []
    for (var i = 0; i < sources.length; i++) {
      var source = sources[i]
      if (source.kind === "google" && source.enabled !== false) out.push(source)
    }
    return out
  }

  function syncAll(force) {
    if (syncing) return "busy"
    var pending = googleSources()
    if (pending.length === 0) return "no sources"
    var queue = []
    for (var i = 0; i < pending.length; i++)
      queue.push({ id: pending[i].id, calendarId: pending[i].calendarId, full: force === true })
    syncQueue = queue
    syncing = true
    syncError = ""
    runSync()
    return "ok"
  }

  function runSync() {
    if (syncQueue.length === 0) {
      syncing = false
      lastSynced = Date.now()
      saveCache()
      return
    }
    var job = syncQueue[0]
    var entry = remote[job.id]
    var token = job.full ? "" : (entry ? String(entry.syncToken || "") : "")
    var args = [gcalBin, "events", job.calendarId]
    if (token !== "") args = args.concat(["--sync-token", token])
    else args = args.concat(["--from", syncFromISO + "T00:00:00Z", "--to", syncToISO + "T00:00:00Z"])
    syncProc.command = args
    syncProc.running = false
    syncProc.running = true
  }

  function finishSync(text) {
    var job = syncQueue.length > 0 ? syncQueue[0] : null
    if (!job) { syncing = false; return }
    var page = Model.parseGoogleEvents(text, job.id)

    if (!page.ok) {
      syncError = page.error
      syncQueue = syncQueue.slice(1)
      runSync()
      return
    }

    // The token was too old to resume from: take the same calendar again from
    // scratch rather than leaving a half-updated cache behind.
    if (page.expired && !job.full) {
      var retry = [{ id: job.id, calendarId: job.calendarId, full: true }]
      syncQueue = retry.concat(syncQueue.slice(1))
      runSync()
      return
    }

    var entry = remote[job.id] || { syncToken: "", events: [] }
    var kept = job.full ? [] : (entry.events || [])
    var index = {}
    var merged = []
    var i

    for (i = 0; i < kept.length; i++) index[kept[i].id] = kept[i]
    for (i = 0; i < page.deleted.length; i++) delete index[page.deleted[i]]
    for (i = 0; i < page.events.length; i++) index[page.events[i].id] = page.events[i]
    for (var key in index) merged.push(index[key])

    // A fresh object every time: QML does not notice a mutated one.
    var next = {}
    for (var id in remote) next[id] = remote[id]
    next[job.id] = { syncToken: page.syncToken || entry.syncToken || "", events: Model.sortEvents(merged) }
    remote = next

    syncQueue = syncQueue.slice(1)
    runSync()
  }

  // --- writing back ---------------------------------------------------------------
  // A remote event is edited where it lives. The local cache is updated straight
  // away so the panel does not sit still waiting for a round trip, and the
  // source is re-synced afterwards to pick up whatever Google actually stored.
  property var writeQueue: []
  property bool writing: false

  function queueWrite(job) {
    writeQueue = writeQueue.concat([job])
    if (!writing) runWrite()
  }

  function runWrite() {
    if (writeQueue.length === 0) { writing = false; return }
    writing = true
    var job = writeQueue[0]
    writeProc.command = job.command
    writeProc.running = false
    writeProc.running = true
  }

  function finishWrite(text) {
    var job = writeQueue.length > 0 ? writeQueue[0] : null
    writeQueue = writeQueue.slice(1)
    if (job) {
      var reply = {}
      try { reply = JSON.parse(String(text || "{}")) } catch (e) { reply = {} }
      if (reply.error) syncError = String(reply.error)
      // Nothing parseable came back, so the write did not happen: pulling the
      // calendar now would only confirm the event is still missing.
      else if (String(text || "").trim() === "") { /* onExited said why */ }
      else if (job.sourceId) {
        // Pull the source so the cache matches what Google now holds.
        syncQueue = syncQueue.concat([{ id: job.sourceId, calendarId: job.calendarId, full: false }])
        if (!syncing) { syncing = true; runSync() }
      }
    }
    runWrite()
  }

  function remoteSave(sourceId, event) {
    var source = sourceById(sourceId)
    if (!source || source.kind !== "google") return "unknown calendar"
    if (source.writable === false) return "that calendar is read-only"
    var body = JSON.stringify(Model.toGoogleEvent(event))
    var command = event.remoteId !== ""
      ? [gcalBin, "patch", source.calendarId, event.remoteId, body]
      : [gcalBin, "insert", source.calendarId, body]
    queueWrite({ command: command, sourceId: source.id, calendarId: source.calendarId })
    return ""
  }

  function remoteRemove(event) {
    var source = sourceById(event.source)
    if (!source || source.kind !== "google") return "unknown calendar"
    if (source.writable === false) return "that calendar is read-only"
    queueWrite({
      command: [gcalBin, "delete", source.calendarId, event.remoteId],
      sourceId: source.id, calendarId: source.calendarId
    })
    // Drop it locally at once; the follow-up sync confirms.
    var entry = remote[source.id]
    if (entry) {
      var left = []
      for (var i = 0; i < entry.events.length; i++)
        if (entry.events[i].id !== event.id) left.push(entry.events[i])
      var next = {}
      for (var id in remote) next[id] = remote[id]
      next[source.id] = { syncToken: entry.syncToken, events: left }
      remote = next
    }
    return ""
  }

  // --- source bookkeeping -----------------------------------------------------------
  function saveSources(list) {
    sources = list
    sourcesFile.setText(JSON.stringify({ version: 1, sources: list }, null, 2) + "\n")
  }

  function addSource(calendarId, name, color) {
    var id = "google:" + String(calendarId)
    for (var i = 0; i < sources.length; i++) if (sources[i].id === id) return "already added"
    var next = sources.slice(0)
    next.push({
      id: id, kind: "google", calendarId: String(calendarId),
      name: String(name || calendarId), color: Model.normalizeColor(color),
      enabled: true, writable: true
    })
    saveSources(next)
    syncAll(true)
    return id
  }

  function removeSource(id) {
    var next = []
    for (var i = 0; i < sources.length; i++) if (sources[i].id !== id) next.push(sources[i])
    if (next.length === sources.length) return false
    saveSources(next)
    var cache = {}
    for (var key in remote) if (key !== id) cache[key] = remote[key]
    remote = cache
    saveCache()
    return true
  }

  function setSourceEnabled(id, enabled) {
    var next = []
    for (var i = 0; i < sources.length; i++) {
      var source = sources[i]
      if (source.id === id) {
        var copy = {}
        for (var key in source) copy[key] = source[key]
        copy.enabled = enabled === true
        next.push(copy)
      } else next.push(source)
    }
    saveSources(next)
    return true
  }

  function setSourceColor(id, color) {
    var next = []
    var found = false
    for (var i = 0; i < sources.length; i++) {
      var source = sources[i]
      if (source.id === id) {
        var copy = {}
        for (var key in source) copy[key] = source[key]
        copy.color = Model.normalizeColor(color)
        next.push(copy)
        found = true
      } else next.push(source)
    }
    if (!found) return false
    saveSources(next)
    return true
  }

  function sourceForCalendar(calendarId) {
    return sourceById("google:" + String(calendarId))
  }

  // A calendar added from the picker takes the first palette slot nothing else
  // is using, so two calendars never arrive the same colour — which is the whole
  // point of colouring by source.
  function nextSourceColor() {
    var taken = {}
    for (var i = 0; i < sources.length; i++) taken[String(sources[i].color)] = true
    for (var c = 1; c < Model.EVENT_COLORS.length; c++) {
      var key = Model.EVENT_COLORS[c].key
      if (!taken[key]) return key
    }
    return Model.EVENT_COLORS[1 + (sources.length % (Model.EVENT_COLORS.length - 1))].key
  }

  // What a row in the calendar picker does: add the calendar, or drop it and its
  // cached events. Everything the source needs is already in `calendarList`, so
  // the caller passes an id and nothing else.
  function toggleCalendar(calendarId) {
    var existing = sourceForCalendar(calendarId)
    if (existing) return removeSource(existing.id) ? "removed" : "unknown source"

    var entry = null
    for (var i = 0; i < calendarList.length; i++)
      if (String(calendarList[i].id) === String(calendarId)) { entry = calendarList[i]; break }
    if (!entry) return "unknown calendar"

    var id = addSource(entry.id, entry.name, nextSourceColor())
    // A calendar Google only lets us read must not offer an edit button later.
    if (entry.writable === false) {
      var next = []
      for (var j = 0; j < sources.length; j++) {
        var source = sources[j]
        if (source.id === id) {
          var copy = {}
          for (var key in source) copy[key] = source[key]
          copy.writable = false
          next.push(copy)
        } else next.push(source)
      }
      saveSources(next)
    }
    return id
  }

  // --- connecting -----------------------------------------------------------------
  // One press: consent in the browser if there is no grant yet, then the calendar
  // list, then the user's primary calendar added and synced so something shows up
  // straight away. Adding more calendars is the picker's job after that.
  function connectGoogle() {
    if (connecting) return "busy"
    if (!googleAvailable) return "no client"
    connecting = true
    googleError = ""
    connectProc.command = [gcalBin, "connect"]
    connectProc.running = false
    connectProc.running = true
    return "ok"
  }

  function cancelConnect() {
    if (!connecting) return false
    connectProc.running = false
    connecting = false
    return true
  }

  function finishConnect(text) {
    connecting = false
    var reply = {}
    try { reply = JSON.parse(String(text || "{}")) } catch (e) { reply = {} }

    if (reply.error) { googleError = String(reply.error); return }
    if (!reply.ok) { googleError = "the Google helper said nothing back"; return }

    // Clear it here rather than only on the way in: onExited may have raced
    // ahead and written a failure for a call that in fact succeeded.
    googleError = ""
    calendarList = reply.calendars || []
    askGoogle("status")

    // First connection: put the primary calendar in without making them pick it
    // out of a list where it is the obvious answer.
    if (googleSources().length === 0 && String(reply.primary || "") !== "")
      toggleCalendar(reply.primary)
    else
      syncAll(false)
  }

  function disconnectGoogle() {
    googleError = ""
    var keep = []
    for (var i = 0; i < sources.length; i++)
      if (sources[i].kind !== "google") keep.push(sources[i])
    // Drop the calendars and their cache first: the grid should empty as the
    // grant goes, not stay full of events we can no longer refresh.
    var wasGoogle = keep.length !== sources.length
    if (wasGoogle) {
      saveSources(keep)
      remote = ({})
      saveCache()
    }
    calendarList = []
    logoutProc.command = [gcalBin, "logout"]
    logoutProc.running = false
    logoutProc.running = true
    return "ok"
  }

  function refreshCalendars() {
    if (googleConnected) askGoogle("calendars")
  }

  function saveCache() {
    var out = {}
    for (var id in remote) {
      var entry = remote[id]
      out[id] = { syncToken: entry.syncToken || "", events: entry.events || [] }
    }
    cacheFile.setText(JSON.stringify({ version: cacheVersion, sources: out }) + "\n")
  }

  function loadSources(raw) {
    var data
    try { data = JSON.parse(String(raw || "")) } catch (e) { data = null }
    var list = data && data.sources && data.sources.length !== undefined ? data.sources : []
    var out = []
    for (var i = 0; i < list.length; i++) {
      var source = list[i]
      if (!source || !source.id || !source.calendarId) continue
      out.push({
        id: String(source.id), kind: String(source.kind || "google"),
        calendarId: String(source.calendarId), name: String(source.name || source.calendarId),
        color: Model.normalizeColor(source.color), enabled: source.enabled !== false,
        writable: source.writable !== false
      })
    }
    sources = out
  }

  // Version 2 is the first cache whose events carry Google's colour id. A cache
  // written before it has none, and an incremental sync would never re-fetch an
  // event that has not changed — so its sync tokens are dropped and the next
  // sync is a full one, which is what fills the colours in.
  readonly property int cacheVersion: 2

  function loadCache(raw) {
    var data
    try { data = JSON.parse(String(raw || "")) } catch (e) { data = null }
    var stored = data && data.sources ? data.sources : {}
    var stale = Math.round(Number(data && data.version) || 1) < cacheVersion
    var out = {}
    for (var id in stored) {
      var entry = stored[id] || {}
      var list = entry.events && entry.events.length !== undefined ? entry.events : []
      var events = []
      for (var i = 0; i < list.length; i++) {
        var parsed = Model.normalizeEvent(list[i])
        if (parsed) { parsed.id = String(list[i].id || parsed.id); events.push(parsed) }
      }
      out[id] = {
        syncToken: stale ? "" : String(entry.syncToken || ""),
        events: Model.sortEvents(events)
      }
    }
    remote = out
  }

  Process {
    id: syncProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.finishSync(text)
    }
    onExited: function(code) {
      if (code !== 0 && root.syncError === "") root.syncError = "sync helper exited " + code
    }
  }

  // Settled in onExited rather than onStreamFinished, because that is the one
  // signal guaranteed to arrive: a helper that cannot start at all (no python3
  // on the box) closes no stream, and without this the queue kept `writing`
  // true for the rest of the session and every later edit piled up behind it
  // in silence. waitForEnd means the text is complete by the time we exit.
  Process {
    id: writeProc
    stdout: StdioCollector { id: writeOut; waitForEnd: true }
    onExited: function(code) {
      var text = String(writeOut.text || "")
      if (code !== 0 && text.trim() === "")
        root.syncError = "could not run bin/gcal (exit " + code + ") — is python3 installed?"
      root.finishWrite(text)
    }
  }

  Process {
    id: googleProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var reply = {}
        try { reply = JSON.parse(String(text || "{}")) } catch (e) { reply = {} }
        // An error reply is an error, not a new state: letting it land in
        // googleState would blank out `client` and `authorized` and leave the
        // panel offering to connect a build that is already connected.
        if (reply.error) root.googleError = String(reply.error)
        else if (reply.calendars) { root.calendarList = reply.calendars; root.googleError = "" }
        else root.googleState = reply
      }
    }
  }

  // Separate from googleProc because it outlives every other call here: it is
  // running for as long as the user is in the browser.
  Process {
    id: connectProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.finishConnect(text)
    }
    onExited: function(code) {
      // A non-zero exit that printed nothing parseable still has to clear the
      // spinner, or the panel waits on a browser that has gone.
      if (root.connecting) {
        root.connecting = false
        if (root.googleError === "")
          root.googleError = code === 4
            ? "the browser never came back — try again"
            : "the Google helper exited " + code
      }
    }
  }

  Process {
    id: logoutProc
    onExited: root.askGoogle("status")
  }

  function askGoogle(what) {
    googleProc.command = [gcalBin, what]
    googleProc.running = false
    googleProc.running = true
  }

  Timer {
    id: syncTimer
    interval: 600000                      // ten minutes
    repeat: true
    running: root.googleSources().length > 0
    triggeredOnStart: true
    onTriggered: root.syncAll(false)
  }

  FileView {
    id: sourcesFile
    path: root.sourcesPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadSources(text())
    onFileChanged: reload()
  }

  FileView {
    id: cacheFile
    path: root.cachePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadCache(text())
  }

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
    // Only a missing file means first run. PermissionDenied, NotAFile or a
    // plain read error mean the store is there and could not be read, and
    // creating an empty one over it would throw the user's events away.
    onLoadFailed: function(error) {
      if (error === FileViewError.FileNotFound) { mkdirProc.running = true; return }
      root.lastError = "Could not read " + root.eventsPath
        + " (" + FileViewError.toString(error) + ") — not overwriting it"
    }
    onFileChanged: reload()
  }

  // First run: create ~/.config/omagenda and write an empty store, so the file
  // the user is told about actually exists before they go looking for it.
  // 0700, because everything that lands in here is personal: the event store,
  // and the cache holding every synced Google event. FileView writes its files
  // 0644, so the directory is what keeps other accounts on the machine out.
  Process {
    id: mkdirProc
    command: ["mkdir", "-p", "-m", "700", root.configDir]
    onExited: function(code) {
      if (code !== 0) { root.lastError = "Could not create " + root.configDir; return }
      root.loaded = true
      root.save([])
    }
  }

  // Ask once at startup whether this build has a Google client and whether the
  // user has already granted it, so the calendars page knows what to offer
  // before anyone presses anything.
  Component.onCompleted: root.askGoogle("status")

  // --- IPC --------------------------------------------------------------------
  // `omarchy-shell omagenda <method> [args]`. Handy for testing without
  // clicking, and for scripting the store from outside the shell.
  IpcHandler {
    target: "omagenda"

    function toggle(): string { return root.shell && root.shell.toggle("io.github.neaxic.omagenda", "") ? "ok" : "no bar widget" }

    function status(): string {
      return JSON.stringify({
        today: root.todayISO,
        selected: root.selectedISO,
        daySelected: root.daySelected,
        grid: root.gridMode,
        sources: root.sources.length,
        synced: root.lastSynced,
        syncError: root.syncError,
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
      return JSON.stringify(Model.eventsOn(root.allEvents, iso))
    }

    function upcoming(days: string): string {
      var n = parseInt(days, 10)
      return JSON.stringify(Model.upcoming(root.allEvents, root.todayISO, isFinite(n) ? n : root.upcomingDays))
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

    // month | year | detail <id> | compose [id] | calendars | settings
    function page(name: string, id: string): string {
      return root.showPage(name, id) ? root.uiPage
        : "expected month|year|detail|compose|calendars|settings"
    }

    function barMode(value: string): string {
      root.persistSettings({ barMode: Model.normalizeBarMode(value) })
      return root.barMode
    }

    function setOption(key: string, value: string): string {
      if (key === "") return "expected a key"
      if (!root.isKnownSetting(key))
        return "unknown setting: " + key + " (known: " + root.knownSettings.join(", ") + ")"
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

    // --- calendars ------------------------------------------------------------
    function sources(): string {
      var out = [root.localSource]
      for (var i = 0; i < root.sources.length; i++) out.push(root.sources[i])
      return JSON.stringify(out)
    }

    function sourceAdd(calendarId: string, name: string, color: string): string {
      if (calendarId === "") return "expected a calendar id"
      return root.addSource(calendarId, name, color)
    }

    function sourceRemove(id: string): string {
      return root.removeSource(id) ? "ok" : "unknown source"
    }

    function sourceEnable(id: string, enabled: string): string {
      return root.setSourceEnabled(id, enabled === "true") ? "ok" : "unknown source"
    }

    function sourceColor(id: string, color: string): string {
      return root.setSourceColor(id, color) ? "ok" : "unknown source"
    }

    // The calendar picker's row action, by Google calendar id.
    function calendarToggle(calendarId: string): string {
      if (calendarId === "") return "expected a calendar id"
      return root.toggleCalendar(calendarId)
    }

    // --- google ---------------------------------------------------------------
    // The helper is asked in the background; `googleResult` reads what came back,
    // the same shape `bin/gcal` prints.
    function google(what: string): string {
      if (["status", "calendars"].indexOf(what) === -1) return "expected status|calendars"
      root.askGoogle(what)
      return "ok"
    }

    function googleResult(): string {
      return JSON.stringify({
        state: root.googleState, calendars: root.calendarList,
        connecting: root.connecting, error: root.googleError
      })
    }

    // What the SYNC WITH GOOGLE CALENDAR button does. Returns as soon as the
    // browser is open; `googleResult` says how it went.
    function connect(): string { return root.connectGoogle() }

    function disconnect(): string { return root.disconnectGoogle() }

    function sync(force: string): string {
      return root.syncAll(force === "true" || force === "full")
    }

    function syncStatus(): string {
      return JSON.stringify({
        syncing: root.syncing,
        queued: root.syncQueue.length,
        writing: root.writing,
        lastSynced: root.lastSynced,
        error: root.syncError,
        sources: root.googleSources().length
      })
    }

    function reload(): string { eventsFile.reload(); return "ok" }

    function path(): string { return root.eventsPath }
  }
}
