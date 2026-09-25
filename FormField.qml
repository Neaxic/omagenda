import QtQuick
import qs.Commons
import qs.Ui

// A labelled input in the mockup's language: a tracked upper-case label over a
// flat field closed by a single rule — no boxes, no rounding. The qs.Ui field
// is kept for its focus and selection behaviour, with its background replaced.
Column {
  id: root

  property var chrome: null
  property string label: ""
  property string placeholder: ""
  property alias text: field.text
  property alias field: field
  property bool focused: field.activeFocus

  signal submitted()
  signal escaped()

  spacing: Style.space(6)

  Text {
    text: root.label
    color: root.chrome ? root.chrome.dim : "transparent"
    font.family: root.chrome ? root.chrome.fontFamily : "monospace"
    font.pixelSize: root.chrome ? root.chrome.labelSize : 10
    font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
  }

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
}
