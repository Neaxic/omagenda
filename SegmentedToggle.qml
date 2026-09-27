import QtQuick
import qs.Commons

// The WEEKS / YEAR switch: one outlined box, the active half filled solid with
// the panel's ink and its label knocked out in the background colour.
//
// An option may carry a `glyph` as well as, or instead of, its label — the bar
// icon is chosen by looking at the icons themselves, not at names for them.
Item {
  id: root

  property var chrome: null
  property var options: []            // [{ key, label, glyph }]
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

        width: Math.max(Style.space(50), content.implicitWidth + Style.space(18))
        height: root.height

        Rectangle {
          anchors.fill: parent
          anchors.margins: 1
          visible: segment.active
          color: root.chrome ? root.chrome.body : "transparent"
        }

        readonly property color ink: {
          if (!root.chrome) return "transparent"
          if (segment.active) return root.chrome.onInverted
          return segmentMouse.containsMouse ? root.chrome.body : root.chrome.dim
        }

        Row {
          id: content
          anchors.centerIn: parent
          spacing: Style.space(6)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: segment.modelData.glyph === undefined ? "" : segment.modelData.glyph
            color: segment.ink
            font.family: root.chrome ? root.chrome.glyphFamily : "monospace"
            // A segment that is only a glyph has to carry the whole meaning, so
            // it is set at icon size rather than beside a label.
            font.pixelSize: segment.modelData.label === undefined || segment.modelData.label === ""
              ? Style.font.icon : Style.font.bodySmall
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: segment.modelData.label === undefined ? "" : segment.modelData.label
            color: segment.ink
            font.family: root.chrome ? root.chrome.fontFamily : "monospace"
            font.pixelSize: root.chrome ? root.chrome.labelSize : 10
            font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
          }
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
