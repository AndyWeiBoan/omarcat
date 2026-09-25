import QtQuick
import qs.Commons
import "../Model.js" as Model

// The name above a grouped list -- "Cores", "Top Processes", "Addresses".
//
// Small, quiet and in title case, the way macOS labels a group in System
// Settings. It used to be uppercase, letter-spaced and in the accent colour,
// which is iStat's convention; in Apple's, blue means interactive and a
// heading that shouts competes with the numbers it is introducing.
//
// It sits ABOVE its group rather than inside it, so the group itself is a
// clean rounded surface with nothing but rows in it.
Text {
  id: root

  property string fontFamily: Style.font.family
  property color foreground: Color.popups.text

  textFormat: Text.PlainText
  color: Util.alpha(foreground, Model.INK.secondary)
  font.family: fontFamily
  font.pixelSize: Style.font.caption
  font.weight: Font.DemiBold
  elide: Text.ElideRight
  // Nerd Font outlines overshoot the em box; reserve it so the first row in a
  // clipping list is never beheaded (mirrors qs.Ui.PanelSectionHeader).
  topPadding: Math.ceil(Style.font.caption * 0.15)
}
