import QtQuick
import qs.Commons
import "../Model.js" as Model

// Card title line: the name on the left, a quiet detail on the right
// ("CPU" ......... "4.85 GHz, 49°").
//
// The name is the panel's own text colour at label strength, not the accent.
// In macOS blue is for things you can act on; a card that titles itself in
// blue reads as a link and, when every card does it, nothing is emphasised at
// all. See Model.INK.
Item {
  id: root

  property string title: ""
  property string detail: ""
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family

  // Opt-in: park the detail immediately after the title instead of at the far
  // right edge. Worth it when the detail belongs TO the title ("CPU, and here
  // is how fast and how hot it is") rather than being a separate fact that
  // happens to share the line.
  property bool inlineDetail: false

  width: parent ? parent.width : implicitWidth
  implicitHeight: Math.max(titleText.implicitHeight, detailText.implicitHeight)
  height: implicitHeight

  Text {
    id: titleText
    textFormat: Text.PlainText
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    text: root.title
    color: Util.alpha(root.foreground, Model.INK.label)
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    font.weight: Font.DemiBold
    elide: Text.ElideRight
    width: Math.min(implicitWidth, parent.width - detailText.width - Style.space(8))
  }

  // Anchored one way or the other, never both: an Item can only honour one
  // horizontal anchor pair at a time.
  states: State {
    when: root.inlineDetail
    AnchorChanges {
      target: detailText
      anchors.right: undefined
      anchors.left: titleText.right
    }
    PropertyChanges {
      detailText.anchors.leftMargin: Style.space(8)
    }
  }

  Text {
    id: detailText
    textFormat: Text.PlainText
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    text: root.detail
    color: Util.alpha(root.foreground, Model.INK.secondary)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
