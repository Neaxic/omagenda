import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Datebook's popup, built to the mockup: a masthead with the month set large and
// a year meter, a hairline month grid with a week gutter, the selected day's
// agenda, and a footer that pages the months. WEEKS/YEAR switches the grid for
// twelve miniatures; an event opens a detail page; + and NEW EVENT open the
// compose page. The store, the clock and the shared selection live in
// Service.qml, the date maths in Model.js.
Panel {
  id: root
  moduleName: "datebook"
  ipcTarget: "datebook"
  // The service registers the "datebook" IPC target (it owns toggle + the store),
  // so this widget must not claim it a second time.
  manageIpc: false

  // --- theme --------------------------------------------------------------------
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // The mockup's headline is a tight grotesque, which no monospace stands in for,
  // so the first installed face from Model.DISPLAY_FAMILIES wins unless the user
  // names one (or "theme" to keep the bar's own font).
  readonly property string displayFamily: {
    var wanted = String(setting("displayFont", "auto"))
    if (wanted === "theme") return fontFamily
    if (wanted !== "" && wanted !== "auto") return wanted
    return Model.pickFamily(Qt.fontFamilies(), Model.DISPLAY_FAMILIES, fontFamily)
  }

  Chrome {
    id: tokens
    foreground: root.foreground
    accent: root.accent
    urgent: root.urgent
    // The mockup sets everything in one grotesque; only the Nerd Font glyphs
    // stay on the bar's monospace, which is the only face that carries them.
    fontFamily: root.displayFamily
    displayFamily: root.displayFamily
    glyphFamily: root.fontFamily
    themePalette: root.book ? root.book.themePalette : ({})
    paletteMode: root.book ? root.book.eventPalette : "spread"
  }

  // --- service ------------------------------------------------------------------
  property var book: null
  function findBook() {
    if (!book && bar && bar.shell && typeof bar.shell.serviceFor === "function")
      book = bar.shell.serviceFor("datebook")
  }
  onBarChanged: findBook()
  Timer {
    interval: 500
    repeat: true
    running: !root.book
    onTriggered: root.findBook()
  }

  function pushSettings() { if (book) book.settings = root.settings }
  onSettingsChanged: pushSettings()
  onBookChanged: pushSettings()

  // --- derived ------------------------------------------------------------------
  readonly property string todayISO: book ? book.todayISO : Model.todayISO()
  readonly property string selectedISO: book ? book.selectedISO : todayISO
  readonly property int viewYear: book ? book.viewYear : new Date().getFullYear()
  readonly property int viewMonth: book ? book.viewMonth : new Date().getMonth()
  readonly property var weeks: book ? book.weeks : []
  readonly property string gridLabel: book ? book.gridLabel : ""
  readonly property string gridMode: book ? book.gridMode : "weeks"
  readonly property var yearMonths: book ? book.yearMonths : []
  readonly property var dayEvents: book ? book.selectedEvents : []
  readonly property int todayCount: book ? book.todayEvents.length : 0
  readonly property bool use24Hour: book ? book.use24Hour : true
  readonly property bool weekStartsMonday: book ? book.weekStartsMonday : true
  readonly property bool showWeekNumbers: book ? book.showWeekNumbers : true
  readonly property string barText: book ? book.barText : ""
  readonly property string barGlyph: Model.barIconGlyph(setting("barIcon", "calendar"))

  readonly property int selectedDay: {
    var date = Model.fromISO(selectedISO)
    return date ? date.getDate() : 0
  }

  readonly property int todayMonth: {
    var date = Model.fromISO(todayISO)
    return date && date.getFullYear() === viewYear ? date.getMonth() : -1
  }

  // --- pages --------------------------------------------------------------------
  // "month" and "year" are the two halves of the toggle; "detail" and "compose"
  // take over the body below the masthead.
  readonly property string page: book ? book.uiPage : "month"
  readonly property bool onCalendar: page === "month" || page === "year"

  readonly property string openEventId: book ? book.uiEventId : ""
  property string composeError: ""
  property bool textFocus: false

  readonly property var openEvent: {
    if (openEventId === "" || !book) return null
    return book.occurrenceById(openEventId, selectedISO)
  }

  function showPage(name, id) { if (book) book.showPage(name, id || "") }

  function openDetail(id) { showPage("detail", id) }

  function startCompose(id) {
    composeError = ""
    showPage("compose", id || "")
  }

  function backFromPage() {
    composeError = ""
    showPage("month", "")
  }

  // --- actions ------------------------------------------------------------------
  function stepMonth(delta) { if (book) book.stepMonth(delta) }
  function stepWeeks(delta) { if (book) book.stepWeeks(delta) }
  function stepYear(delta) { if (book) book.stepYear(delta) }
  function setGridMode(mode) { if (book) book.setGridMode(mode) }
  // The pager's inner arrows move by whatever the grid is showing.
  function stepGrid(delta) { gridMode === "month" ? stepMonth(delta) : stepWeeks(delta) }
  function selectDay(iso) { if (book) book.select(iso) }
  function goToday() { if (book) book.goToday() }
  function stepDay(delta) { if (book) book.select(Model.shiftISO(selectedISO, delta)) }
  function openFile() { if (book) book.openEventsFile() }

  function saveCompose(values) {
    if (!book) return
    var error = book.saveEvent(openEventId, values)
    if (error !== "") { composeError = error; return }
    backFromPage()
  }

  function deleteEvent(id) {
    if (book) book.remove(id)
    backFromPage()
  }

  function barPressed(buttonCode) {
    if (buttonCode === Qt.RightButton) goToday()
    else if (buttonCode === Qt.MiddleButton) { open(); startCompose("") }
    else toggle()
  }

  // Opening always lands on today's month rather than wherever last month's
  // browsing left the shared selection.
  onOpenedChanged: {
    if (opened) { showPage("month", ""); composeError = ""; goToday() }
    else { textFocus = false }
  }

  // --- bar widget ---------------------------------------------------------------
  implicitWidth: barLoader.item ? barLoader.item.implicitWidth : 0
  implicitHeight: barLoader.item ? barLoader.item.implicitHeight : 0

  Loader {
    id: barLoader
    anchors.fill: parent
    sourceComponent: root.barText === "" ? iconButton : textButton
  }

  Component {
    id: iconButton
    BarIconButton {
      bar: root.bar
      text: root.barGlyph !== "" ? root.barGlyph : Model.barIconGlyph("calendar")
      active: root.todayCount > 0
      activeColor: root.accent
      tooltipText: root.book ? root.book.tooltip : "Datebook"
      onPressed: function(buttonCode) { root.barPressed(buttonCode) }
    }
  }

  Component {
    id: textButton
    WidgetButton {
      bar: root.bar
      text: (root.barGlyph !== "" ? root.barGlyph + " " : "") + root.barText
      tooltipText: root.book ? root.book.tooltip : "Datebook"
      onPressed: function(buttonCode) { root.barPressed(buttonCode) }
    }
  }

  // --- popup --------------------------------------------------------------------
  KeyboardPanel {
    id: panel
    anchorItem: barLoader
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    // The mockup's own 32px gutter, so the rules run edge to edge inside it.
    padding: tokens.pad
    contentWidth: panel.fittedContentWidth(Style.space(613))
    contentHeight: panel.fittedContentHeight(card.implicitHeight, Style.space(900))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.textFocus
      onCloseRequested: root.onCalendar ? root.close() : root.backFromPage()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (root.page === "year") {
          if (dx !== 0) root.stepMonth(dx > 0 ? 1 : -1)
          if (dy !== 0) root.stepMonth(dy > 0 ? 4 : -4)
          return
        }

        if (!root.onCalendar) return
        if (dx !== 0) root.stepDay(dx > 0 ? 1 : -1)
        if (dy !== 0) root.stepDay(dy > 0 ? 7 : -7)
      }
      onReturnRequested: if (root.onCalendar) root.startCompose("")
      onTextKey: function(text) {
        if (!root.onCalendar) return
        var key = String(text).toLowerCase()
        if (key === "t") root.goToday()
        else if (key === "n" || key === "]") root.page === "year" ? root.stepYear(1) : root.stepGrid(1)
        else if (key === "p" || key === "[") root.page === "year" ? root.stepYear(-1) : root.stepGrid(-1)
        else if (key === "m") { if (root.book) root.book.toggleGridMode() }
        else if (key === ">" || key === ".") root.stepMonth(1)
        else if (key === "<" || key === ",") root.stepMonth(-1)
        else if (key === "y") root.showPage(root.page === "year" ? "month" : "year", "")
        else if (key === "a") root.startCompose("")
        else if (key === "o") root.openFile()
      }

      Column {
        id: card
        width: parent.width
        spacing: 0

        // --- masthead -------------------------------------------------------
        CalendarHeader {
          width: parent.width
          chrome: tokens
          title: root.page === "year" ? String(root.viewYear) : Model.MONTH_NAMES[root.viewMonth]
          trailing: root.page === "year" ? "" : String(root.selectedDay)
          onSlabClicked: root.goToday()
          trailingControl: Component {
            SegmentedToggle {
              chrome: tokens
              current: root.page === "year" ? "year" : root.gridMode
              options: [
                { key: "weeks", label: "WEEKS" },
                { key: "month", label: "MONTH" },
                { key: "year", label: "YEAR" }
              ]
              onPicked: function(key) {
                if (key === "year") { root.showPage("year", ""); return }
                root.setGridMode(key)
                root.showPage("month", "")
              }
            }
          }
        }

        Item { width: 1; height: Style.space(19) }

        Rectangle { width: parent.width; height: 1; color: tokens.rule }

        Item { width: 1; height: Style.space(25) }

        // --- weekday row and the WEEKS / YEAR switch -------------------------
        // Weekday letters only — the year page has nothing to put here, so the
        // row collapses rather than leaving a band of empty space.
        Item {
          width: parent.width
          height: root.page === "month" ? tokens.segment : 0
          visible: root.page === "month"

          // Centred over the columns they head, which the mockup's own squeeze
          // could not do with the switch sharing the row.
          Row {
            id: weekdayRow
            x: tokens.gutter
            height: parent.height
            visible: root.page === "month"
            readonly property real slot: Math.max(1, (parent.width - tokens.gutter) / 7)

            Repeater {
              model: Model.weekdayPairs(root.weekStartsMonday)

              delegate: Text {
                required property var modelData
                width: weekdayRow.slot
                height: weekdayRow.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData
                color: tokens.dimmer
                font.family: tokens.fontFamily
                font.pixelSize: tokens.labelSize
                font.letterSpacing: tokens.trackedSpacing
              }
            }
          }

        }

        Item { width: 1; height: root.onCalendar ? Style.space(13) : 0 }


        // --- the body -------------------------------------------------------
        Loader {
          id: pageLoader
          width: parent.width
          sourceComponent: {
            if (root.page === "year") return yearPage
            if (root.page === "detail") return detailPage
            if (root.page === "compose") return composePage
            return monthPage
          }
        }
      }
    }
  }

  // --- the month page ---------------------------------------------------------------
  Component {
    id: monthPage

    Column {
      spacing: 0

      MonthGrid {
        width: parent.width
        chrome: tokens
        weeks: root.weeks
        selectedISO: root.selectedISO
        // A month's last row is part of the month, not the far end of a window.
        fadeLastWeek: root.gridMode === "weeks"
        onDaySelected: function(iso) { root.selectDay(iso) }
        onDayActivated: function(iso) { root.selectDay(iso); root.startCompose("") }
      }

      Item { width: 1; height: Style.space(18) }

      // --- the selected day ------------------------------------------------
      // No heading: the masthead already names the day and the grid has it
      // outlined, so a third statement of the date was only taking up room.
      // With events, the agenda's own top rule closes the grid; without them,
      // this one does, so the grid is never left with an open bottom edge.
      Rectangle {
        width: parent.width
        height: visible ? 1 : 0
        visible: root.dayEvents.length === 0
        color: tokens.rule
      }

      // --- the agenda ------------------------------------------------------
      // A day with nothing on it shows nothing at all: an empty band is just
      // dead space between the grid and the pager.
      Column {
        width: parent.width
        spacing: 0
        visible: root.dayEvents.length > 0
        height: visible ? implicitHeight : 0

        Rectangle { width: parent.width; height: 1; color: tokens.rule }

        // Four bands is as tall as the agenda gets; a busier day scrolls.
        Flickable {
          width: parent.width
          height: Math.min(agenda.implicitHeight, tokens.eventRow * 4)
          visible: root.dayEvents.length > 0
          contentHeight: agenda.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: agenda
            width: parent.width

            Repeater {
              model: root.dayEvents

              delegate: EventCard {
                required property var modelData
                width: agenda.width
                chrome: tokens
                occurrence: modelData
                use24Hour: root.use24Hour
                onOpened: function(id) { root.openDetail(id) }
              }
            }
          }
        }
      }

      Item { width: 1; height: Style.space(30) }

      // --- pager -----------------------------------------------------------
      // Outer arrows jump a month, inner ones step whatever the grid shows —
      // a week on the rolling window, a month when it is expanded.
      Item {
        width: parent.width
        height: Style.space(30)

        Row {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          PagerArrow {
            chrome: tokens
            glyph: "\u{F013D}"                        // chevron-double-left
            strong: true
            onClicked: root.stepMonth(-1)
          }

          PagerArrow {
            chrome: tokens
            glyph: "\u{F0141}"                        // chevron-left
            visible: root.gridMode === "weeks"
            onClicked: root.stepGrid(-1)
          }
        }

        Text {
          anchors.centerIn: parent
          text: root.gridLabel
          color: tokens.dim
          font.family: tokens.fontFamily
          font.pixelSize: tokens.labelSize
          font.letterSpacing: tokens.trackedSpacing
        }

        Row {
          anchors.right: parent.right
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          PagerArrow {
            chrome: tokens
            glyph: "\u{F0142}"                        // chevron-right
            visible: root.gridMode === "weeks"
            onClicked: root.stepGrid(1)
          }

          PagerArrow {
            chrome: tokens
            glyph: "\u{F013E}"                        // chevron-double-right
            strong: true
            onClicked: root.stepMonth(1)
          }
        }
      }

      Item { width: 1; height: Style.space(25) }

      Row {
        spacing: Style.space(10)

        OutlineButton {
          chrome: tokens
          glyph: "\u{F0415}"                         // plus
          label: "NEW EVENT"
          onClicked: root.startCompose("")
        }

        OutlineButton {
          chrome: tokens
          label: "TODAY"
          onClicked: root.goToday()
        }
      }
    }
  }

  // --- the year page ----------------------------------------------------------------
  Component {
    id: yearPage

    Column {
      spacing: 0

      YearGrid {
        width: parent.width
        chrome: tokens
        months: root.yearMonths
        currentMonth: root.viewMonth
        todayMonth: root.todayMonth
        onMonthPicked: function(month) {
          // From the year, a month opens whole rather than as a three-week window.
          if (root.book) root.book.openMonth(root.viewYear, month)
          root.showPage("month", "")
        }
      }

      Item { width: 1; height: Style.space(30) }

      Item {
        width: parent.width
        height: Style.space(30)

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          text: "\u{F0141}"
          color: prevYearMouse.containsMouse ? tokens.headline : tokens.dim
          font.family: tokens.glyphFamily
          font.pixelSize: Style.font.icon

          MouseArea {
            id: prevYearMouse
            anchors.fill: parent
            anchors.margins: -Style.space(10)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.stepYear(-1)
          }
        }

        Text {
          anchors.centerIn: parent
          text: String(root.viewYear)
          color: tokens.dim
          font.family: tokens.fontFamily
          font.pixelSize: tokens.labelSize
          font.letterSpacing: tokens.trackedSpacing
        }

        Text {
          anchors.right: parent.right
          anchors.rightMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          text: "\u{F0142}"
          color: nextYearMouse.containsMouse ? tokens.headline : tokens.dim
          font.family: tokens.glyphFamily
          font.pixelSize: Style.font.icon

          MouseArea {
            id: nextYearMouse
            anchors.fill: parent
            anchors.margins: -Style.space(10)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.stepYear(1)
          }
        }
      }
    }
  }

  // --- the detail page --------------------------------------------------------------
  Component {
    id: detailPage

    EventDetail {
      chrome: tokens
      occurrence: root.openEvent
      use24Hour: root.use24Hour
      onEditRequested: function(id) { root.startCompose(id) }
      onDeleteRequested: function(id) { root.deleteEvent(id) }
      onClosed: root.backFromPage()
    }
  }

  // --- the compose page -------------------------------------------------------------
  Component {
    id: composePage

    EventCompose {
      chrome: tokens
      dateISO: root.selectedISO
      editingId: root.openEventId
      error: root.composeError
      onSaved: function(values) { root.saveCompose(values) }
      onCancelled: root.backFromPage()
      onAnyFieldFocusedChanged: root.textFocus = anyFieldFocused
      // The form is created the moment the page switches, so it fills itself
      // in rather than waiting to be pushed at.
      Component.onCompleted: {
        load(root.openEvent)
        focusTitle()
      }
      Component.onDestruction: root.textFocus = false
    }
  }
}
