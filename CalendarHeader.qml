import QtQuick
import qs.Commons

// The masthead: a filled glyph slab, the month set huge with the selected day
// trailing it in a quieter weight, and the view switch on the right.
Item {
  id: root

  property var chrome: null
  property string title: ""          // "September"
  property string trailing: ""       // "26"
  property int year: 2026
  property real progress: 0          // 0..1

  // Sits under the year meter on the right — the mockup keeps the WEEKS/YEAR
  // switch in the weekday row, but there it cannot share the row with weekday
  // letters that line up with the columns.
  property Component trailingControl: null

  signal slabClicked()

  implicitHeight: Math.max(slab.height, headline.implicitHeight, rightStack.implicitHeight)

  // --- glyph slab ---------------------------------------------------------------
  Rectangle {
    id: slab
    width: root.chrome ? root.chrome.slab : 38
    height: width
    anchors.verticalCenter: parent.verticalCenter
    color: slabMouse.containsMouse
      ? (root.chrome ? root.chrome.hoverFill : "transparent")
      : (root.chrome ? root.chrome.fill : "transparent")

    Text {
      anchors.centerIn: parent
      text: "\u{F00ED}"                                   // md-calendar
      color: root.chrome ? root.chrome.body : "transparent"
      font.family: root.chrome ? root.chrome.glyphFamily : "monospace"
      font.pixelSize: Style.font.iconLarge
    }

    MouseArea {
      id: slabMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.slabClicked()
    }
  }

  // --- month and day ------------------------------------------------------------
  // The two sit on one baseline, so the day reads as part of the same line as
  // the month rather than as a number hung off the top of it. Anchored rather
  // than put in a Row: a positioner has no baseline to align to.
  Item {
    id: headline
    anchors.left: slab.right
    anchors.leftMargin: Style.space(22)
    anchors.verticalCenter: parent.verticalCenter
    anchors.right: rightStack.left
    anchors.rightMargin: Style.space(24)
    implicitHeight: monthText.implicitHeight

    Text {
      id: monthText
      width: Math.min(implicitWidth, Math.max(Style.space(60), headline.width - dayText.width - Style.space(20)))
      elide: Text.ElideRight
      text: root.title
      color: root.chrome ? root.chrome.headline : "transparent"
      font.family: root.chrome ? root.chrome.displayFamily : "monospace"
      font.pixelSize: root.chrome ? root.chrome.displaySize : 46
      font.weight: Font.Bold
      font.letterSpacing: -Style.space(1)
    }

    Text {
      id: dayText
      anchors.left: monthText.right
      anchors.leftMargin: Style.space(20)
      anchors.baseline: monthText.baseline
      text: root.trailing
      color: root.chrome ? root.chrome.dim : "transparent"
      font.family: root.chrome ? root.chrome.displayFamily : "monospace"
      font.pixelSize: root.chrome ? root.chrome.displayMuted : 33
    }
  }

  // --- the view switch ------------------------------------------------------------
  Item {
    id: rightStack
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: switchLoader.width
    implicitHeight: switchLoader.height

    Loader {
      id: switchLoader
      anchors.right: parent.right
      sourceComponent: root.trailingControl
    }
  }
}
