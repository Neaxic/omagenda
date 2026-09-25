import QtQuick
import qs.Commons

// Datebook's design tokens in one place, so the six view components don't each
// re-derive them. The values are the ratios measured off the mockup: every ink
// level is the panel foreground at a fixed alpha, so the look survives a theme
// change instead of hard-coding near-black and off-white.
//
// Ratios, for reference (colour over background, mockup #F2F2EF on #08090A):
//   headline 1.00 · body 0.96 · dim 0.47 · dimmer 0.33 · faint 0.21
//   strong edge 0.53 · edge 0.26 · rule 0.17 · hairline 0.12 · fill 0.06
QtObject {
  id: root

  property color foreground: Color.foreground
  property color accent: Color.accent
  property color urgent: Color.urgent

  // The mockup is set end to end in one grotesque, so `fontFamily` is that face
  // and `displayFamily` its headline weight. Nerd Font codepoints live only in
  // the bar's monospace, so every glyph keeps `glyphFamily` instead.
  property string fontFamily: Style.font.family
  property string displayFamily: Style.font.family
  property string glyphFamily: Style.font.family

  // --- ink --------------------------------------------------------------------
  readonly property color headline: foreground
  readonly property color body: Util.alpha(foreground, 0.96)
  readonly property color dim: Util.alpha(foreground, 0.47)
  readonly property color dimmer: Util.alpha(foreground, 0.33)
  readonly property color faint: Util.alpha(foreground, 0.21)

  // --- surfaces ---------------------------------------------------------------
  readonly property color hairline: Util.alpha(foreground, 0.12)   // inside the grid
  readonly property color rule: Util.alpha(foreground, 0.17)       // section dividers
  readonly property color edge: Util.alpha(foreground, 0.26)       // outlined buttons
  readonly property color strongEdge: Util.alpha(foreground, 0.53) // the selected day
  readonly property color fill: Util.alpha(foreground, 0.06)       // icon slab, selection
  readonly property color hoverFill: Util.alpha(foreground, 0.09)
  readonly property color meter: Util.alpha(foreground, 0.89)
  readonly property color onInverted: Color.popups.background

  // --- metrics ----------------------------------------------------------------
  // Design pixels from the mockup, run through Style.space() so a theme's
  // spacing scale still moves everything together.
  readonly property int pad: Style.space(32)
  readonly property int gutter: Style.space(33)          // the week-number column
  readonly property int rowHeight: Style.space(63)
  readonly property int cellPad: Style.space(12)
  readonly property int slab: Style.space(38)            // the header icon button
  readonly property int control: Style.space(34)         // the + button
  readonly property int segment: Style.space(28)         // the WEEKS/YEAR toggle
  readonly property int eventRow: Style.space(60)
  readonly property int dot: Style.space(4)
  readonly property int todayDot: Style.space(6)

  // --- type -------------------------------------------------------------------
  // The mockup's 46px is set in a tighter face than anything normally installed,
  // so the headline runs a little smaller here to keep the meter clear of it.
  readonly property int displaySize: Style.fontPx(3.33)  // 40px "September"
  readonly property int displayMuted: Style.fontPx(2.33) // 28px "26"
  readonly property int sectionSize: Style.fontPx(1.5)   // 18px "1 event"
  readonly property real trackedSpacing: Math.max(1, Style.space(1) * 1.2)

  // Uppercase, letter-spaced 10px labels — the mockup's connective tissue.
  readonly property int labelSize: Style.font.caption
}
