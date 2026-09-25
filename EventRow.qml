import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// One event on one day: its time (or "All day"), its title, a marker when it is
// a repeat, and a delete button that appears on hover. The occurrence comes from
// Model.eventsOn()/upcoming(), so it already knows which day it is standing on.
Rectangle {
  id: root

  property var occurrence: null
  property bool use24Hour: true

  property color foreground: Color.foreground
  property color dim: Qt.darker(foreground, 1.55)
  property color accent: Color.accent
  property color hoverFill: Style.hoverFillFor(foreground, accent, Color.urgent)
  property string fontFamily: Style.font.family

  signal clicked(string iso)
  signal removeRequested(string id)

  readonly property string timeLabel: {
    if (!occurrence) return ""
    var time = Model.formatTime(occurrence.time, use24Hour)
    return time === "" ? "All day" : time
  }

  implicitHeight: Math.max(Style.space(22), label.implicitHeight + Style.space(6))
  height: implicitHeight
  radius: Style.space(4)
  color: mouse.containsMouse ? root.hoverFill : "transparent"

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: if (root.occurrence) root.clicked(root.occurrence.iso)
  }

  Row {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(6)
    anchors.rightMargin: Style.space(4)
    spacing: Style.space(8)

    Text {
      width: Style.space(52)
      text: root.timeLabel
      color: root.occurrence && root.occurrence.time === "" ? root.dim : root.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      verticalAlignment: Text.AlignVCenter
      height: root.height - Style.space(6)
    }

    Text {
      id: label
      width: parent.width - Style.space(52) - removeButton.width - parent.spacing * 2
      text: root.occurrence ? root.occurrence.title : ""
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
      verticalAlignment: Text.AlignVCenter
      height: root.height - Style.space(6)
    }

    PanelActionButton {
      id: removeButton
      // A repeat shows its cadence instead of a delete button until hovered, so
      // it is obvious which rows are part of a series.
      visible: mouse.containsMouse || removeHover.containsMouse
      iconText: "\u{F0A7A}"                    // trash-can-outline
      tooltipText: root.occurrence && root.occurrence.repeat !== "none"
        ? "Delete the whole series (" + Model.REPEAT_LABELS[root.occurrence.repeat] + ")"
        : "Delete"
      foreground: root.dim
      hoverColor: Color.urgent
      fontFamily: root.fontFamily
      fontSize: Style.font.caption
      onClicked: if (root.occurrence) root.removeRequested(root.occurrence.id)

      MouseArea {
        id: removeHover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
      }
    }

    Text {
      visible: !removeButton.visible && root.occurrence && root.occurrence.repeat !== "none"
      text: "\u{F0E8E}"                        // calendar-sync
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      verticalAlignment: Text.AlignVCenter
      height: root.height - Style.space(6)
    }
  }
}
