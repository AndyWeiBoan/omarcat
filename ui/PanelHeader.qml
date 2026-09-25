// The panel's one navigation control: where you are, how to go back, and the
// way into settings.
//
// It replaces a row of tabs, and the reason is width. The panel's minimum width
// was the width of the tab strip spelled out -- six page names side by side --
// which made every page as wide as the longest list of names rather than as
// wide as its own content. Overview is the home screen now; the other pages are
// reached by drilling into the row they belong to.

import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

Item {
  id: root

  property string title: ""
  // The part, under the page's name. Identity, not state: a CPU does not
  // become a different part while you watch it, so it belongs on the page you
  // opened deliberately rather than on the pane you glance at. This is where
  // macOS keeps it too -- About This Mac, not Control Center.
  property string subtitle: ""
  // Home shows the plugin's name and no way back; every other page shows where
  // it is and how to leave.
  property bool canGoBack: false
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family

  signal backRequested()
  signal settingsRequested()

  implicitHeight: Math.max(titleBlock.implicitHeight, Style.space(22))

  Text {
    id: backChevron
    textFormat: Text.PlainText
    visible: root.canGoBack
    anchors.left: parent.left
    // On the title's line, not on the block's middle: with a subtitle under it
    // a centred chevron drifts into the gap between the two and stops reading
    // as the control for either.
    anchors.verticalCenter: titleBlock.verticalCenter
    anchors.verticalCenterOffset: -Math.round(subtitleText.height / 2)
    text: "‹"
    color: Color.accent
    opacity: backArea.containsMouse ? 1 : 0.85
    font.family: root.fontFamily
    font.pixelSize: Style.font.heading
    font.bold: true
  }

  Column {
    id: titleBlock
    anchors.left: root.canGoBack ? backChevron.right : parent.left
    anchors.leftMargin: root.canGoBack ? Style.space(8) : 0
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0

    Text {
      id: titleText
      textFormat: Text.PlainText
      width: parent.width
      // The title is where you are, not something to click. Only the chevron
      // beside it is blue, and only because it is the control.
      text: root.title
      color: root.canGoBack && backArea.containsMouse
        ? Color.accent
        : Util.alpha(root.foreground, Model.INK.label)
      font.family: root.fontFamily
      font.pixelSize: Style.font.subtitle
      font.weight: Font.DemiBold
      elide: Text.ElideRight
    }

    // Zero-height when there is nothing to say -- most machines resolve some
    // of these and not others, and a missing part number must not shift the
    // page under it.
    Text {
      id: subtitleText
      textFormat: Text.PlainText
      visible: root.subtitle !== ""
      height: visible ? implicitHeight : 0
      width: parent.width
      text: root.subtitle
      color: Util.alpha(root.foreground, Model.INK.secondary)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  // The chevron and the title are one target: a two-character arrow is a mean
  // thing to ask anyone to hit.
  MouseArea {
    id: backArea
    visible: root.canGoBack
    anchors.left: parent.left
    anchors.right: titleBlock.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.backRequested()
  }

  // **No settings control up here.** A gear in the corner of a popover is not
  // a macOS pattern -- it is a Windows and GNOME one. Where macOS has to hand
  // you off to a settings screen it puts a row at the BOTTOM of the list and
  // spells it out: Control Center's Wi-Fi pane ends with "Wi-Fi Settings...",
  // not with an icon you have to guess at.
  //
  // So the way in is the last row of the Overview list. `settingsRequested`
  // stays for callers that still connect to it; nothing here emits it now.
}
