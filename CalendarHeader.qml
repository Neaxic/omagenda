import QtQuick
import qs.Commons
import "Model.js" as Model

// The mockup's masthead: a filled glyph slab, the month set huge with the
// selected day trailing it in a quieter weight, and a year meter on the right
// showing how much of the year has gone.
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
  // Top-aligned rather than baseline-aligned, as in the mockup: the smaller
  // number hangs off the top of the word.
  // Anchored rather than put in a Row: the smaller number hangs from the top of
  // the word, which a positioner would fight.
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
      anchors.top: monthText.top
      anchors.topMargin: Style.space(3)
      text: root.trailing
      color: root.chrome ? root.chrome.dim : "transparent"
      font.family: root.chrome ? root.chrome.displayFamily : "monospace"
      font.pixelSize: root.chrome ? root.chrome.displayMuted : 33
    }
  }

  // --- year meter and the view switch --------------------------------------------
  Column {
    id: rightStack
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(10)

  Row {
    anchors.right: parent.right
    spacing: Style.space(10)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: String(root.year)
      color: root.chrome ? root.chrome.dim : "transparent"
      font.family: root.chrome ? root.chrome.fontFamily : "monospace"
      font.pixelSize: root.chrome ? root.chrome.labelSize : 10
      font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
    }

    Item {
      width: Style.space(128)
      height: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Math.max(1, Style.space(2))
        color: root.chrome ? root.chrome.hairline : "transparent"
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * Math.max(0, Math.min(1, root.progress))
        height: Math.max(1, Style.space(2))
        color: root.chrome ? root.chrome.meter : "transparent"

        Behavior on width {
          NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Model.percentLabel(root.progress)
      color: root.chrome ? root.chrome.dim : "transparent"
      font.family: root.chrome ? root.chrome.fontFamily : "monospace"
      font.pixelSize: root.chrome ? root.chrome.labelSize : 10
      font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
    }
  }

    Loader {
      anchors.right: parent.right
      sourceComponent: root.trailingControl
    }
  }
}
