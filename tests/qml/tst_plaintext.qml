import QtQuick
import QtTest
import "../.." as Omagenda
import "../../Model.js" as Model

// Nothing in the popup is ours to trust. A calendar can be shared with the user
// by anyone, and its event titles, locations, notes and even its own name are
// written by that person. Qt's default textFormat is AutoText, which sniffs a
// string and renders anything that looks like markup as rich text — so a title
// of `<img src="https://somewhere/pixel.png">` would have Qt fetch that image,
// which is a tracking pixel the user never opted into and a request that leaves
// the machine outside Google. Every Text in the tree is therefore PlainText,
// and this walks the ones that show external content to keep it that way.
// Run it with:  qmltestrunner -import tests/qml -input tests/qml/tst_plaintext.qml
TestCase {
  id: tc
  name: "PlainTextOnly"
  when: windowShown
  width: 600
  height: 400
  visible: true

  readonly property string hostile: "<img src='https://tracker.example/pixel.png'> Lunch"
  readonly property var occurrence: ({
    id: "x", title: tc.hostile, date: "2026-10-10", time: "12:00", durationMin: 60,
    notes: tc.hostile, location: tc.hostile, color: "none", spans: false, days: 1
  })

  Omagenda.EventCard {
    id: card
    width: 600
    occurrence: tc.occurrence
  }

  Omagenda.EventDetail {
    id: detail
    width: 600
    occurrence: tc.occurrence
  }

  Omagenda.CalendarRow {
    id: calendarRow
    width: 600
    name: tc.hostile
    note: tc.hostile
  }

  Omagenda.MonthGrid {
    id: grid
    width: 600
    weeks: Model.weeksFrom("2026-10-05", 2, { mondayFirst: true, todayISO: "2026-10-10", marks: {} })
  }

  function texts(item, found) {
    for (var i = 0; i < item.children.length; i++) {
      var child = item.children[i]
      // A Text is the only thing here with both of these.
      if (child.textFormat !== undefined && child.text !== undefined) found.push(child)
      texts(child, found)
    }
    return found
  }

  function check(item, label) {
    var found = texts(item, [])
    verify(found.length > 0, label + " has no Text items; the walk found nothing to check")
    for (var i = 0; i < found.length; i++)
      compare(found[i].textFormat, Text.PlainText,
              label + " renders a Text as rich text: " + found[i].text)
    return found
  }

  function test_an_event_card_is_plain() {
    var found = check(card, "EventCard")
    // The title and the location both carry it, and both must arrive as the
    // characters that were written rather than as markup Qt acts on.
    var verbatim = 0
    for (var i = 0; i < found.length; i++) if (found[i].text === tc.hostile) verbatim++
    verify(verbatim >= 1, "the hostile string never reached a Text at all")
  }

  function test_the_detail_page_is_plain() { check(detail, "EventDetail") }

  // The calendar's own name comes from Google too.
  function test_a_calendar_row_is_plain() { check(calendarRow, "CalendarRow") }

  function test_the_grid_is_plain() { check(grid, "MonthGrid") }
}
