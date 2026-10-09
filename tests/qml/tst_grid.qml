import QtQuick
import QtTest
import "../.." as Omagenda
import "../../Model.js" as Model

// The one test that runs the real QML. Model.wheelSteps is covered by the node
// suite; what this pins down is the wiring around it — that a wheel event
// landing on a day actually reaches the grid and comes back out as a step.
// Run it with:  qmltestrunner -import tests/qml -input tests/qml/tst_grid.qml
TestCase {
  id: tc
  name: "GridScroll"
  when: windowShown
  width: 700
  height: 420
  visible: true

  property var steps: []

  Omagenda.MonthGrid {
    id: grid
    width: 700
    weeks: Model.weeksFrom("2026-10-05", 4, { mondayFirst: true, todayISO: "2026-10-09", marks: {} })
    onStepped: function(delta) { tc.steps.push(delta) }
  }

  function init() {
    tc.steps = []
    grid.wheelAccum = 0
  }

  // 200,30 is inside the first row and past the week-number gutter, so the
  // event lands on a day cell's MouseArea — the pointer's usual home.
  function test_scrolling_over_a_day_pages_forward() {
    mouseWheel(grid, 200, 30, 0, -120)
    compare(tc.steps, [1])
  }

  function test_scrolling_up_pages_back() {
    mouseWheel(grid, 200, 30, 0, 120)
    compare(tc.steps, [-1])
  }

  function test_a_trackpad_needs_a_whole_notch() {
    mouseWheel(grid, 200, 30, 0, -60)
    compare(tc.steps, [])
    mouseWheel(grid, 200, 30, 0, -60)
    compare(tc.steps, [1])
  }

  function test_a_sideways_wheel_is_left_alone() {
    mouseWheel(grid, 200, 30, -240, 0)
    compare(tc.steps, [])
  }

  function test_the_grid_really_is_four_weeks_of_days() {
    compare(grid.weeks.length, 4)
    compare(grid.weeks[0].days.length, 7)
    verify(grid.height > 100)
  }
}
