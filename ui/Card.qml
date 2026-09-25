import QtQuick
import qs.Commons
import "../Model.js" as Model

// The grouped surface macOS builds a stats or settings list out of: a rounded
// panel holding rows, with the group's name set ABOVE it (see SectionTitle) and
// a soft shadow under it.
//
// **It is LIGHTER than the panel, not darker.** This used to tint towards the
// text colour, which on a light theme made every group a grey slab on a lighter
// background -- the opposite of what the real thing does. Measured off a macOS
// Control Center over nine known wallpapers, a card is pure white at alpha
// 0.337 over the panel material; the panel itself is #dadada at 0.365. White at
// a low alpha lifts a surface in a dark theme just as well, which is why the
// rule here is "white, at an alpha that depends on how light the panel already
// is" rather than "the theme's foreground, inverted".
//
// The shadow is what stops the group floating without weight. It cannot simply
// be drawn behind: at a third opaque, a shadow under the fill shows through and
// darkens the middle of the group, which the reference never does. GroupShadow
// masks it away.
Item {
  id: root

  property color foreground: Color.popups.text
  property real padding: Style.space(12)
  property real spacing: Style.space(8)
  default property alias content: column.data

  // How light the surface underneath already is. A light panel takes the
  // measured 0.337; a dark one would be washed out by it, and macOS's own dark
  // mode uses a much thinner white.
  readonly property bool onLightSurface: {
    var bg = Color.popups.background
    return (0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b) > 0.5
  }

  width: parent ? parent.width : implicitWidth
  implicitHeight: column.implicitHeight + padding * 2
  height: implicitHeight

  // Behind the fill, so it is declared as the value of a named property with an
  // explicit parent: a plain child of this Item would be appended to the
  // default property, which is the content column.
  property Item groupShadow: GroupShadow {
    parent: root
    x: 0
    y: 0
    width: root.width
    height: root.height
    z: -1
    radius: fill.radius
    color: Qt.rgba(0, 0, 0, root.onLightSurface ? 0.22 : 0.30)
    spread: 6
    offsetY: 1.5
  }

  Rectangle {
    id: fill
    anchors.fill: parent
    radius: Style.cornerRadius
    color: Qt.rgba(1, 1, 1, root.onLightSurface ? 0.337 : 0.10)
    // No drawn outline. A grouped list in macOS is separated from what is
    // behind it by tone and a shadow, not by a line.
    border.width: 0
  }

  Column {
    id: column
    anchors.fill: parent
    anchors.margins: root.padding
    spacing: root.spacing
  }
}
