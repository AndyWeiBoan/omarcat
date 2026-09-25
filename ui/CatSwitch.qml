import QtQuick
import qs.Commons
import "../Model.js" as Model

// A macOS switch: when it is on, the TRACK is the accent and the knob is white.
//
// Omarchy's shared ToggleSwitch has it the other way round -- the track stays a
// faint tint and the knob takes the accent -- so on a light theme an enabled
// switch read as a dark pill with a white dot, which says nothing about being
// on. Filled track, light knob is the convention everywhere: macOS, iOS, GNOME,
// Android.
//
// Drawn here rather than fixed in `qs.Ui.ToggleSwitch`, which is an upstream
// file every other panel shares; this plugin is the only place that wants the
// macOS shape, and a shared file should not change behaviour underneath the
// themes that were drawn against it.
Item {
  id: root

  property bool checked: false
  property bool interactive: true
  property color foreground: Color.popups.text
  property color accent: Color.accent

  property int trackHeight: Style.space(18)
  property int trackWidth: Math.round(trackHeight * 1.72)
  property int knobInset: Math.max(1, Math.round(trackHeight * 0.1))
  readonly property int knobSize: trackHeight - knobInset * 2

  signal toggled()

  implicitWidth: trackWidth
  implicitHeight: trackHeight

  Rectangle {
    id: track
    anchors.fill: parent
    radius: height / 2
    // Off is a neutral groove, not a tinted one: the only colour on the control
    // should be the colour that means "on".
    color: root.checked ? root.accent : Util.alpha(root.foreground, 0.18)

    Behavior on color { ColorAnimation { duration: 140 } }

    Rectangle {
      width: root.knobSize
      height: root.knobSize
      radius: height / 2
      x: root.checked ? track.width - width - root.knobInset : root.knobInset
      anchors.verticalCenter: parent.verticalCenter
      color: "white"
      // The knob's own shadow, the way macOS lifts it off the track. One ring
      // rather than a blur: at this size that is all that is visible anyway.
      border.width: 1
      border.color: Qt.rgba(0, 0, 0, 0.06)

      Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.interactive
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled()
  }
}
