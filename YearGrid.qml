import QtQuick
import qs.Commons

// The YEAR half of the toggle: twelve months on the same hairline grid, each a
// miniature of the month view. A day with events is a solid mark, today is
// ringed in the same accent the month grid lights it with, and clicking a month
// drops back into the week view on it.
Grid {
  id: root

  property var chrome: null
  property var months: []            // Model.yearMonths()
  property int currentMonth: -1      // the month the calendar is standing on
  property int todayMonth: -1

  signal monthPicked(int month)

  columns: 4
  spacing: 0

  readonly property real cellWidth: width / columns
  readonly property real markSize: Math.max(2, Style.space(4))
  readonly property real markGap: Math.max(1, Style.space(3))

  Repeater {
    model: root.months

    delegate: Item {
      id: monthCell
      required property var modelData
      required property int index
      readonly property bool current: index === root.currentMonth

      width: root.cellWidth
      height: Style.space(112)

      // Hairlines on the leading edges only, so the block keeps an open outside.
      Rectangle {
        width: 1
        height: parent.height
        visible: monthCell.index % root.columns !== 0
        color: root.chrome ? root.chrome.hairline : "transparent"
      }

      Rectangle {
        width: parent.width
        height: 1
        visible: monthCell.index >= root.columns
        color: root.chrome ? root.chrome.hairline : "transparent"
      }

      Rectangle {
        anchors.fill: parent
        anchors.margins: Style.space(1)
        color: monthMouse.containsMouse
          ? (root.chrome ? root.chrome.hoverFill : "transparent")
          : (monthCell.current ? (root.chrome ? root.chrome.fill : "transparent") : "transparent")
        border.width: monthCell.current ? 1 : 0
        border.color: root.chrome ? root.chrome.strongEdge : "transparent"
      }

      Column {
        anchors.fill: parent
        anchors.margins: Style.space(12)
        spacing: Style.space(10)

        Text {
          text: monthCell.modelData.short.toUpperCase()
          color: {
            if (!root.chrome) return "transparent"
            if (monthCell.current) return root.chrome.headline
            return monthCell.index === root.todayMonth ? root.chrome.body : root.chrome.dim
          }
          font.family: root.chrome ? root.chrome.fontFamily : "monospace"
          font.pixelSize: root.chrome ? root.chrome.labelSize : 10
          font.letterSpacing: root.chrome ? root.chrome.trackedSpacing : 1
        }

        // The miniature: one mark per day, laid out on the month's own weeks.
        Column {
          spacing: root.markGap

          Repeater {
            model: monthCell.modelData.weeks

            delegate: Row {
              required property var modelData
              spacing: root.markGap

              Repeater {
                model: modelData.days

                delegate: Rectangle {
                  required property var modelData
                  width: root.markSize
                  height: root.markSize
                  color: {
                    if (!root.chrome || modelData.iso === "") return "transparent"
                    if (modelData.count > 0) return root.chrome.body
                    return root.chrome.faint
                  }
                  border.width: modelData.today ? 1 : 0
                  border.color: root.chrome ? root.chrome.todayEdge : "transparent"
                }
              }
            }
          }
        }
      }

      MouseArea {
        id: monthMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.monthPicked(monthCell.index)
      }
    }
  }
}
