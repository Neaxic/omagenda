import QtQuick
import qs.Commons

// One line of the settings page: what the setting is on the left, the control
// that changes it on the right, and the same hairline the calendars list is
// ruled with. The control is whatever is declared inside the row, so a row does
// not care whether it holds a switch, a stepper or a chevron.
//
// A `clickable` row is the whole line: that is how the pages this one leads to
// are opened. Ordinary rows leave their mouse area disabled so the control
// inside them keeps every click.
Item {
  id: root

  property var chrome: null
  property string label: ""
  // A second line under the label, for the settings whose name is not the whole
  // story. Left empty it takes no room at all.
  property string note: ""
  property bool clickable: false

  default property alias content: holder.data

  signal clicked()

  readonly property real gap: Style.space(16)

  implicitHeight: Math.max(Style.space(46), labels.implicitHeight + gap * 2,
                           holder.implicitHeight + gap)
  height: implicitHeight

  Rectangle {
    anchors.fill: parent
    color: mouse.containsMouse
      ? (root.chrome ? root.chrome.fill : "transparent")
      : "transparent"
  }

  Column {
    id: labels
    anchors.left: parent.left
    anchors.right: holder.left
    anchors.rightMargin: root.gap
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(3)

    Text {
      width: parent.width
      text: root.label
      color: root.chrome ? root.chrome.body : "transparent"
      font.family: root.chrome ? root.chrome.fontFamily : "monospace"
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      visible: root.note !== ""
      text: root.note
      color: root.chrome ? root.chrome.dimmer : "transparent"
      font.family: root.chrome ? root.chrome.fontFamily : "monospace"
      font.pixelSize: root.chrome ? root.chrome.labelSize : 10
      elide: Text.ElideRight
    }
  }

  Item {
    id: holder
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height
    width: implicitWidth
    height: implicitHeight
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
    enabled: root.clickable
    hoverEnabled: root.clickable
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
