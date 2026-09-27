import QtQuick
import qs.Commons
import "Model.js" as Model

// Everything the widget can be told, on one page instead of in shell.json: what
// the bar shows, how the grid is drawn, and the two places worth going from
// here — the calendars and the events file itself.
//
// Only settings with something to show are on it. `upcomingDays` is the window
// the `upcoming` IPC call reports on and changes nothing on screen, so it stays
// where it was, in shell.json and over IPC.
Column {
  id: root

  property var chrome: null

  property string barMode: "next"
  property string barIcon: "calendar"
  property int barMaxTitle: 18
  property string displayFont: "auto"
  property string displayFamily: ""      // what "auto" actually resolved to
  property bool weekStartsMonday: true
  property bool showWeekNumbers: true
  property int weeksShown: 3
  property string eventPalette: "spread"
  property bool use24Hour: true

  property string calendarsNote: ""
  property string eventsPath: ""

  // (key, value) straight off the manifest's schema — the page never invents a
  // setting the widget does not declare.
  signal optionChanged(string key, var value)
  signal calendarsRequested()
  signal eventsFileRequested()
  signal closed()

  spacing: Style.space(20)

  readonly property var iconOptions: {
    var out = []
    for (var i = 0; i < Model.BAR_ICONS.length; i++) {
      var icon = Model.BAR_ICONS[i]
      out.push(icon.glyph === "" ? { key: icon.key, label: "NONE" }
                                 : { key: icon.key, glyph: icon.glyph })
    }
    return out
  }

  // "auto" and "theme" are the two the page can offer; a named family is shown
  // as the third option so choosing it back is possible after naming one.
  readonly property var fontOptions: {
    var out = [{ key: "auto", label: "AUTO" }, { key: "theme", label: "THEME" }]
    var named = String(root.displayFont)
    if (named !== "auto" && named !== "theme" && named !== "")
      out.push({ key: named, label: named.toUpperCase() })
    return out
  }

  // --- heading --------------------------------------------------------------
  Text {
    text: "SETTINGS"
    color: root.chrome ? root.chrome.dim : "transparent"
    font.family: root.chrome ? root.chrome.fontFamily : "monospace"
    font.pixelSize: root.chrome ? root.chrome.labelSize : 10
    font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
  }

  Rectangle {
    width: parent.width
    height: 1
    color: root.chrome ? root.chrome.rule : "transparent"
  }

  // --- the bar --------------------------------------------------------------
  Column {
    width: parent.width
    spacing: 0

    Text {
      text: "IN THE BAR"
      bottomPadding: Style.space(10)
      color: root.chrome ? root.chrome.dimmer : "transparent"
      font.family: root.chrome ? root.chrome.fontFamily : "monospace"
      font.pixelSize: root.chrome ? root.chrome.labelSize : 10
      font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
    }

    SettingRow {
      width: parent.width
      chrome: root.chrome
      label: "Shows"

      SegmentedToggle {
        chrome: root.chrome
        current: root.barMode
        options: [
          { key: "next", label: "NEXT" },
          { key: "date", label: "DATE" },
          { key: "count", label: "COUNT" },
          { key: "clock", label: "CLOCK" },
          { key: "icon", label: "ICON" }
        ]
        onPicked: function(key) { root.optionChanged("barMode", key) }
      }
    }

    SettingRow {
      width: parent.width
      chrome: root.chrome
      label: "Icon"

      SegmentedToggle {
        chrome: root.chrome
        current: root.barIcon
        options: root.iconOptions
        onPicked: function(key) { root.optionChanged("barIcon", key) }
      }
    }

    // Only "next" puts an event's title in the bar, so only "next" has a length
    // to cap. In every other mode the row would be a control with nothing to act on.
    SettingRow {
      width: parent.width
      visible: root.barMode === "next"
      chrome: root.chrome
      label: "Longest title"

      Stepper {
        chrome: root.chrome
        value: root.barMaxTitle
        minimum: 6
        maximum: 48
        suffix: "chars"
        onStepped: function(value) { root.optionChanged("barMaxTitle", value) }
      }
    }
  }

  // --- the calendar ---------------------------------------------------------
  Column {
    width: parent.width
    spacing: 0

    Text {
      text: "THE CALENDAR"
      bottomPadding: Style.space(10)
      color: root.chrome ? root.chrome.dimmer : "transparent"
      font.family: root.chrome ? root.chrome.fontFamily : "monospace"
      font.pixelSize: root.chrome ? root.chrome.labelSize : 10
      font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
    }

    SettingRow {
      width: parent.width
      chrome: root.chrome
      label: "Week starts"

      SegmentedToggle {
        chrome: root.chrome
        current: root.weekStartsMonday ? "mon" : "sun"
        options: [{ key: "mon", label: "MON" }, { key: "sun", label: "SUN" }]
        onPicked: function(key) { root.optionChanged("weekStartsMonday", key === "mon") }
      }
    }

    SettingRow {
      width: parent.width
      chrome: root.chrome
      label: "Week numbers"

      SegmentedToggle {
        chrome: root.chrome
        current: root.showWeekNumbers ? "on" : "off"
        options: [{ key: "on", label: "ON" }, { key: "off", label: "OFF" }]
        onPicked: function(key) { root.optionChanged("showWeekNumbers", key === "on") }
      }
    }

    SettingRow {
      width: parent.width
      chrome: root.chrome
      label: "Weeks in the rolling grid"

      Stepper {
        chrome: root.chrome
        value: root.weeksShown
        minimum: 1
        maximum: 8
        onStepped: function(value) { root.optionChanged("weeksShown", value) }
      }
    }

    SettingRow {
      width: parent.width
      chrome: root.chrome
      label: "Times"

      SegmentedToggle {
        chrome: root.chrome
        current: root.use24Hour ? "24" : "12"
        options: [{ key: "24", label: "24H" }, { key: "12", label: "12H" }]
        onPicked: function(key) { root.optionChanged("use24Hour", key === "24") }
      }
    }

    SettingRow {
      width: parent.width
      chrome: root.chrome
      label: "Event colours"
      note: "SPREAD TURNS THE THEME ACCENT INTO SIX HUES"

      SegmentedToggle {
        chrome: root.chrome
        current: root.eventPalette
        options: [{ key: "spread", label: "SPREAD" }, { key: "theme", label: "THEME" }]
        onPicked: function(key) { root.optionChanged("eventPalette", key) }
      }
    }

    SettingRow {
      width: parent.width
      chrome: root.chrome
      label: "Headline font"
      note: root.displayFont === "auto" && root.displayFamily !== ""
        ? root.displayFamily.toUpperCase() : ""

      SegmentedToggle {
        chrome: root.chrome
        current: root.displayFont
        options: root.fontOptions
        onPicked: function(key) { root.optionChanged("displayFont", key) }
      }
    }
  }

  // --- where the rest of it lives -------------------------------------------
  Column {
    width: parent.width
    spacing: 0

    SettingRow {
      width: parent.width
      chrome: root.chrome
      clickable: true
      label: "Calendars"
      note: root.calendarsNote
      onClicked: root.calendarsRequested()

      Text {
        text: "\u{F0142}"                          // chevron-right
        color: root.chrome ? root.chrome.dim : "transparent"
        font.family: root.chrome ? root.chrome.glyphFamily : "monospace"
        font.pixelSize: Style.font.icon
      }
    }

    SettingRow {
      width: parent.width
      chrome: root.chrome
      clickable: true
      label: "Events file"
      note: root.eventsPath
      onClicked: root.eventsFileRequested()

      Text {
        text: "\u{F03CC}"                          // open-in-new
        color: root.chrome ? root.chrome.dim : "transparent"
        font.family: root.chrome ? root.chrome.glyphFamily : "monospace"
        font.pixelSize: Style.font.icon
      }
    }
  }

  OutlineButton {
    chrome: root.chrome
    label: "BACK"
    onClicked: root.closed()
  }
}
