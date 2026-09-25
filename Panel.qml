import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Datebook: a month calendar in the bar. UI only — the event file, the clock and
// the shared month/day selection live in Service.qml, the date maths in Model.js.
// One of these exists per monitor; both read the same service instance, so what
// you page or select on one screen is what the other shows.
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
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color hairline: Style.normalBorderFor(foreground, accent, urgent)
  readonly property color hoverFill: Style.hoverFillFor(foreground, accent, urgent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

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
  readonly property var cells: book ? book.cells : []
  readonly property var dayEvents: book ? book.selectedEvents : []
  readonly property var upcomingEvents: book ? book.upcomingEvents : []
  readonly property int todayCount: book ? book.todayEvents.length : 0
  readonly property bool use24Hour: book ? book.use24Hour : true
  readonly property bool weekStartsMonday: book ? book.weekStartsMonday : true
  readonly property bool showWeekNumbers: book ? book.showWeekNumbers : true
  readonly property int upcomingDays: book ? book.upcomingDays : 14
  readonly property string barText: book ? book.barText : ""
  readonly property string barGlyph: Model.barIconGlyph(setting("barIcon", "calendar"))

  // "month" is the calendar; "upcoming" is the flat list of what is coming.
  property string view: "month"
  readonly property bool inUpcoming: view === "upcoming"

  // Esc and the arrow keys belong to the grid unless the add field has focus.
  property bool textFocus: false
  property var addFieldRef: null
  property string addError: ""

  readonly property string heroMeta: {
    if (!book) return "Loading…"
    var when = Model.relativeDay(selectedISO, todayISO)
    var n = dayEvents.length
    return when + " · " + (n === 0 ? "nothing planned" : n + (n === 1 ? " event" : " events"))
  }

  // --- actions ------------------------------------------------------------------
  function stepMonth(delta) { if (book) book.stepMonth(delta) }
  function selectDay(iso) { if (book) book.select(iso) }
  function goToday() { if (book) book.goToday() }
  function stepDay(delta) { if (book) book.select(Model.shiftISO(selectedISO, delta)) }
  function removeEvent(id) { if (book) book.remove(id) }
  function openFile() { if (book) book.openEventsFile() }

  function submitAdd(field) {
    if (!book || !field) return
    var error = book.addFromInput(field.text, selectedISO)
    addError = error
    if (error === "") field.text = ""
  }

  function focusAddField() {
    if (addFieldRef) addFieldRef.forceActiveFocus()
  }

  function barPressed(buttonCode) {
    if (buttonCode === Qt.RightButton) goToday()
    else if (buttonCode === Qt.MiddleButton) view = inUpcoming ? "month" : "upcoming"
    else toggle()
  }

  // Opening always lands on today rather than wherever last month's browsing
  // left the shared selection.
  onOpenedChanged: {
    if (opened) { view = "month"; goToday() }
    else { addError = ""; textFocus = false }
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
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(card.implicitHeight, Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.textFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      // Left/right walk days, up/down walk weeks — the grid's own geometry.
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.stepDay(dx > 0 ? 1 : -1)
        if (dy !== 0) root.stepDay(dy > 0 ? 7 : -7)
      }
      onReturnRequested: root.focusAddField()
      onActivateRequested: root.focusAddField()
      onTextKey: function(text) {
        var key = String(text).toLowerCase()
        if (key === "t") root.goToday()
        else if (key === "n" || key === "]") root.stepMonth(1)
        else if (key === "p" || key === "[") root.stepMonth(-1)
        else if (key === "u") root.view = root.inUpcoming ? "month" : "upcoming"
        else if (key === "o") root.openFile()
        else if (key === "a") root.focusAddField()
      }

      Column {
        id: card
        width: parent.width
        spacing: Style.space(10)

        // --- heading ----------------------------------------------------------
        PanelHero {
          width: parent.width
          foreground: root.foreground
          fontFamily: root.fontFamily
          title: root.inUpcoming ? "Upcoming" : Model.monthTitle(root.viewYear, root.viewMonth)
          meta: root.inUpcoming
            ? "Next " + root.upcomingDays + " days · " + root.upcomingEvents.length + " in total"
            : root.heroMeta
          iconComponent: Component {
            Text {
              text: Model.barIconGlyph("month")
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
          trailingControl: Component {
            Row {
              spacing: Style.space(4)

              PanelActionButton {
                visible: !root.inUpcoming
                iconText: "\u{F0141}"          // chevron-left
                tooltipText: "Previous month (p)"
                foreground: root.dim
                hoverColor: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.stepMonth(-1)
              }

              Button {
                text: "Today"
                tooltipText: "Jump to today (t)"
                bordered: true
                selected: root.selectedISO === root.todayISO && !root.inUpcoming
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                onClicked: { root.view = "month"; root.goToday() }
              }

              PanelActionButton {
                visible: !root.inUpcoming
                iconText: "\u{F0142}"          // chevron-right
                tooltipText: "Next month (n)"
                foreground: root.dim
                hoverColor: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.stepMonth(1)
              }
            }
          }
        }

        // --- month or upcoming ------------------------------------------------
        Loader {
          width: parent.width
          sourceComponent: root.inUpcoming ? upcomingView : monthView
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        // --- add --------------------------------------------------------------
        Column {
          width: parent.width
          spacing: Style.space(4)

          TextField {
            id: addField
            width: parent.width
            placeholderText: "Add: [date] [HH:MM] title [!weekly]"
            foreground: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            Component.onCompleted: root.addFieldRef = addField
            onActiveFocusChanged: root.textFocus = activeFocus
            onTextChanged: root.addError = ""
            onAccepted: root.submitAdd(addField)
            Keys.onEscapePressed: { text = ""; keyCatcher.forceActiveFocus() }
          }

          Text {
            width: parent.width
            visible: root.addError !== ""
            text: root.addError
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        // --- footer -----------------------------------------------------------
        Row {
          spacing: Style.space(6)

          PanelActionButton {
            iconText: root.inUpcoming ? Model.barIconGlyph("month") : "\u{F0A33}"   // calendar-week
            tooltipText: root.inUpcoming ? "Back to the month (u)" : "Upcoming events (u)"
            foreground: root.inUpcoming ? root.accent : root.dim
            hoverColor: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.view = root.inUpcoming ? "month" : "upcoming"
          }

          PanelActionButton {
            iconText: "\u{F11D7}"              // note-text-outline
            tooltipText: "Open events.json (o)"
            foreground: root.dim
            hoverColor: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.openFile()
          }

          Item { width: Style.space(4); height: 1 }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.book && root.book.lastError !== "" ? root.book.lastError : ""
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }

  // --- the month view -------------------------------------------------------------
  Component {
    id: monthView

    Column {
      spacing: Style.space(8)

      MonthGrid {
        width: parent.width
        cells: root.cells
        weekdayLabels: Model.weekdayLabels(root.weekStartsMonday)
        showWeekNumbers: root.showWeekNumbers
        selectedISO: root.selectedISO
        foreground: root.foreground
        accent: root.accent
        dim: root.dim
        hairline: root.hairline
        fontFamily: root.fontFamily
        onDaySelected: function(iso) { root.selectDay(iso) }
      }

      PanelSeparator { width: parent.width; foreground: root.foreground }

      // The selected day's agenda.
      Column {
        width: parent.width
        spacing: Style.space(4)

        PanelSectionHeader {
          width: parent.width
          text: Model.formatDayLong(root.selectedISO)
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Text {
          width: parent.width
          visible: root.dayEvents.length === 0
          text: "Nothing planned — type below to add something."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Repeater {
          model: root.dayEvents
          delegate: EventRow {
            required property var modelData
            width: parent.width
            occurrence: modelData
            use24Hour: root.use24Hour
            foreground: root.foreground
            dim: root.dim
            accent: root.accent
            hoverFill: root.hoverFill
            fontFamily: root.fontFamily
            onRemoveRequested: function(id) { root.removeEvent(id) }
          }
        }
      }
    }
  }

  // --- the upcoming view ----------------------------------------------------------
  Component {
    id: upcomingView

    Column {
      spacing: Style.space(6)

      Text {
        width: parent.width
        visible: root.upcomingEvents.length === 0
        text: "Nothing in the next " + root.upcomingDays + " days."
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      Repeater {
        model: root.upcomingEvents
        delegate: Column {
          required property var modelData
          required property int index
          width: parent.width
          spacing: Style.space(2)

          // One heading per day, printed on the first occurrence of that day.
          PanelSectionHeader {
            width: parent.width
            visible: index === 0 || root.upcomingEvents[index - 1].iso !== modelData.iso
            text: Model.relativeDay(modelData.iso, root.todayISO)
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          EventRow {
            width: parent.width
            occurrence: modelData
            use24Hour: root.use24Hour
            foreground: root.foreground
            dim: root.dim
            accent: root.accent
            hoverFill: root.hoverFill
            fontFamily: root.fontFamily
            onClicked: function(iso) { root.view = "month"; root.selectDay(iso) }
            onRemoveRequested: function(id) { root.removeEvent(id) }
          }
        }
      }
    }
  }
}
