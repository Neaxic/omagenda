import QtQuick
import qs.Commons

// The month grid from the mockup: a week-number gutter, seven columns, hairline
// rules between rows and columns, day numbers set left and centred in their row,
// event dots at the bottom-left and today's cell lit from within. Nothing here
// does date arithmetic — Model.monthWeeks() hands it finished rows.
Column {
  id: root

  property var chrome: null
  property var weeks: []            // Model.weeksFrom()
  property string selectedISO: ""
  property bool showWeekNumbers: true

  // The last week of a rolling window is the furthest ahead, so it sits back a
  // little rather than competing with the week you are in.
  property bool fadeLastWeek: true
  property real lastWeekOpacity: 0.55

  signal daySelected(string iso)
  signal dayActivated(string iso)   // double click: straight into the day

  readonly property real gutterWidth: showWeekNumbers ? (chrome ? chrome.gutter : 33) : 0
  readonly property real cellWidth: (width - gutterWidth) / 7

  // Multi-day events are drawn as bars across the days they cover, stacked in
  // lanes. Every row grows by the same amount so the grid stays even, and only
  // when something actually runs across it.
  readonly property real barHeight: Math.max(2, Style.space(3))
  readonly property real barGap: Math.max(1, Style.space(2))
  readonly property real barInset: Style.space(4)
  readonly property real barBottom: Style.space(10)
  readonly property int laneCount: {
    var most = 0
    for (var i = 0; i < weeks.length; i++) {
      var segs = weeks[i].segments || []
      for (var j = 0; j < segs.length; j++) most = Math.max(most, segs[j].lane + 1)
    }
    return Math.min(4, most)
  }
  readonly property real laneStep: barHeight + barGap
  readonly property real rowHeight: (chrome ? chrome.rowHeight : 63) + laneCount * laneStep

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
      readonly property real fade: root.fadeLastWeek && root.weeks.length > 1
        && index === root.weeks.length - 1 ? root.lastWeekOpacity : 1.0

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
        visible: root.showWeekNumbers
        opacity: weekRow.fade
        width: root.gutterWidth
        height: parent.height
        verticalAlignment: Text.AlignVCenter
        text: weekRow.week.week > 0 ? String(weekRow.week.week) : ""
        color: root.chrome ? root.chrome.faint : "transparent"
        font.family: root.chrome ? root.chrome.fontFamily : "monospace"
        font.pixelSize: root.chrome ? root.chrome.labelSize : 10
      }

      // The bars sit above the cells but take no clicks, so the days underneath
      // stay selectable.
      Item {
        x: root.gutterWidth
        width: root.cellWidth * 7
        height: parent.height
        z: 1
        opacity: weekRow.fade

        Repeater {
          model: weekRow.week.segments || []

          delegate: Rectangle {
            required property var modelData
            readonly property bool openLeft: modelData.continuesBefore
            readonly property bool openRight: modelData.continuesAfter

            x: modelData.startCol * root.cellWidth + (openLeft ? 0 : root.barInset)
            width: (modelData.endCol - modelData.startCol + 1) * root.cellWidth
                   - (openLeft ? 0 : root.barInset) - (openRight ? 0 : root.barInset)
            height: root.barHeight
            y: parent.height - root.barBottom - root.barHeight - modelData.lane * root.laneStep
            visible: modelData.lane < root.laneCount
            color: root.chrome ? root.chrome.eventInk(modelData.color) : "transparent"
          }
        }
      }

      Row {
        x: root.gutterWidth
        height: parent.height
        spacing: 0
        opacity: weekRow.fade

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

            // Today: the cell itself lights up — an accent ring and the faintest
            // tint — drawn over the selection so the two stay legible on the day
            // they coincide, which a shared neutral outline could not do.
            Rectangle {
              anchors.fill: parent
              visible: dayCell.day.today
              color: root.chrome ? root.chrome.todayGlow : "transparent"
              border.width: 1
              border.color: root.chrome ? root.chrome.todayEdge : "transparent"
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
                // Days past the month's end only step back one level: on a
                // rolling window they are ordinary future days, and the last
                // row is already fading them a second time.
                if (!dayCell.day.inMonth) return root.chrome.dim
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
              anchors.bottomMargin: root.barBottom + root.laneCount * root.laneStep + Style.space(4)
              spacing: Style.space(4)

              Repeater {
                // One dot per single-day event, each in its own colour. Runs are
                // counted in `count` but drawn as bars, so the dots follow the
                // colour list instead — otherwise every day a run passes through
                // would also carry an inkless dot.
                model: Math.min(3, (dayCell.day.colors || []).length)

                delegate: Rectangle {
                  required property int index
                  width: root.chrome ? root.chrome.dot : 4
                  height: width
                  radius: width / 2
                  color: root.chrome ? root.chrome.eventInk(dayCell.day.colors[index]) : "transparent"
                  opacity: dayCell.day.inMonth ? 1.0 : 0.45
                }
              }
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
