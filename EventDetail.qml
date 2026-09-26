import QtQuick
import qs.Commons
import "Model.js" as Model

// What the chevron on an event opens: the event set large, its facts as tracked
// label / value pairs, and edit and delete as outline buttons.
Column {
  id: root

  property var chrome: null
  property var occurrence: null
  property bool use24Hour: true

  signal editRequested(string id)
  signal deleteRequested(string id)
  signal closed()

  spacing: Style.space(20)

  Column {
    width: parent.width
    spacing: Style.space(10)

    Text {
      text: root.occurrence ? Model.dayHeading(root.occurrence.iso) : ""
      color: root.chrome ? root.chrome.dim : "transparent"
      font.family: root.chrome ? root.chrome.fontFamily : "monospace"
      font.pixelSize: root.chrome ? root.chrome.labelSize : 10
      font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
    }

    Row {
      width: parent.width
      spacing: Style.space(12)

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.occurrence && root.chrome
          && root.chrome.eventHex(root.occurrence.color) !== ""
        width: Style.space(12)
        height: width
        color: root.occurrence && root.chrome ? root.chrome.eventInk(root.occurrence.color) : "transparent"
      }

      Text {
        width: parent.width - (parent.children[0].visible ? Style.space(24) : 0)
        text: root.occurrence ? root.occurrence.title : ""
        color: root.chrome ? root.chrome.headline : "transparent"
        font.family: root.chrome ? root.chrome.displayFamily : "monospace"
        font.pixelSize: Style.font.display
        font.weight: Font.Bold
        wrapMode: Text.WordWrap
      }
    }
  }

  Rectangle {
    width: parent.width
    height: 1
    color: root.chrome ? root.chrome.rule : "transparent"
  }

  // --- the facts ----------------------------------------------------------------
  Column {
    width: parent.width
    spacing: Style.space(14)

    Repeater {
      model: {
        if (!root.occurrence) return []
        var rows = root.occurrence.spans
          ? [
              { label: "WHEN", value: Model.spanLabel(root.occurrence, root.use24Hour) },
              { label: "RUNS", value: Model.formatDayLong(root.occurrence.startISO)
                                     + " → " + Model.formatDayLong(root.occurrence.endISO) }
            ]
          : [
              { label: "WHEN", value: Model.timeRange(root.occurrence, root.use24Hour) },
              { label: "DATE", value: Model.formatDayLong(root.occurrence.iso) }
            ]
        if (root.occurrence.location !== "")
          rows.push({ label: "PLACE", value: root.occurrence.location })
        if (root.occurrence.repeat !== "none") {
          var value = Model.REPEAT_LABELS[root.occurrence.repeat]
          if (root.occurrence.until !== "")
            value += " until " + Model.formatDayLong(root.occurrence.until)
          rows.push({ label: "REPEATS", value: value })
          rows.push({ label: "SERIES FROM", value: Model.formatDayLong(root.occurrence.date) })
        }
        if (root.occurrence.notes !== "")
          rows.push({ label: "NOTES", value: root.occurrence.notes })
        return rows
      }

      delegate: Row {
        required property var modelData
        width: root.width
        spacing: Style.space(16)

        Text {
          width: Style.space(96)
          text: modelData.label
          color: root.chrome ? root.chrome.dimmer : "transparent"
          font.family: root.chrome ? root.chrome.fontFamily : "monospace"
          font.pixelSize: root.chrome ? root.chrome.labelSize : 10
          font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
        }

        Text {
          width: parent.width - Style.space(96) - Style.space(16)
          text: modelData.value
          color: root.chrome ? root.chrome.body : "transparent"
          font.family: root.chrome ? root.chrome.fontFamily : "monospace"
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }
      }
    }
  }

  // --- actions ------------------------------------------------------------------
  Row {
    spacing: Style.space(10)

    OutlineButton {
      chrome: root.chrome
      glyph: "\u{F0CB6}"                       // pencil-outline
      label: "EDIT"
      onClicked: if (root.occurrence) root.editRequested(root.occurrence.id)
    }

    OutlineButton {
      chrome: root.chrome
      glyph: "\u{F0A7A}"                       // trash-can-outline
      label: root.occurrence && root.occurrence.repeat !== "none" ? "DELETE SERIES" : "DELETE"
      danger: true
      onClicked: if (root.occurrence) root.deleteRequested(root.occurrence.id)
    }

    OutlineButton {
      chrome: root.chrome
      label: "BACK"
      onClicked: root.closed()
    }
  }
}
