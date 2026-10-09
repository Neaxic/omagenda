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
  property string barFormat: ""
  property string barIcon: "calendar"
  property int barMaxTitle: 18
  // Everything Model.barLabel needs, straight off the service, so the field can
  // show what a format renders to before it is saved. A preview off real values
  // is the only way to tell "{today.mon}" from "{today.month}" at a glance.
  property var previewInputs: ({})
  property string displayFont: "auto"
  property string displayFamily: ""      // what "auto" actually resolved to
  property bool weekStartsMonday: true
  property bool showWeekNumbers: true
  property int weeksShown: 3
  property string opensOn: "month"
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

  // While the format field has focus the page's letter shortcuts have to stand
  // down, or typing a "c" would open the calendars instead of a character. Same
  // contract the compose form has with the panel.
  readonly property bool anyFieldFocused: formatField.focused

  // Saved on Enter or on leaving the field rather than on every keystroke: a
  // format is unfinished for most of the time it is being typed, and each save
  // is a write to shell.json. A format naming a token we do not have is never
  // stored — the line under the field says so instead.
  function saveFormat() {
    if (root.formatIssue !== "") return
    if (formatField.text === root.barFormat) return
    root.optionChanged("barFormat", formatField.text)
  }

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

  // What the format in the field renders to right now, and what is wrong with it.
  // Both follow the field rather than the saved setting: they are there to be
  // read while typing.
  property string draftFormat: ""
  readonly property string formatIssue: Model.barFormatIssue(root.draftFormat)
  readonly property string formatPreview: {
    if (root.formatIssue !== "") return ""
    var inputs = {}
    for (var key in root.previewInputs) inputs[key] = root.previewInputs[key]
    inputs.mode = "custom"
    inputs.format = root.draftFormat
    return Model.barLabel(inputs)
  }

  // Whether the format asks for a title without capping it itself, which is the
  // only case where "Longest title" still has something to act on. Asked of the
  // parser rather than the text, so spacing inside the braces does not matter.
  readonly property bool capsATitle: {
    var tokens = Model.barFormatTokens(root.barFormat)
    for (var i = 0; i < tokens.length; i++)
      if (tokens[i].name === "next.title" && !/^\d+$/.test(tokens[i].arg)) return true
    return false
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
    textFormat: Text.PlainText
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
      textFormat: Text.PlainText
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
          { key: "icon", label: "ICON" },
          { key: "custom", label: "CUSTOM" }
        ]
        // Arriving at CUSTOM with nothing written seeds the field with the shape
        // the bar is showing right now, so the first thing you see is what you
        // already had and can edit — never a blank line you have to guess at.
        onPicked: function(key) {
          if (key === "custom" && Model.trim(root.barFormat) === "")
            root.optionChanged("barFormat", Model.barFormatFor(root.barMode, ""))
          root.optionChanged("barMode", key)
        }
      }
    }

    // A format needs the width of the page, not the right-hand column of a row,
    // and it is only worth showing in the mode that reads it.
    Column {
      width: parent.width
      visible: root.barMode === "custom"
      topPadding: Style.space(16)
      bottomPadding: Style.space(16)
      spacing: Style.space(6)

      FormField {
        id: formatField
        width: parent.width
        chrome: root.chrome
        label: "FORMAT"
        placeholder: Model.BAR_FORMATS.next
        text: root.barFormat
        onTextChanged: root.draftFormat = text
        onSubmitted: { root.saveFormat(); field.focus = false }
        // Escape puts the saved format back and hands the page its keys again,
        // so a second Escape leaves the page as it does everywhere else.
        onEscaped: { text = root.barFormat; field.focus = false }
        onFocusedChanged: if (!focused) root.saveFormat()
        Component.onCompleted: root.draftFormat = text
      }

      // One line doing two jobs: what the format says now, or why it cannot.
      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: root.formatIssue !== "" ? root.formatIssue
            : (root.formatPreview === "" ? "shows nothing" : "\u2192  " + root.formatPreview)
        color: {
          if (!root.chrome) return "transparent"
          return root.formatIssue !== "" ? root.chrome.body : root.chrome.dimmer
        }
        font.family: root.chrome ? root.chrome.fontFamily : "monospace"
        font.pixelSize: root.chrome ? root.chrome.labelSize : 10
        elide: Text.ElideRight
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: "{next.title} [optional] || fallback \u00b7 omarchy-shell omagenda barTokens lists them all"
        color: root.chrome ? root.chrome.dimmer : "transparent"
        font.family: root.chrome ? root.chrome.fontFamily : "monospace"
        font.pixelSize: root.chrome ? root.chrome.labelSize : 10
        wrapMode: Text.WordWrap
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

    // Only a title in the bar has a length to cap — the "next" preset, or a
    // custom format that asks for one without capping it itself. In every other
    // mode the row would be a control with nothing to act on.
    SettingRow {
      width: parent.width
      visible: root.barMode === "next" || (root.barMode === "custom" && root.capsATitle)
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
      textFormat: Text.PlainText
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
      label: "Opens on"

      SegmentedToggle {
        chrome: root.chrome
        current: root.opensOn
        options: [{ key: "month", label: "MONTH" }, { key: "weeks", label: "WEEKS" }]
        onPicked: function(key) { root.optionChanged("gridMode", key) }
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
        textFormat: Text.PlainText
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
        textFormat: Text.PlainText
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
