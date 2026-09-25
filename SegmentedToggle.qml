import QtQuick
import qs.Commons

// The WEEKS / YEAR switch: one outlined box, the active half filled solid with
// the panel's ink and its label knocked out in the background colour.
Item {
  id: root

  property var chrome: null
  property var options: []            // [{ key, label }]
  property string current: ""

  signal picked(string key)

  implicitWidth: row.implicitWidth
  implicitHeight: chrome ? chrome.segment : 28

  Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.width: 1
    border.color: root.chrome ? root.chrome.edge : "transparent"
  }

  Row {
    id: row
    anchors.fill: parent
    spacing: 0

    Repeater {
      model: root.options

      delegate: Item {
        id: segment
        required property var modelData
        readonly property bool active: modelData.key === root.current

        width: Math.max(Style.space(50), segmentLabel.implicitWidth + Style.space(18))
        height: root.height

        Rectangle {
          anchors.fill: parent
          anchors.margins: 1
          visible: segment.active
          color: root.chrome ? root.chrome.body : "transparent"
        }

        Text {
          id: segmentLabel
          anchors.centerIn: parent
          text: segment.modelData.label
          color: {
            if (!root.chrome) return "transparent"
            if (segment.active) return root.chrome.onInverted
            return segmentMouse.containsMouse ? root.chrome.body : root.chrome.dim
          }
          font.family: root.chrome ? root.chrome.fontFamily : "monospace"
          font.pixelSize: root.chrome ? root.chrome.labelSize : 10
          font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
        }

        MouseArea {
          id: segmentMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.picked(segment.modelData.key)
        }
      }
    }
  }
}
