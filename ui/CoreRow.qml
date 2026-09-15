// One physical core: how hard it is working and how hot that is making it.
//
// Physical, not logical. The sampler measures threads, but a temperature sensor
// belongs to a core -- two hyperthreads report one temperature between them --
// so a per-thread row would have to print the same degrees twice and imply a
// precision the hardware does not have.
//
// Each bar is labelled inline rather than by colour, because colour here is
// already spoken for: it carries severity, and a bar that is red because it is
// hot must not be confused with a bar that is red because it is busy.

import QtQuick
import qs.Commons

Column {
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

  readonly property bool hasTemperature: root.temperature >= 0

  spacing: Style.space(4)

  Text {
    textFormat: Text.PlainText
    text: root.title
    color: root.foreground
    opacity: 0.75
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Repeater {
    model: [
      {
        label: "Load",
        // A core at 100% is doing its job, not failing -- so the thresholds sit
        // higher than they would for a resource you can run out of.
        value: root.usage,
        text: Math.round(root.usage) + "%",
        warnAt: 80,
        dangerAt: 95,
        show: true
      },
      {
        label: "Temp",
        // Scaled against the sensor's own limit where the hardware reports one,
        // so the bar means "how close to throttling" rather than "how close to
        // an arbitrary round number".
        value: root.hasTemperature ? root.temperature / Math.max(1, root.temperatureCeiling) * 100 : 0,
        text: root.temperatureText,
        warnAt: 80,
        dangerAt: 92,
        show: root.hasTemperature
      }
    ]

    delegate: Item {
      id: line
      required property var modelData
      width: root.width
      visible: line.modelData.show
      height: visible ? Math.max(label.implicitHeight, bar.height, value.implicitHeight) : 0

      Text {
        id: label
        textFormat: Text.PlainText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: line.modelData.label
        color: root.foreground
        opacity: 0.45
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        id: value
        textFormat: Text.PlainText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: line.modelData.text
        color: root.foreground
        opacity: 0.8
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      LevelBar {
        id: bar
        anchors.left: label.right
        anchors.right: value.left
        anchors.leftMargin: Style.space(6)
        anchors.rightMargin: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        value: line.modelData.value
        warnAt: line.modelData.warnAt
        dangerAt: line.modelData.dangerAt
        foreground: root.foreground
        normalColor: root.normalColor
        warnColor: root.warnColor
        dangerColor: root.dangerColor
      }
    }
  }
}
