// One subsystem on the Overview page: name, a large current reading, a capacity
// bar that changes colour when the reading matters, and one quiet line of
// supporting detail.
//
// The number is deliberately the biggest thing on the row. This page is read at
// a glance and from a distance; the title only has to be big enough to tell the
// rows apart, because their order never changes.

import QtQuick
import qs.Commons

Column {
  id: root

  property string title: ""
  // The hardware this row is about -- the CPU part, the disk, the wifi chip.
  // Quiet and directly under the title, because it answers "which one is this"
  // and never changes; the number above it is the thing being watched.
  // Empty means the row has nothing honest to say: Fans reports a driver name,
  // not a part, so it gets no line rather than a filler one.
  property string subtitle: ""
  // Pre-formatted by the caller, because not every row is a percentage -- the
  // network row puts an interface name here.
  property string value: ""
  property string detail: ""

  // 0-100, only used when showBar is true.
  property real level: 0
  property real warnAt: 101
  property real dangerAt: 101
  property bool inverted: false
  property bool forceNormal: false
  property bool showBar: true

  // A row whose headline is a word rather than a measurement renders it quieter
  // -- "wlp0s20f3" at display size would shout louder than 94% of a full disk.
  property bool valueIsText: false

  // The page this row drills into, empty when it has none. A chevron appears
  // only where it leads somewhere -- Fans and Battery have no detail page of
  // their own, and an arrow that does nothing is worse than no arrow.
  property string target: ""

  signal drillRequested(string target)

  property color foreground: Color.popups.text
  property color normalColor: Color.accent
  property color warnColor: Color.urgent
  property color dangerColor: Color.urgent
  property string fontFamily: Style.font.family

  spacing: Style.space(6)

  // The whole row is the target, not the chevron: a single glyph is a mean
  // thing to ask anyone to hit.
  HoverHandler {
    id: rowHover
    enabled: root.target !== ""
    cursorShape: Qt.PointingHandCursor
  }

  TapHandler {
    enabled: root.target !== ""
    onTapped: root.drillRequested(root.target)
  }

  Item {
    width: parent.width
    implicitHeight: Math.max(titleText.implicitHeight, valueText.implicitHeight)
    height: implicitHeight

    Text {
      id: titleText
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.baseline: valueText.baseline
      text: root.title
      color: Color.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.subtitle
      font.bold: true
      elide: Text.ElideRight
      width: Math.min(implicitWidth, parent.width - valueText.width - Style.space(8))
    }

    Text {
      id: chevron
      textFormat: Text.PlainText
      visible: root.target !== ""
      anchors.right: parent.right
      anchors.baseline: valueText.baseline
      text: "›"
      color: rowHover.hovered ? Color.accent : root.foreground
      opacity: rowHover.hovered ? 1 : 0.35
      font.family: root.fontFamily
      font.pixelSize: Style.font.heading
      font.bold: true
    }

    Text {
      id: valueText
      textFormat: Text.PlainText
      anchors.right: root.target !== "" ? chevron.left : parent.right
      anchors.rightMargin: root.target !== "" ? Style.space(8) : 0
      anchors.top: parent.top
      text: root.value
      color: root.foreground
      opacity: root.valueIsText ? 0.6 : 1
      font.family: root.fontFamily
      font.pixelSize: root.valueIsText ? Style.font.bodySmall : Style.font.display
      font.bold: !root.valueIsText
    }
  }

  Text {
    textFormat: Text.PlainText
    width: parent.width
    visible: root.subtitle.length > 0
    text: root.subtitle
    color: root.foreground
    opacity: 0.45
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }

  LevelBar {
    width: parent.width
    visible: root.showBar
    value: root.level
    warnAt: root.warnAt
    dangerAt: root.dangerAt
    inverted: root.inverted
    forceNormal: root.forceNormal
    foreground: root.foreground
    normalColor: root.normalColor
    warnColor: root.warnColor
    dangerColor: root.dangerColor
  }

  Text {
    textFormat: Text.PlainText
    width: parent.width
    visible: root.detail.length > 0
    text: root.detail
    color: root.foreground
    opacity: 0.6
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
  }
}
