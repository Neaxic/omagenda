import QtQuick
import qs.Commons

// One arrow in a pager: a glyph with a generous hit area around it, because the
// mockup's chevrons are small and sit at the very edge of the popup.
Item {
  id: root

  property var chrome: null
  property string glyph: ""
  property string tooltip: ""
  property bool strong: false        // the month jumps, set a step quieter

  signal clicked()

  implicitWidth: Style.space(18)
  implicitHeight: Style.space(24)

  Text {
    anchors.centerIn: parent
    text: root.glyph
    color: {
      if (!root.chrome) return "transparent"
      if (mouse.containsMouse) return root.chrome.headline
      return root.strong ? root.chrome.dim : root.chrome.dimmer
    }
    font.family: root.chrome ? root.chrome.glyphFamily : "monospace"
    font.pixelSize: Style.font.icon
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    anchors.margins: -Style.space(6)
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
