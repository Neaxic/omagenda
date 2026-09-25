import QtQuick
import qs.Commons

// The month grid from the mockup: a week-number gutter, seven columns, hairline
// rules between rows and columns, day numbers set left and centred in their row,
// event dots at the bottom-left and a today dot at the top-right. Nothing here
// does date arithmetic — Model.monthWeeks() hands it finished rows.
Column {
  id: root

  property var chrome: null
  property var weeks: []            // Model.monthWeeks()
  property string selectedISO: ""

  signal daySelected(string iso)
  signal dayActivated(string iso)   // double click: straight into the day

  readonly property real gutterWidth: chrome ? chrome.gutter : 33
  readonly property real cellWidth: (width - gutterWidth) / 7
  readonly property real rowHeight: chrome ? chrome.rowHeight : 63

  spacing: 0

  // The grid's top rule reads a touch stronger than the rules inside it.
  Rectangle {
    width: parent.width
    height: 1
    color: root.chrome ? root.chrome.rule : "transparent"
  }

  Repeater {
    model: root.weeks

    delegate: Item {
      id: weekRow
      required property var modelData
      required property int index
      readonly property var week: modelData

      width: root.width
      height: root.rowHeight

      // Row separators sit at the top of every row but the first, so the grid
      // keeps an open bottom edge the way the mockup does.
      Rectangle {
        width: parent.width
        height: 1
        visible: weekRow.index > 0
        color: root.chrome ? root.chrome.hairline : "transparent"
      }

      Text {
        x: 0
        width: root.gutterWidth
        height: parent.height
        verticalAlignment: Text.AlignVCenter
        text: weekRow.week.week > 0 ? String(weekRow.week.week) : ""
        color: root.chrome ? root.chrome.faint : "transparent"
        font.family: root.chrome ? root.chrome.fontFamily : "monospace"
        font.pixelSize: root.chrome ? root.chrome.labelSize : 10
      }

      Row {
        x: root.gutterWidth
        height: parent.height
        spacing: 0

        Repeater {
          model: weekRow.week.days

          delegate: Item {
            id: dayCell
            required property var modelData
            readonly property var day: modelData
            readonly property bool real: day.iso !== ""
            readonly property bool selected: real && day.iso === root.selectedISO

            width: root.cellWidth
            height: root.rowHeight

            // The column rule, drawn on the left edge of every column.
            Rectangle {
              width: 1
              height: parent.height
              color: root.chrome ? root.chrome.hairline : "transparent"
            }

            Rectangle {
              anchors.fill: parent
              color: dayCell.selected
                ? (root.chrome ? root.chrome.fill : "transparent")
                : (cellMouse.containsMouse && dayCell.real
                   ? (root.chrome ? root.chrome.hoverFill : "transparent")
                   : "transparent")
              border.width: dayCell.selected ? 1 : 0
              border.color: root.chrome ? root.chrome.strongEdge : "transparent"
            }

            Text {
              x: root.chrome ? root.chrome.cellPad : 12
              anchors.verticalCenter: parent.verticalCenter
              anchors.verticalCenterOffset: dayCell.day.count > 0 ? -Style.space(5) : 0
              visible: dayCell.real
              text: dayCell.real ? String(dayCell.day.day) : ""
              color: {
                if (!root.chrome) return "transparent"
                if (dayCell.selected) return root.chrome.headline
                if (!dayCell.day.inMonth) return root.chrome.faint
                return root.chrome.body
              }
              font.family: root.chrome ? root.chrome.fontFamily : "monospace"
              font.pixelSize: Style.font.title
              font.bold: dayCell.selected
            }

            // Event dots, bottom left. Three is the ceiling; a fourth event just
            // keeps the third dot rather than crowding the cell.
            Row {
              x: root.chrome ? root.chrome.cellPad : 12
              anchors.bottom: parent.bottom
              anchors.bottomMargin: Style.space(16)
              spacing: Style.space(4)

              Repeater {
                model: Math.min(3, dayCell.day.count)

                delegate: Rectangle {
                  width: root.chrome ? root.chrome.dot : 4
                  height: width
                  radius: width / 2
                  color: root.chrome ? root.chrome.body : "transparent"
                  opacity: dayCell.day.inMonth ? 1.0 : 0.45
                }
              }
            }

            // Today: a filled square at the top right, kept even under the
            // selection outline so "today" and "selected" stay distinguishable.
            Rectangle {
              visible: dayCell.day.today
              width: root.chrome ? root.chrome.todayDot : 6
              height: width
              radius: width / 2
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.rightMargin: Style.space(13)
              anchors.topMargin: Style.space(13)
              color: root.chrome ? root.chrome.headline : "transparent"
            }

            MouseArea {
              id: cellMouse
              anchors.fill: parent
              enabled: dayCell.real
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.daySelected(dayCell.day.iso)
              onDoubleClicked: root.dayActivated(dayCell.day.iso)
            }
          }
        }
      }
    }
  }
}
