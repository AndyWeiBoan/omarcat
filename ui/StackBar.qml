// A horizontal bar split into segments that share one total -- the counterpart
// to LevelBar, which shows one quantity against a capacity.
//
// Used where the parts add up to the whole and that is the point: memory is
// apps plus cache plus shared plus free, and four separate bars would hide the
// fact that they are dividing up one fixed amount.
//
// Drawn right-to-left, each segment as a fully rounded rectangle running from
// x = 0 to its own cumulative end. Every one of them is a pill, but only its
// right cap is ever visible -- the segment in front covers the rest. That gives
// clean colour boundaries and a rounded outline without masking the whole bar
// to a rounded shape, which would cost a render target for a six-pixel strip.

import QtQuick
import qs.Commons

Item {
  id: root

  // [{ value: 0..1 of the whole, color, fill: 0..1 of this segment }] in draw
  // order, first segment leftmost.
  //
  // `fill` is optional and defaults to solid. Where it is given, the segment is
  // drawn as a dim slot with a bright portion inside it -- the shape a partition
  // map wants: how the whole is divided, and how full each division is. Without
  // it a division that is tiny but nearly full is invisible, and giving tiny
  // segments a minimum width instead would misstate the proportion, which is
  // the one thing this bar exists to get right.
  property var segments: []
  property color foreground: Color.popups.text
  property color trackColor: Util.alpha(foreground, 0.14)

  implicitHeight: Style.space(6)

  // Each segment's own span, with a floor: a segment that has ANYTHING in it
  // gets at least one bar-height of width.
  //
  // Without it the legend names colours the bar does not show. A 345 MB
  // partition on a 227 GB disk is 0.15% -- a third of a pixel -- so the row
  // beneath sits there with a purple dot beside it pointing at nothing. The
  // floor is taken back out of the largest segment, so the total is unchanged
  // and only the biggest band pays, where a percent is invisible anyway.
  //
  // A segment that is genuinely empty still gets nothing. The floor says "some,
  // not none"; it does not invent anything.
  readonly property real minSpan: Math.min(0.2, height / Math.max(1, width))

  readonly property var spans: {
    const adj = [];
    for (let i = 0; i < root.segments.length; i++)
      adj.push(Math.max(0, Number(root.segments[i].value) || 0));

    let owed = 0;
    for (let i = 0; i < adj.length; i++) {
      if (adj[i] > 0 && adj[i] < root.minSpan) {
        owed += root.minSpan - adj[i];
        adj[i] = root.minSpan;
      }
    }
    // Take it back from the biggest, one bite at a time, never below the floor.
    while (owed > 1e-6) {
      let big = -1;
      for (let i = 0; i < adj.length; i++)
        if (adj[i] > root.minSpan && (big < 0 || adj[i] > adj[big])) big = i;
      if (big < 0) break;
      const take = Math.min(owed, adj[big] - root.minSpan);
      adj[big] -= take;
      owed -= take;
    }
    return adj;
  }

  // Cumulative ends, clamped so a sampler that overshoots slightly cannot paint
  // past the track.
  readonly property var bounds: {
    const out = [];
    let acc = 0;
    for (let i = 0; i < root.spans.length; i++) {
      acc += root.spans[i];
      out.push(Math.min(1, acc));
    }
    return out;
  }

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: root.trackColor
  }

  // Pass one: the divisions themselves.
  Repeater {
    model: root.segments.length

    delegate: Rectangle {
      required property int index
      // Reverse order: the last segment is drawn first and sits at the back.
      readonly property int slot: root.segments.length - 1 - index
      readonly property var spec: root.segments[slot]
      readonly property bool hasFill: spec.fill !== undefined

      height: parent.height
      width: Math.max(0, root.bounds[slot] * parent.width)
      radius: height / 2
      // Dim when this segment carries its own fill, because then the bright
      // colour is reserved for the used part inside it.
      color: hasFill ? Util.alpha(spec.color, 0.3) : spec.color
      visible: width > 0

      Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }
  }

  // Pass two: how full each division is, drawn in place rather than cumulatively.
  Repeater {
    model: root.segments.length

    delegate: Rectangle {
      required property int index
      readonly property var spec: root.segments[index]
      readonly property real start: index === 0 ? 0 : root.bounds[index - 1]
      readonly property real span: Math.max(0, root.bounds[index] - start)
      readonly property real portion: Math.max(0, Math.min(1, Number(spec.fill)))

      visible: spec.fill !== undefined && portion > 0
      x: start * parent.width
      height: parent.height
      // A minimum of one bar height here, unlike the divisions above: this is a
      // "some versus none" reading, not a proportion, and a partition with a
      // little in it should not look empty.
      width: Math.max(height, span * parent.width * portion)
      radius: height / 2
      color: spec.color

      Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }
  }
}
