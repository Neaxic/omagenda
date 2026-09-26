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

  // { title, date, days, time, durationMin, location, color, repeat }
  signal saved(var values)
  signal cancelled()

  property string repeatValue: "none"
  property string colorValue: "none"
  property string sourceValue: "local"
  // [{ key, label }] — the local store plus every synced calendar.
  property var sources: []

  spacing: Style.space(20)

  function load(occurrence) {
    if (!occurrence) {
      // Assigning breaks the binding to dateISO, which is the point: from here
      // on the field is the form's own state, not a view of the selection.
      dateField.text = root.dateISO
      titleField.text = ""
      daysField.text = ""
      timeField.text = ""
      lengthField.text = ""
      placeField.text = ""
      repeatValue = "none"
      colorValue = "none"
      sourceValue = "local"
      return
    }
    // The event's own date, not the day the grid happens to be sitting on.
    dateField.text = occurrence.startISO || occurrence.date
    titleField.text = occurrence.title
    daysField.text = occurrence.days > 1 ? String(occurrence.days) : ""
    timeField.text = occurrence.time
    lengthField.text = occurrence.durationMin > 0 ? String(occurrence.durationMin) : ""
    placeField.text = occurrence.location
    repeatValue = occurrence.repeat
    colorValue = occurrence.color
    sourceValue = occurrence.source || "local"
  }

  function focusTitle() { titleField.field.forceActiveFocus() }

  function submit() {
    root.saved({
      title: titleField.text,
      date: dateField.text,
      days: parseInt(daysField.text, 10) || 1,
      time: timeField.text,
      durationMin: parseInt(lengthField.text, 10) || 0,
      location: placeField.text,
      color: root.colorValue,
      source: root.sourceValue,
      repeat: root.repeatValue
    })
  }

  readonly property bool anyFieldFocused: titleField.focused || dateField.focused
    || daysField.focused || timeField.focused || lengthField.focused || placeField.focused

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
    spacing: Style.space(16)

    // Four across: when it is, how long it runs, what time it starts and how
    // long that sitting lasts.
    readonly property real slot: (width - Style.space(48)) / 4

    FormField {
      id: dateField
      width: parent.slot
      chrome: root.chrome
      label: "DATE"
      placeholder: "YYYY-MM-DD"
      onSubmitted: root.submit()
      onEscaped: root.cancelled()
    }

    FormField {
      id: daysField
      width: parent.slot
      chrome: root.chrome
      label: "DAYS"
      placeholder: "1"
      onSubmitted: root.submit()
      onEscaped: root.cancelled()
    }

    FormField {
      id: timeField
      width: parent.slot
      chrome: root.chrome
      label: "TIME"
      placeholder: "14:00"
      onSubmitted: root.submit()
      onEscaped: root.cancelled()
    }

    FormField {
      id: lengthField
      width: parent.slot
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
    visible: root.sources.length > 1

    Text {
      text: "CALENDAR"
      color: root.chrome ? root.chrome.dim : "transparent"
      font.family: root.chrome ? root.chrome.fontFamily : "monospace"
      font.pixelSize: root.chrome ? root.chrome.labelSize : 10
      font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
    }

    SegmentedToggle {
      chrome: root.chrome
      current: root.sourceValue
      options: root.sources
      onPicked: function(key) { root.sourceValue = key }
    }
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
