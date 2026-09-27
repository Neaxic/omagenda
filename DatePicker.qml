import QtQuick
import qs.Commons
import "Model.js" as Model

// The compose form's optional calendar. It only fills the DATE field in — the
// field stays an ordinary text field — so a typed date and a picked one are the
// same thing, and neither way is the "real" one.
//
// Deliberately not the month grid: that one carries week numbers, event dots and
// multi-day bars, none of which help you answer "which day". This is the same
// hairline language at a quarter of the height.
Column {
  id: root

  property var chrome: null
  property string iso: ""            // the date the field currently holds
  property string todayISO: ""
  property bool mondayFirst: true

  signal picked(string iso)

  spacing: Style.space(10)

  // The month on show. It follows the field, and goes on following it when the
  // field is typed into, so the picker never argues with what is written above.
  property int viewYear: 0
  property int viewMonth: 0

  function syncToField() {
    var date = Model.fromISO(root.iso) || Model.fromISO(root.todayISO) || new Date()
    viewYear = date.getFullYear()
    viewMonth = date.getMonth()
  }

  onIsoChanged: syncToField()
  Component.onCompleted: syncToField()

  function step(delta) {
    var moved = Model.addMonths(viewYear, viewMonth, delta)
    viewYear = moved.year
    viewMonth = moved.month
  }

  readonly property var weeks: Model.monthWeeks(viewYear, viewMonth, {
    mondayFirst: root.mondayFirst,
    showAdjacentMonths: true,
    todayISO: root.todayISO
  })

  readonly property real cellWidth: width / 7
  readonly property real cellHeight: Style.space(26)

  // --- the month on show ----------------------------------------------------
  Item {
    width: parent.width
    height: Style.space(24)

    PagerArrow {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      chrome: root.chrome
      glyph: "\u{F0141}"                          // chevron-left
      strong: true
      onClicked: root.step(-1)
    }

    Text {
      anchors.centerIn: parent
      text: (Model.MONTH_NAMES[root.viewMonth] + " " + root.viewYear).toUpperCase()
      color: root.chrome ? root.chrome.dim : "transparent"
      font.family: root.chrome ? root.chrome.fontFamily : "monospace"
      font.pixelSize: root.chrome ? root.chrome.labelSize : 10
      font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
    }

    PagerArrow {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      chrome: root.chrome
      glyph: "\u{F0142}"                          // chevron-right
      strong: true
      onClicked: root.step(1)
    }
  }

  // --- the weekdays ---------------------------------------------------------
  Row {
    width: parent.width

    Repeater {
      model: Model.weekdayLabels(root.mondayFirst)

      delegate: Text {
        required property var modelData
        width: root.cellWidth
        horizontalAlignment: Text.AlignHCenter
        text: modelData
        color: root.chrome ? root.chrome.dimmer : "transparent"
        font.family: root.chrome ? root.chrome.fontFamily : "monospace"
        font.pixelSize: root.chrome ? root.chrome.labelSize : 10
        font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
      }
    }
  }

  Rectangle {
    width: parent.width
    height: 1
    color: root.chrome ? root.chrome.hairline : "transparent"
  }

  // --- the days -------------------------------------------------------------
  Column {
    width: parent.width
    spacing: 0

    Repeater {
      model: root.weeks

      delegate: Row {
        required property var modelData
        width: parent.width
        spacing: 0

        Repeater {
          model: modelData.days

          delegate: Item {
            id: pickCell
            required property var modelData
            readonly property bool chosen: modelData.iso !== "" && modelData.iso === root.iso

            width: root.cellWidth
            height: root.cellHeight

            Rectangle {
              anchors.fill: parent
              anchors.margins: Style.space(1)
              color: pickCell.chosen
                ? (root.chrome ? root.chrome.fill : "transparent")
                : (pickMouse.containsMouse
                   ? (root.chrome ? root.chrome.hoverFill : "transparent")
                   : "transparent")
              border.width: pickCell.chosen ? 1 : 0
              border.color: root.chrome ? root.chrome.strongEdge : "transparent"
            }

            // The same ring the month grid marks today with, so the two views
            // agree about which day is now.
            Rectangle {
              anchors.fill: parent
              anchors.margins: Style.space(1)
              visible: pickCell.modelData.today
              color: root.chrome ? root.chrome.todayGlow : "transparent"
              border.width: 1
              border.color: root.chrome ? root.chrome.todayEdge : "transparent"
            }

            Text {
              anchors.centerIn: parent
              text: pickCell.modelData.iso === "" ? "" : String(pickCell.modelData.day)
              color: {
                if (!root.chrome) return "transparent"
                if (pickCell.chosen) return root.chrome.headline
                return pickCell.modelData.inMonth ? root.chrome.body : root.chrome.dimmer
              }
              font.family: root.chrome ? root.chrome.fontFamily : "monospace"
              font.pixelSize: Style.font.bodySmall
              font.bold: pickCell.chosen
            }

            MouseArea {
              id: pickMouse
              anchors.fill: parent
              enabled: pickCell.modelData.iso !== ""
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.picked(pickCell.modelData.iso)
            }
          }
        }
      }
    }
  }
}
