import QtQuick
import qs.Commons
import "Model.js" as Model

// The event palette as swatches. No labels: mainstream calendars name their
// colours things like "Tomato" and "Basil" precisely because the name carries
// no meaning — the bucket you put an event in is yours to define.
Row {
  id: root

  property var chrome: null
  property string current: "none"

  signal picked(string key)

  spacing: Style.space(8)

  Repeater {
    model: Model.EVENT_COLORS

    delegate: Rectangle {
      id: swatch
      required property var modelData
      readonly property bool active: modelData.key === root.current
      readonly property string hex: root.chrome ? root.chrome.eventHex(modelData.key) : ""

      width: Style.space(20)
      height: Style.space(20)
      color: hex === "" ? "transparent" : hex
      border.width: swatch.active || swatchMouse.containsMouse ? Math.max(1, Style.space(2)) : 1
      border.color: {
        if (!root.chrome) return "transparent"
        if (swatch.active) return root.chrome.headline
        return swatchMouse.containsMouse ? root.chrome.strongEdge : root.chrome.edge
      }

      // "No colour" is the empty square, struck through so it does not read as
      // a swatch that failed to load.
      Rectangle {
        visible: swatch.hex === ""
        anchors.centerIn: parent
        width: parent.width - Style.space(8)
        height: 1
        rotation: -45
        color: root.chrome ? root.chrome.dim : "transparent"
      }

      MouseArea {
        id: swatchMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked(swatch.modelData.key)
      }
    }
  }
}
