import QtQuick
import qs.Commons
import "../Model.js" as Model

// The separator between two rows of a grouped list. Inset on the left to where
// the row's text starts, flush to the right edge -- Apple's rule, and the
// reason a grouped list reads as one object rather than as a stack of slabs.
Rectangle {
  id: root

  property color foreground: Color.popups.text
  property real inset: 0

  x: inset
  width: (parent ? parent.width : 0) - inset
  height: 1
  color: Util.alpha(foreground, Model.INK.separator)
}
