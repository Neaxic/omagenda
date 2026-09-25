import QtQuick
import qs.Commons

// The mockup's one button shape: a square-cornered outline, an optional glyph,
// and a tracked upper-case label. With no label it collapses to the square
// icon button used for "+" beside the day heading.
Item {
  id: root

  property var chrome: null
  property string glyph: ""
  property string label: ""
  property string tooltip: ""
  property bool danger: false

  signal clicked()

  readonly property bool iconOnly: label === ""
  readonly property color ink: {
    if (!chrome) return "transparent"
    if (!enabled) return chrome.faint
    if (danger) return chrome.urgent
    return mouse.containsMouse ? chrome.headline : chrome.dim
  }

  implicitWidth: iconOnly
    ? (chrome ? chrome.control : 34)
    : content.implicitWidth + Style.space(30)
  implicitHeight: iconOnly ? (chrome ? chrome.control : 34) : Style.space(33)

  Rectangle {
    anchors.fill: parent
    color: mouse.containsMouse && root.enabled
      ? (root.chrome ? root.chrome.fill : "transparent")
      : "transparent"
    border.width: 1
    border.color: root.chrome
      ? (mouse.containsMouse && root.enabled ? root.chrome.strongEdge : root.chrome.edge)
      : "transparent"
  }

  Row {
    id: content
    anchors.centerIn: parent
    spacing: Style.space(10)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.glyph !== ""
      text: root.glyph
      color: root.ink
      font.family: root.chrome ? root.chrome.glyphFamily : "monospace"
      font.pixelSize: root.iconOnly ? Style.font.icon : Style.font.bodySmall
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.iconOnly
      text: root.label
      color: root.ink
      font.family: root.chrome ? root.chrome.fontFamily : "monospace"
      font.pixelSize: root.chrome ? root.chrome.labelSize : 10
      font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    enabled: root.enabled
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
