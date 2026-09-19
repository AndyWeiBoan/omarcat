import QtQuick
import QtQuick.Effects

// The soft shadow macOS casts from every grouped list onto the panel behind
// it. Same construction as the Control Center's, and for the same reasons.
//
// Two things make this awkward, and both have bitten a previous version:
//
//   1. **It must not reach the group's own interior.** A card here is only 0.337
//      opaque, so anything drawn behind it shows straight through, and the
//      reference's cards are the same value in the middle as at the edge. So
//      the blurred shape is masked by the shape again, inverted, leaving only
//      the halo outside.
//
//   2. **The effect, its source and its mask all have to be the same size, and
//      big enough to hold the blur.** The first attempt let MultiEffect's
//      `autoPaddingEnabled` grow the drawing area past the source, which then
//      sampled the mask outside its own texture: the rounding stopped at the
//      bounding box and every corner kept a square wedge. Here the whole thing
//      lives inside `host`, which is the card plus `pad` on each side, so
//      nothing is ever sampled outside.
//
// A second attempt drew concentric one-pixel outlines instead, which has no
// mask to get wrong but only as many steps as it has pixels -- the banding was
// visible, most of all under the last card where the halo sits alone on the
// panel rather than meeting the next card's.
Item {
  id: root

  property real radius: 0
  // Alpha carries the strength. The blur halves it either side of the edge, so
  // the value just outside the card is roughly half of what is set here.
  property color color: "#00000000"
  // Logical pixels the halo reaches.
  property real spread: 6
  // macOS lights from straight above: below a card the panel darkens by 0.10,
  // above it by 0.03. Shifting the blurred shape down while the mask stays on
  // the card is what produces that -- the halo leaves more of itself below the
  // edge than above it.
  property real offsetY: 0

  visible: color.a > 0

  // The padding has to clear the blur, not just look generous. MultiEffect's
  // blur reaches `blurMax * blur` pixels; if that is wider than the padding the
  // halo hits the host's edge, clamps, and fills the whole padded rectangle --
  // which shows up as a hard-edged square block around each corner. Below,
  // blurMax x blur works out to exactly `spread`, and the padding is 2.5x that.
  readonly property real pad: Math.ceil(spread * 2.5 + Math.abs(offsetY) + 2)

  Item {
    id: host
    x: -root.pad
    y: -root.pad
    width: root.width + root.pad * 2
    height: root.height + root.pad * 2

    // What gets blurred: the card's shape, carrying the shadow's colour.
    Item {
      id: shape
      anchors.fill: parent
      visible: false
      layer.enabled: true

      Rectangle {
        x: root.pad
        y: root.pad + root.offsetY
        width: root.width
        height: root.height
        radius: root.radius
        color: root.color
      }
    }

    // The same shape again, opaque. A mask works on alpha, so the translucent
    // one above would only remove its own fraction of the interior.
    Item {
      id: shapeMask
      anchors.fill: parent
      visible: false
      layer.enabled: true

      Rectangle {
        x: root.pad
        y: root.pad
        width: root.width
        height: root.height
        radius: root.radius
        color: "black"
      }
    }

    MultiEffect {
      anchors.fill: parent
      source: shape
      autoPaddingEnabled: false
      blurEnabled: true
      blurMax: 32
      blur: Math.max(0, Math.min(1, root.spread / 32))
      maskEnabled: true
      maskSource: shapeMask
      maskInverted: true
    }
  }
}
