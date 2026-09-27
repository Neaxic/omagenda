import QtQuick
import qs.Commons

// A number the arrows walk, for the three settings that are counts. It is the
// pager's own chevrons either side of the value, so a setting reads as the same
// kind of control as paging a month — and it clamps rather than wrapping, since
// there is nothing past 8 weeks to wrap to.
Row {
  id: root

  property var chrome: null
  property int value: 0
  property int minimum: 0
  property int maximum: 99
  property int step: 1
  property string suffix: ""

  signal stepped(int value)

  spacing: Style.space(4)

  function move(delta) {
    var next = Math.max(minimum, Math.min(maximum, value + delta * step))
    if (next !== value) root.stepped(next)
  }

  PagerArrow {
    anchors.verticalCenter: parent.verticalCenter
    chrome: root.chrome
    glyph: "\u{F0141}"                            // chevron-left
    strong: root.value > root.minimum
    onClicked: root.move(-1)
  }

  Text {
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(46)
    horizontalAlignment: Text.AlignHCenter
    text: root.value + (root.suffix === "" ? "" : " " + root.suffix)
    color: root.chrome ? root.chrome.body : "transparent"
    font.family: root.chrome ? root.chrome.fontFamily : "monospace"
    font.pixelSize: Style.font.bodySmall
  }

  PagerArrow {
    anchors.verticalCenter: parent.verticalCenter
    chrome: root.chrome
    glyph: "\u{F0142}"                            // chevron-right
    strong: root.value < root.maximum
    onClicked: root.move(1)
  }
}
