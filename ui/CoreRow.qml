// One physical core, on one line: how hard it is working, and how hot that is
// making it.
//
// Physical, not logical. The sampler measures threads, but a temperature sensor
// belongs to a core -- two hyperthreads report one temperature between them --
// so a per-thread row would have to print the same degrees twice and imply a
// precision the hardware does not have.
//
// **One line, not two.** It used to set the core's name on its own line and
// then a labelled bar underneath, so eight cores read as sixteen rows and the
// word "Load" was repeated eight times to say what the whole group already
// said. On a machine with no per-core sensor -- which is most of them -- that
// label was the only thing the second line carried.
//
// The temperature rides as a suffix after the percentage rather than as a
// second bar. Colour here is already spoken for: it carries severity, and a bar
// that is red because it is hot must not be confused with one that is red
// because it is busy.

import QtQuick
import qs.Commons
import "../Model.js" as Model

Item {
  id: root

  property string title: ""

  property real usage: 0            // 0-100
  property real temperature: -1     // °C, negative when unavailable
  property real temperatureCeiling: 100
  property string temperatureText: ""

  property color foreground: Color.popups.text
  property color normalColor: Color.accent
  property color warnColor: Color.urgent
  property color dangerColor: Color.urgent
  property string fontFamily: Style.font.family

  // Every row but the first draws the hairline above it.
  property bool showSeparator: true

  readonly property bool hasTemperature: root.temperature >= 0
  readonly property real hInset: Style.space(12)

  width: parent ? parent.width : implicitWidth
  implicitHeight: Style.space(26)
  height: implicitHeight

  Hairline {
    visible: root.showSeparator
    foreground: root.foreground
    inset: root.hInset
  }

  Text {
    id: label
    textFormat: Text.PlainText
    anchors.left: parent.left
    anchors.leftMargin: root.hInset
    anchors.verticalCenter: parent.verticalCenter
    text: root.title
    color: Util.alpha(root.foreground, Model.INK.label)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
    width: Math.min(implicitWidth, root.width * 0.34)
  }

  Text {
    id: temp
    textFormat: Text.PlainText
    visible: root.hasTemperature && root.temperatureText !== ""
    anchors.right: parent.right
    anchors.rightMargin: root.hInset
    anchors.verticalCenter: parent.verticalCenter
    text: root.temperatureText
    color: Util.alpha(root.foreground, Model.INK.tertiary)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Text {
    id: value
    textFormat: Text.PlainText
    anchors.right: temp.visible ? temp.left : parent.right
    anchors.rightMargin: temp.visible ? Style.space(8) : root.hInset
    anchors.verticalCenter: parent.verticalCenter
    // A fixed slot so eight percentages line up on their right edge instead of
    // stepping in and out with the width of "9%" against "100%".
    horizontalAlignment: Text.AlignRight
    width: metrics.advanceWidth
    text: Math.round(root.usage) + "%"
    color: Util.alpha(root.foreground, Model.INK.secondary)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  TextMetrics {
    id: metrics
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    text: "100%"
  }

  LevelBar {
    anchors.left: label.right
    anchors.right: value.left
    anchors.leftMargin: Style.space(10)
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    // A core at 100% is doing its job, not failing -- so the thresholds sit
    // higher than they would for a resource you can run out of.
    value: root.usage
    warnAt: 80
    dangerAt: 95
    foreground: root.foreground
    normalColor: root.normalColor
    warnColor: root.warnColor
    dangerColor: root.dangerColor
  }
}
