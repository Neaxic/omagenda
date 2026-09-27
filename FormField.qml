import QtQuick
import qs.Commons
import qs.Ui

// A labelled input in the mockup's language: a tracked upper-case label over a
// flat field closed by a single rule — no boxes, no rounding. The qs.Ui field
// is kept for its focus and selection behaviour, with its background replaced.
//
// `trailingGlyph` hangs one glyph inside the right of the field — the date
// field's calendar. It is a button beside the text, never instead of it: the
// field stays typeable with the picker open.
Column {
  id: root

  property var chrome: null
  property string label: ""
  property string placeholder: ""
  property alias text: field.text
  property alias field: field
  property bool focused: field.activeFocus

  property string trailingGlyph: ""
  property bool trailingActive: false

  signal submitted()
  signal escaped()
  signal trailingClicked()

  spacing: Style.space(6)

  Text {
    text: root.label
    color: root.chrome ? root.chrome.dim : "transparent"
    font.family: root.chrome ? root.chrome.fontFamily : "monospace"
    font.pixelSize: root.chrome ? root.chrome.labelSize : 10
    font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
  }

  // The field and its trailing glyph share one box so the glyph can sit inside
  // the rule rather than beside it, which is what keeps the four-across row of
  // fields on their columns.
  Item {
    width: parent.width
    height: field.implicitHeight

    TextField {
      id: field
      width: parent.width
      placeholderText: root.placeholder
      foreground: root.chrome ? root.chrome.body : Color.foreground
      // Quieter than the kit's default, so a placeholder is never mistaken for a
      // value that is already filled in.
      placeholderTextColor: root.chrome ? root.chrome.dimmer : Color.muted
      font.family: root.chrome ? root.chrome.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      horizontalPadding: 0
      rightPadding: root.trailingGlyph === "" ? 0 : Style.space(22)
      verticalPadding: Style.space(6)
      onAccepted: root.submitted()
      Keys.onEscapePressed: root.escaped()

      background: Item {
        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width
          height: 1
          color: {
            if (!root.chrome) return "transparent"
            if (field.activeFocus) return root.chrome.strongEdge
            return field.hovered ? root.chrome.edge : root.chrome.hairline
          }
        }
      }
    }

    Text {
      id: trailing
      visible: root.trailingGlyph !== ""
      anchors.right: parent.right
      anchors.verticalCenter: field.verticalCenter
      anchors.verticalCenterOffset: -Style.space(2)
      text: root.trailingGlyph
      color: {
        if (!root.chrome) return "transparent"
        if (root.trailingActive) return root.chrome.headline
        return trailingMouse.containsMouse ? root.chrome.body : root.chrome.dim
      }
      font.family: root.chrome ? root.chrome.glyphFamily : "monospace"
      font.pixelSize: Style.font.bodySmall

      MouseArea {
        id: trailingMouse
        anchors.fill: parent
        anchors.margins: -Style.space(6)
        enabled: root.trailingGlyph !== ""
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.trailingClicked()
      }
    }
  }
}
