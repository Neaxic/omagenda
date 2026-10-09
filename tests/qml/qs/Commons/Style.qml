pragma Singleton
import QtQuick

// Stands in for the shell's Style singleton so a component can be loaded
// outside Quickshell. Only the members the grid reads are here; the numbers
// are the shell's own 1px-per-unit scale.
QtObject {
  readonly property QtObject font: QtObject {
    readonly property int title: 14
    readonly property int body: 12
    readonly property int caption: 10
  }

  function space(n) { return n }
}
