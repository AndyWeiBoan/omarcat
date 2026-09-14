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

Item {
  id: root

  property string title: ""
  // Home shows the plugin's name and no way back; every other page shows where
  // it is and how to leave.
  property bool canGoBack: false
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family

  signal backRequested()
  signal settingsRequested()

  implicitHeight: Math.max(titleText.implicitHeight, gear.implicitHeight, Style.space(22))

  Text {
    id: backChevron
    textFormat: Text.PlainText
    visible: root.canGoBack
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    text: "‹"
    color: backArea.containsMouse ? Color.accent : root.foreground
    opacity: 0.9
    font.family: root.fontFamily
    font.pixelSize: Style.font.heading
    font.bold: true
  }

  Text {
    id: titleText
    textFormat: Text.PlainText
    anchors.left: root.canGoBack ? backChevron.right : parent.left
    anchors.leftMargin: root.canGoBack ? Style.space(8) : 0
    anchors.right: gear.left
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    text: root.title
    color: root.canGoBack && backArea.containsMouse ? Color.accent : Color.accent
    font.family: root.fontFamily
    font.pixelSize: Style.font.subtitle
    font.bold: true
    elide: Text.ElideRight
  }

  // The chevron and the title are one target: a two-character arrow is a mean
  // thing to ask anyone to hit.
  MouseArea {
    id: backArea
    visible: root.canGoBack
    anchors.left: parent.left
    anchors.right: gear.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.backRequested()
  }

  // A labelled button, not a bare cog. An icon alone is a guess -- this one is
  // the only way into settings now that the tab strip is gone, so it says what
  // it is.
  Button {
    id: gear
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    // The Nerd Font cog, the same glyph Omarchy uses for settings elsewhere --
    // not the "⚙" emoji, which the font stack renders in colour and which
    // therefore looks nothing like the rest of the panel.
    //
    // Deliberately drawn with the font ALIAS rather than a resolved family:
    // this machine's monospace is Comic Code, which has no such glyph, and it
    // is fontconfig's per-glyph fallback that finds JetBrainsMono Nerd Font.
    // Binding to the concrete family would produce tofu.
    iconText: "󰒓"
    text: "Settings"
    bordered: true
    foreground: root.foreground
    fontFamily: root.fontFamily
    onClicked: root.settingsRequested()
  }
}
