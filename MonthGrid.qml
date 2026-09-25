import QtQuick
import qs.Commons

// The month grid: a weekday header plus one cell per day, driven entirely by the
// flat cell list Model.monthCells() builds. It does no date arithmetic of its
// own — a cell already knows whether it is today, in the month, a weekend, and
// how many events it holds.
Column {
  id: root

  // Cells from Model.monthCells(), and the labels from Model.weekdayLabels().
  property var cells: []
  property var weekdayLabels: []
  property bool showWeekNumbers: true
  property string selectedISO: ""

  property color foreground: Color.foreground
  property color accent: Color.accent
  property color dim: Qt.darker(foreground, 1.55)
  property color hairline: Style.normalBorderFor(foreground, accent, Color.urgent)
  property string fontFamily: Style.font.family

  signal daySelected(string iso)

  readonly property int columns: showWeekNumbers ? 8 : 7
  readonly property real gap: Style.space(2)
  readonly property real cellWidth: (width - gap * (columns - 1)) / columns
  readonly property real cellHeight: Math.max(Style.space(26), cellWidth * 0.82)

  spacing: Style.space(4)

  // --- weekday header ---------------------------------------------------------
  Row {
    width: parent.width
    spacing: root.gap

    // Keeps the header aligned with the grid when a week column is present.
    Item {
      visible: root.showWeekNumbers
      width: root.showWeekNumbers ? root.cellWidth : 0
      height: Style.space(14)
    }

    Repeater {
      model: root.weekdayLabels
      delegate: Text {
        required property var modelData
        required property int index
        width: root.cellWidth
        height: Style.space(14)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: String(modelData)
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  // --- days -------------------------------------------------------------------
  Grid {
    width: parent.width
    columns: root.columns
    spacing: root.gap

    Repeater {
      model: root.cells

      delegate: Item {
        required property var modelData
        // Aliased: the dot Repeater below shadows `modelData` with its own.
        readonly property var cell: modelData
        readonly property bool isDay: cell.kind === "day"
        readonly property bool selected: isDay && cell.iso === root.selectedISO

        width: root.cellWidth
        height: root.cellHeight

        // Week number: no fill, no hit area, just a quiet marker in the gutter.
        Text {
          anchors.centerIn: parent
          visible: cell.kind === "week"
          text: cell.week > 0 ? String(cell.week) : ""
          color: root.dim
          opacity: 0.7
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Rectangle {
          anchors.fill: parent
          visible: parent.isDay
          radius: Style.space(4)
          color: parent.selected
            ? Style.selectedFillFor(root.foreground, root.accent, Color.urgent)
            : (dayMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent, Color.urgent) : "transparent")
          // Today is a ring, so it stays visible under the selected fill.
          border.width: cell.today ? Math.max(1, Style.space(1)) : 0
          border.color: root.accent

          Column {
            anchors.centerIn: parent
            spacing: Style.space(2)

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: cell.day > 0 ? String(cell.day) : ""
              color: cell.today ? root.accent : root.foreground
              opacity: cell.inMonth ? (cell.weekend ? 0.75 : 1.0) : 0.35
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: cell.today
            }

            // Up to three dots; a fourth event just keeps the third dot.
            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(2)
              height: Style.space(3)

              Repeater {
                model: Math.min(3, cell.count)
                delegate: Rectangle {
                  width: Style.space(3)
                  height: width
                  radius: width / 2
                  color: root.accent
                  opacity: cell.inMonth ? 0.9 : 0.4
                }
              }
            }
          }

          MouseArea {
            id: dayMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.daySelected(cell.iso)
          }
        }
      }
    }
  }
}
