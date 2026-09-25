import QtQuick
import qs.Commons
import "../Model.js" as Model

// A macOS segmented control: one grey track with a light capsule sitting on the
// chosen segment.
//
// **The selected segment is not blue.** Blue in macOS means a thing that is on
// or a thing you can follow -- a switch, a checkbox, a link. A segmented
// control is a choice among peers, and since Big Sur it marks the choice by
// RAISING it: the capsule is near-white and reads as sitting above the track,
// the way the Finder's view switcher or a System Settings segmented control
// does. Colour is not doing any work there, elevation is.
//
// Local to this plugin rather than a change to qs.Ui.ButtonGroup, which every
// other panel shares and which was drawn against the themes as they are.
Item {
  id: root

  property var options: []
  property string value: ""
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family

  signal changed(string value)

  readonly property int count: Array.isArray(options) ? options.length : 0

  // `options` is either a plain string[] (label == value) or an array of
  // { value, label } objects -- the same shape qs.Ui.ButtonGroup takes, so the
  // callers did not have to change.
  function optionValue(o) { return (o && typeof o === "object") ? String(o.value) : String(o) }
  function optionLabel(o) {
    return (o && typeof o === "object" && o.label !== undefined) ? String(o.label) : String(o)
  }
  readonly property real pad: Style.space(10)
  readonly property real gap: Style.space(2)
  // Every segment the width of the widest label, so the capsule is the same
  // size wherever it lands and nothing shifts when the choice changes.
  readonly property real cell: Math.ceil(widest.advanceWidth) + pad * 2

  implicitWidth: cell * count + gap * 2
  implicitHeight: Style.space(24)

  TextMetrics {
    id: widest
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    text: {
      var best = ""
      for (var i = 0; i < root.count; i++) {
        var t = root.optionLabel(root.options[i])
        if (t.length > best.length) best = t
      }
      return best
    }
  }

  readonly property int index: {
    for (var i = 0; i < root.count; i++)
      if (root.optionValue(root.options[i]) === root.value) return i
    return -1
  }

  Rectangle {
    id: track
    anchors.fill: parent
    radius: Style.space(7)
    color: Util.alpha(root.foreground, 0.07)
  }

  Rectangle {
    id: capsule
    visible: root.index >= 0
    width: root.cell
    height: parent.height - root.gap * 2
    x: root.gap + root.index * root.cell
    y: root.gap
    radius: Style.space(6)
    // Near-white rather than white: on a light theme a pure white capsule on a
    // light grey track is almost invisible, and macOS's own is slightly warm of
    // the surface it sits on rather than brighter than everything.
    color: Util.alpha(root.foreground, 0.02)
    border.width: 1
    border.color: Util.alpha(root.foreground, 0.10)

    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  }

  Repeater {
    model: root.count

    delegate: Item {
      required property int index
      readonly property var option: root.options[index]
      readonly property string optionValue: root.optionValue(option)
      readonly property string optionLabel: root.optionLabel(option)
      readonly property bool selected: root.value === optionValue

      x: root.gap + index * root.cell
      y: root.gap
      width: root.cell
      height: root.height - root.gap * 2

      Text {
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: parent.optionLabel
        color: Util.alpha(root.foreground,
                          parent.selected ? Model.INK.label : Model.INK.secondary)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.weight: parent.selected ? Font.DemiBold : Font.Normal
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.changed(parent.optionValue)
      }
    }
  }
}
