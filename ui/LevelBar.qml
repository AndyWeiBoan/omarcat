// A horizontal capacity bar: how full something is, and whether that is a
// problem. The Overview page is built out of these.
//
// Deliberately not a graph. It answers "how much of it is gone right now",
// which is a single number -- anything about how it got there belongs on the
// subsystem's own page, where there is room for a time axis.
//
// The colour is the second channel of information and carries the judgement:
// the length says how full, the colour says whether full is bad. That is why
// the thresholds are inputs rather than constants -- 80% of RAM is ordinary,
// 80% of a disk is not, and a battery is the other way up entirely.

import QtQuick
import qs.Commons

Item {
  id: root

  // 0-100. Clamped, because a sampler that briefly reports 100.4 should not
  // paint outside the track.
  property real value: 0
  readonly property real fraction: Math.max(0, Math.min(1, root.value / 100))

  property color normalColor: Color.accent
  property color warnColor: Color.urgent
  property color dangerColor: Color.urgent
  property color foreground: Color.popups.text

  // Crossed going UP by default. `inverted` flips the comparison for anything
  // where a LOW reading is the bad one -- a battery being the only case so far.
  property real warnAt: 101
  property real dangerAt: 101
  property bool inverted: false

  // Overrides the thresholds entirely. A charging battery is not in trouble at
  // 10%, so the caller needs a way to say "never mind the number".
  property bool forceNormal: false

  readonly property color activeColor: {
    if (root.forceNormal)
      return root.normalColor;
    if (root.inverted)
      return root.value <= root.dangerAt ? root.dangerColor
           : root.value <= root.warnAt ? root.warnColor
           : root.normalColor;
    return root.value >= root.dangerAt ? root.dangerColor
         : root.value >= root.warnAt ? root.warnColor
         : root.normalColor;
  }

  implicitHeight: Style.space(6)

  Rectangle {
    id: track
    anchors.fill: parent
    radius: height / 2
    color: Util.alpha(root.foreground, 0.14)
  }

  Rectangle {
    height: parent.height
    // Never wider than the track, and never a sliver so thin it reads as an
    // artifact: below about a corner radius a rounded rect degenerates into a
    // dot, so a tiny non-zero reading is drawn as a visible minimum instead of
    // vanishing. A 0.4% CPU is still not 0.
    width: root.fraction <= 0 ? 0 : Math.max(parent.height, parent.width * root.fraction)
    radius: height / 2
    color: root.activeColor

    // Both eased: the fill should glide rather than jump on every sample, and
    // the colour should cross its threshold as a fade rather than a flash --
    // a reading that hovers on 70% would otherwise strobe.
    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 260 } }
  }
}
