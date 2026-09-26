import QtQuick
import qs.Commons

// One line in the calendars list: a swatch that is filled when the calendar is
// being synced and an empty outline when it is not, its name, and whatever is
// worth saying about it on the right. Clicking anywhere on the row adds or drops
// it — there is no separate checkbox, because the swatch already is one.
Item {
  id: root

  property var chrome: null
  property string name: ""
  property string note: ""
  property string color: "none"
  property bool added: false
  // The local store cannot be dropped, so its row does not pretend to be a control.
  property bool fixed: false

  signal toggled()

  implicitHeight: Style.space(44)
  height: implicitHeight

  readonly property color swatchInk: {
    if (!chrome) return "transparent"
    var hex = chrome.eventHex(root.color)
    return hex === "" ? chrome.dim : hex
  }

  Rectangle {
    anchors.fill: parent
    color: mouse.containsMouse && !root.fixed
      ? (root.chrome ? root.chrome.fill : "transparent")
      : "transparent"
  }

  Row {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(14)

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(12)
      height: width
      color: root.added ? root.swatchInk : "transparent"
      border.width: root.added ? 0 : 1
      border.color: root.chrome ? root.chrome.edge : "transparent"
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - Style.space(12) - Style.space(28) - noteText.width
      text: root.name
      color: root.chrome
        ? (root.added ? root.chrome.body : root.chrome.dim)
        : "transparent"
      font.family: root.chrome ? root.chrome.fontFamily : "monospace"
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }

    Text {
      id: noteText
      anchors.verticalCenter: parent.verticalCenter
      text: root.note
      color: root.chrome ? root.chrome.dimmer : "transparent"
      font.family: root.chrome ? root.chrome.fontFamily : "monospace"
      font.pixelSize: root.chrome ? root.chrome.labelSize : 10
      font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
    }
  }

  Rectangle {
    anchors.bottom: parent.bottom
    width: parent.width
    height: 1
    color: root.chrome ? root.chrome.hairline : "transparent"
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    enabled: !root.fixed
    hoverEnabled: !root.fixed
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled()
  }
}
