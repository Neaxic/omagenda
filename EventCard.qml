import QtQuick
import qs.Commons
import "Model.js" as Model

// One event in the day's agenda: the title, a meta line of time and place, and
// a chevron into the detail view. A full-width band closed by a hairline, as in
// the mockup — no fill, no rounding, no side borders.
Item {
  id: root

  property var chrome: null
  property var occurrence: null
  property bool use24Hour: true

  signal opened(string id)

  implicitHeight: chrome ? chrome.eventRow : 60

  readonly property string metaLine: {
    if (!occurrence) return ""
    var parts = [occurrence.spans
      ? Model.spanLabel(occurrence, use24Hour)
      : Model.timeRange(occurrence, use24Hour)]
    if (occurrence.recurring || occurrence.repeat !== "none")
      parts.push(Model.REPEAT_LABELS[occurrence.repeat])
    return parts.join("  ·  ")
  }

  Rectangle {
    anchors.fill: parent
    color: mouse.containsMouse
      ? (root.chrome ? root.chrome.fill : "transparent")
      : "transparent"
  }

  // The event's colour, if it has one: a rail inside the band's own padding, so
  // a coloured and an uncoloured event still line their titles up.
  Rectangle {
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(2, Style.space(3))
    height: parent.height - Style.space(18)
    visible: root.occurrence && root.chrome
      && root.chrome.eventHex(root.occurrence.color) !== ""
    color: root.occurrence && root.chrome ? root.chrome.eventInk(root.occurrence.color) : "transparent"
  }

  Column {
    anchors.left: parent.left
    anchors.right: chevron.left
    anchors.leftMargin: Style.space(13)
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(8)

    Text {
      width: parent.width
      text: root.occurrence ? root.occurrence.title : ""
      color: root.chrome ? root.chrome.body : "transparent"
      font.family: root.chrome ? root.chrome.fontFamily : "monospace"
      font.pixelSize: Style.font.title
      elide: Text.ElideRight
    }

    Row {
      spacing: Style.space(6)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.occurrence && root.occurrence.spans
          ? "\u{F0679}"                                     // calendar-range
          : "\u{F0150}"                                     // clock-outline
        color: root.chrome ? root.chrome.dimmer : "transparent"
        font.family: root.chrome ? root.chrome.glyphFamily : "monospace"
        font.pixelSize: Style.font.caption
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.metaLine
        color: root.chrome ? root.chrome.dim : "transparent"
        font.family: root.chrome ? root.chrome.fontFamily : "monospace"
        font.pixelSize: Style.font.bodySmall
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.occurrence && root.occurrence.location !== ""
        text: "  ·  "
        color: root.chrome ? root.chrome.dimmer : "transparent"
        font.family: root.chrome ? root.chrome.fontFamily : "monospace"
        font.pixelSize: Style.font.bodySmall
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.occurrence && root.occurrence.location !== ""
        text: "\u{F07D9}"                                  // map-marker-outline
        color: root.chrome ? root.chrome.dimmer : "transparent"
        font.family: root.chrome ? root.chrome.glyphFamily : "monospace"
        font.pixelSize: Style.font.caption
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.occurrence && root.occurrence.location !== ""
        text: root.occurrence ? root.occurrence.location : ""
        color: root.chrome ? root.chrome.dim : "transparent"
        font.family: root.chrome ? root.chrome.fontFamily : "monospace"
        font.pixelSize: Style.font.bodySmall
      }
    }
  }

  Text {
    id: chevron
    anchors.right: parent.right
    anchors.rightMargin: Style.space(20)
    anchors.verticalCenter: parent.verticalCenter
    text: "\u{F0142}"                                      // chevron-right
    color: root.chrome
      ? (mouse.containsMouse ? root.chrome.body : root.chrome.dimmer)
      : "transparent"
    font.family: root.chrome ? root.chrome.glyphFamily : "monospace"
    font.pixelSize: Style.font.icon
  }

  // The band's closing rule.
  Rectangle {
    anchors.bottom: parent.bottom
    width: parent.width
    height: 1
    color: root.chrome ? root.chrome.rule : "transparent"
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: if (root.occurrence) root.opened(root.occurrence.id)
  }
}
