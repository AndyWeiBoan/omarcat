import QtQuick
import qs.Commons
import "../Model.js" as Model

// The grouped surface macOS builds a settings or stats list out of: a plain
// rounded fill holding rows, with the group's name set ABOVE it rather than
// inside (see SectionTitle).
//
// Faint border, not a drawn outline. A grouped list in macOS is separated from
// its background by tone and a shadow, not by a line; the hairline stays only
// so the group is still legible on a theme whose popup surface is the same
// value as this fill.
Rectangle {
  id: root

  property color foreground: Color.popups.text
  property real padding: Style.space(12)
  property real spacing: Style.space(8)
  default property alias content: column.data

  width: parent ? parent.width : implicitWidth
  implicitHeight: column.implicitHeight + padding * 2
  radius: Style.cornerRadius
  color: Util.alpha(foreground, Model.INK.groupFill)
  border.width: 1
  border.color: Util.alpha(foreground, Model.INK.groupBorder)

  Column {
    id: column
    anchors.fill: parent
    anchors.margins: root.padding
    spacing: root.spacing
  }
}
