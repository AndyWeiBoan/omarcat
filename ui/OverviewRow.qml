// One subsystem on the Overview page, as a row of a grouped list rather than a
// card of its own: name, current reading, a capacity bar whose colour carries
// the judgement, and one quiet line of detail.
//
// **Five cards became one group with five rows.** Five separate surfaces, each
// titling itself in blue and setting its number at display size, gave the eye
// no order to read them in -- everything was emphasised, so nothing was. In a
// grouped list the surface is the page, the names run down the left at one
// weight, and the readings line up down the right where they can be compared.
// That is how macOS lays out a list of facts, and it is the whole of the
// hierarchy here.
//
// The number is still the largest thing on the row, but by one step rather than
// three: heading against body, both regular weight. Emphasis comes from size
// and alignment, not from weight and hue.

import QtQuick
import qs.Commons
import "../Model.js" as Model

Item {
  id: root

  property string title: ""
  // The rounded-square badge macOS System Settings puts at the head of a row:
  // a filled squircle with a white symbol in it. It is what lets the column be
  // scanned without reading -- the eye finds "the green one" long before it
  // finds the word "Battery". See Model.ROW_BADGE.
  property string icon: ""
  // Fill and glyph, not "tint and white". A solid saturated square with a white
  // symbol is System Settings' idiom, and it stops working the moment the
  // colour goes: solid grey behind white is what System Settings uses for a row
  // that is DISABLED.
  //
  // This is the Control Center's off-state badge instead, which is already
  // measured and already in this design language: a well at black 0.11 over the
  // card with the symbol in labelColor, black 0.847. Same treatment, same two
  // numbers, so the two panels read as one system. Written against the
  // foreground rather than as literal black so a dark theme gets the same
  // relationship the other way up.
  property color iconFill: Util.alpha(foreground, 0.11)
  property color iconInk: Util.alpha(foreground, Model.INK.label)
  // The badge may be drawn from a different family than the row's text -- SF
  // Symbols live in SF Pro Display, the fallback glyphs in a Nerd Font.
  property string iconFont: ""
  // The hardware this row is about -- the CPU part, the disk, the wifi chip.
  // Quiet and directly under the title, because it answers "which one is this"
  // and never changes; the number beside it is the thing being watched.
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
  // -- "wlp0s20f3" at heading size would shout louder than 94% of a full disk.
  property bool valueIsText: false

  // The page this row drills into, empty when it has none. A chevron appears
  // only where it leads somewhere -- Fans has no page of its own, and an arrow
  // that does nothing is worse than no arrow.
  property string target: ""

  // Every row but the first draws the hairline above it. The first row of the
  // group is always CPU, which is always present, so "first" needs no runtime
  // test -- a hidden row simply draws nothing, and the next visible one still
  // has its separator.
  property bool showSeparator: true

  signal drillRequested(string target)

  property color foreground: Color.popups.text
  property color normalColor: Color.accent
  property color warnColor: Color.urgent
  property color dangerColor: Color.urgent
  property string fontFamily: Style.font.family

  readonly property real hInset: Style.space(12)
  readonly property real vPad: Style.space(10)
  readonly property real badgeSize: Style.space(22)
  // Everything on the row lines up past the badge, the way an indented list
  // does -- including the bar, so the bars start on one edge down the column.
  readonly property real contentInset: icon === "" ? hInset : hInset + badgeSize + Style.space(10)

  width: parent ? parent.width : implicitWidth
  implicitHeight: body.implicitHeight + vPad * 2
  height: implicitHeight

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

  // Hover lights the row, the way a list row lights in macOS -- not the
  // chevron alone, which would say the chevron is the target.
  Rectangle {
    anchors.fill: parent
    color: Util.alpha(root.foreground, 0.05)
    opacity: rowHover.hovered ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 110 } }
  }

  Hairline {
    visible: root.showSeparator
    foreground: root.foreground
    // Inset to where the text starts, not to the badge: Apple's rule, and the
    // reason a grouped list reads as one object rather than a stack of slabs.
    inset: root.contentInset
  }

  // The badge sits against the row's own top padding rather than centred on the
  // whole row: a row with a two-line detail is tall, and a badge floating in
  // the middle of it stops lining up with the title it belongs to.
  Rectangle {
    id: badge
    visible: root.icon !== ""
    x: root.hInset
    y: root.vPad
    width: root.badgeSize
    height: root.badgeSize
    // macOS draws these as squircles; a plain radius at this size is within a
    // pixel of one, and Qt has no squircle.
    radius: Math.round(root.badgeSize * 0.26)
    color: root.iconFill

    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: root.icon
      color: root.iconInk
      font.family: root.iconFont !== "" ? root.iconFont : root.fontFamily
      font.pixelSize: Math.round(root.badgeSize * 0.62)
    }
  }

  Column {
    id: body
    x: root.contentInset
    y: root.vPad
    width: root.width - root.contentInset - root.hInset
    spacing: Style.space(5)

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
        color: Util.alpha(root.foreground, Model.INK.label)
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.weight: Font.DemiBold
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
        color: Color.accent
        opacity: rowHover.hovered ? 1 : 0.55
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
      }

      Text {
        id: valueText
        textFormat: Text.PlainText
        anchors.right: root.target !== "" ? chevron.left : parent.right
        anchors.rightMargin: root.target !== "" ? Style.space(8) : 0
        anchors.top: parent.top
        text: root.value
        color: Util.alpha(root.foreground,
                          root.valueIsText ? Model.INK.secondary : Model.INK.label)
        font.family: root.fontFamily
        font.pixelSize: root.valueIsText ? Style.font.body : Style.font.heading
      }
    }

    Text {
      textFormat: Text.PlainText
      width: parent.width
      visible: root.subtitle.length > 0
      // The part number is identity, not news: it never changes, so it sits
      // below the live line in the ink order even though it sits above it on
      // the row.
      text: root.subtitle
      color: Util.alpha(root.foreground, Model.INK.tertiary)
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
      color: Util.alpha(root.foreground, Model.INK.secondary)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }
}
