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
    color: Color.accent
    opacity: backArea.containsMouse ? 1 : 0.85
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

  // A bare glyph in the accent, the way a macOS popover puts its one auxiliary
  // control in the title bar. It used to be a bordered "Settings" button, which
  // at 28pt tall was the heaviest thing on every page -- including the pages
  // whose whole job is to show a number.
  Item {
    id: gear
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: gearGlyph.implicitWidth + Style.space(8)
    height: Math.max(gearGlyph.implicitHeight, Style.space(22))

    Text {
      id: gearGlyph
      anchors.centerIn: parent
      textFormat: Text.PlainText
      // The Nerd Font cog, the same glyph Omarchy uses for settings elsewhere.
      // Drawn with the font ALIAS rather than a resolved family: this machine's
      // monospace is Comic Code, which has no such glyph, and it is fontconfig's
      // per-glyph fallback that finds JetBrainsMono Nerd Font. Binding to the
      // concrete family would produce tofu.
      text: "󰒓"
      color: Color.accent
      opacity: gearArea.containsMouse ? 1 : 0.85
      font.family: root.fontFamily
      font.pixelSize: Style.font.subtitle
    }

    MouseArea {
      id: gearArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.settingsRequested()
    }
  }

}
