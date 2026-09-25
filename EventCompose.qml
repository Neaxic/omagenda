import QtQuick
import qs.Commons
import "Model.js" as Model

// New event / edit event. Deliberately flat: labelled rules rather than boxes,
// a repeat switch built from the same segmented control as WEEKS/YEAR, and the
// two actions as outline buttons.
Column {
  id: root

  property var chrome: null
  property string dateISO: ""
  property string editingId: ""      // "" while creating
  property string error: ""

  // { title, date, time, durationMin, location, repeat }
  signal saved(var values)
  signal cancelled()

  property string repeatValue: "none"
  property string colorValue: "none"

  spacing: Style.space(20)

  function load(occurrence) {
    if (!occurrence) {
      titleField.text = ""
      timeField.text = ""
      lengthField.text = ""
      placeField.text = ""
      repeatValue = "none"
      colorValue = "none"
      return
    }
    titleField.text = occurrence.title
    timeField.text = occurrence.time
    lengthField.text = occurrence.durationMin > 0 ? String(occurrence.durationMin) : ""
    placeField.text = occurrence.location
    repeatValue = occurrence.repeat
    colorValue = occurrence.color
  }

  function focusTitle() { titleField.field.forceActiveFocus() }

  function submit() {
    root.saved({
      title: titleField.text,
      date: dateField.text,
      time: timeField.text,
      durationMin: parseInt(lengthField.text, 10) || 0,
      location: placeField.text,
      color: root.colorValue,
      repeat: root.repeatValue
    })
  }

  readonly property bool anyFieldFocused: titleField.focused || dateField.focused
    || timeField.focused || lengthField.focused || placeField.focused

  Text {
    text: root.editingId === "" ? "NEW EVENT" : "EDIT EVENT"
    color: root.chrome ? root.chrome.dim : "transparent"
    font.family: root.chrome ? root.chrome.fontFamily : "monospace"
    font.pixelSize: root.chrome ? root.chrome.labelSize : 10
    font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
  }

  FormField {
    id: titleField
    width: parent.width
    chrome: root.chrome
    label: "TITLE"
    placeholder: "Design review"
    onSubmitted: root.submit()
    onEscaped: root.cancelled()
  }

  Row {
    width: parent.width
    spacing: Style.space(20)

    FormField {
      id: dateField
      width: (parent.width - Style.space(40)) / 3
      chrome: root.chrome
      label: "DATE"
      placeholder: "YYYY-MM-DD"
      text: root.dateISO
      onSubmitted: root.submit()
      onEscaped: root.cancelled()
    }

    FormField {
      id: timeField
      width: (parent.width - Style.space(40)) / 3
      chrome: root.chrome
      label: "TIME"
      placeholder: "14:00 — blank for all day"
      onSubmitted: root.submit()
      onEscaped: root.cancelled()
    }

    FormField {
      id: lengthField
      width: (parent.width - Style.space(40)) / 3
      chrome: root.chrome
      label: "MINUTES"
      placeholder: "60"
      onSubmitted: root.submit()
      onEscaped: root.cancelled()
    }
  }

  FormField {
    id: placeField
    width: parent.width
    chrome: root.chrome
    label: "PLACE"
    placeholder: "Studio 2"
    onSubmitted: root.submit()
    onEscaped: root.cancelled()
  }

  Column {
    width: parent.width
    spacing: Style.space(8)

    Text {
      text: "COLOUR"
      color: root.chrome ? root.chrome.dim : "transparent"
      font.family: root.chrome ? root.chrome.fontFamily : "monospace"
      font.pixelSize: root.chrome ? root.chrome.labelSize : 10
      font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
    }

    ColorPicker {
      chrome: root.chrome
      current: root.colorValue
      onPicked: function(key) { root.colorValue = key }
    }
  }

  Column {
    width: parent.width
    spacing: Style.space(8)

    Text {
      text: "REPEATS"
      color: root.chrome ? root.chrome.dim : "transparent"
      font.family: root.chrome ? root.chrome.fontFamily : "monospace"
      font.pixelSize: root.chrome ? root.chrome.labelSize : 10
      font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
    }

    SegmentedToggle {
      chrome: root.chrome
      current: root.repeatValue
      options: [
        { key: "none", label: "ONCE" },
        { key: "daily", label: "DAY" },
        { key: "weekly", label: "WEEK" },
        { key: "monthly", label: "MONTH" },
        { key: "yearly", label: "YEAR" }
      ]
      onPicked: function(key) { root.repeatValue = key }
    }
  }

  Text {
    width: parent.width
    visible: root.error !== ""
    text: root.error
    color: root.chrome ? root.chrome.urgent : "transparent"
    font.family: root.chrome ? root.chrome.fontFamily : "monospace"
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  Row {
    spacing: Style.space(10)

    OutlineButton {
      chrome: root.chrome
      glyph: "\u{F012C}"                       // check
      label: root.editingId === "" ? "ADD EVENT" : "SAVE"
      onClicked: root.submit()
    }

    OutlineButton {
      chrome: root.chrome
      label: "CANCEL"
      onClicked: root.cancelled()
    }
  }
}
