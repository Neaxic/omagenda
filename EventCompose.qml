import QtQuick
import qs.Commons
import "Model.js" as Model

// New event / edit event. Deliberately flat: labelled rules rather than boxes,
// a repeat switch built from the same segmented control as WEEKS/YEAR, and the
// two actions as outline buttons.
//
// The date can be typed or picked: the calendar glyph in the DATE field opens a
// month under the row, and picking a day writes into the same field you would
// otherwise type into. Neither way is privileged, and the picker stays shut
// unless it is asked for.
Column {
  id: root

  property var chrome: null
  property string dateISO: ""
  property string todayISO: ""
  property bool mondayFirst: true
  property string editingId: ""      // "" while creating
  property string error: ""

  // The picker is opt-in and remembers nothing: it opens on whatever the field
  // says and closes the moment a day is chosen.
  property bool pickerOpen: false

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
      pickerOpen = false
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
    // The event's own colour, not the calendar tint it is drawn in.
    colorValue = occurrence.ownColor === undefined ? occurrence.color : occurrence.ownColor
    sourceValue = occurrence.source || "local"
    pickerOpen = false
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
      trailingGlyph: "\u{F00ED}"                 // calendar
      trailingActive: root.pickerOpen
      onTrailingClicked: root.pickerOpen = !root.pickerOpen
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

  DatePicker {
    width: parent.width
    visible: root.pickerOpen
    chrome: root.chrome
    iso: dateField.text
    todayISO: root.todayISO
    mondayFirst: root.mondayFirst
    onPicked: function(iso) {
      dateField.text = iso
      root.pickerOpen = false
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
