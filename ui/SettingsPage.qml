import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// In-panel configuration. Deliberately short.
//
// The upstream project's settings page was 559 lines, and most of it configured
// the row of CPU/MEM/NET readouts it drew in the bar -- which module, in what
// order, as a graph or a ring or a figure, how wide, labelled with letters or
// glyphs. omarcat draws a cat there instead, so all of that went, and with it
// the per-page "hide this section" toggles: a card that has nothing to show
// already hides itself, which is better than asking somebody to decide.
//
// What is left is what a person might actually want to change. Every change is
// written straight to this widget's entry in shell.json through the host.
Column {
  id: root

  property var service: null
  property var host: null
  property var settings: ({})
  property string temperatureUnit: "Celsius"
  property bool publicIpEnabled: false
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family

  function set(key, value) {
    if (host && typeof host.persist === "function") host.persist(key, value)
  }

  function num(key) {
    return Model.num(Model.settingValue(settings, key), Model.SETTINGS[key])
  }

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(10)

  Card {
    foreground: root.foreground
    spacing: Style.space(6)

    ChoiceRow {
      label: "Runner"
      options: [{ value: "cat", label: "Cat" }, { value: "catalpha", label: "Cat α" },
                { value: "dog", label: "Dog" },
                { value: "dancer", label: "Dancer" },
                { value: "sway", label: "Sway" }]
      value: String(Model.settingValue(root.settings, "runner") || Model.SETTINGS.runner)
      onChanged: function(value) { root.set("runner", value) }
    }

    PanelSeparator { foreground: root.foreground }

    ChoiceRow {
      label: "Temperature"
      options: [{ value: "Celsius", label: "°C" }, { value: "Fahrenheit", label: "°F" }]
      value: String(Model.settingValue(root.settings, "temperatureUnit"))
      onChanged: function(value) { root.set("temperatureUnit", value) }
    }

    PanelSeparator { foreground: root.foreground }

    StepperRow {
      label: "Refresh every"
      value: root.num("refreshSeconds")
      unit: "s"
      stops: Model.REFRESH_STOPS
      onChanged: function(value) { root.set("refreshSeconds", value) }
    }

    StepperRow {
      label: "History"
      value: root.num("historySeconds")
      unit: "s"
      minimum: 30
      maximum: 3600
      step: 30
      onChanged: function(value) { root.set("historySeconds", value) }
    }

    PanelSeparator { foreground: root.foreground }

    FlagRow {
      label: "Top processes on every page"
      checked: Model.flag(root.settings, "showProcesses")
      onToggled: root.set("showProcesses", !checked)
    }

    FlagRow {
      label: "Look up public IP address"
      checked: Model.flag(root.settings, "publicIp")
      onToggled: root.set("publicIp", !checked)
    }

    // Spelled out rather than left to the label: this is the one setting on
    // this page that sends anything off the machine, and somebody turning it on
    // should know who they are telling.
    Text {
      textFormat: Text.PlainText
      width: parent.width
      text: "Asks api.ipify.org, which then knows this machine's address."
      color: root.foreground
      opacity: 0.45
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Item {
      width: parent.width
      height: resetButton.implicitHeight + Style.space(4)

      Button {
        id: resetButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "Reset to defaults"
        bordered: true
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: if (root.host && typeof root.host.resetSettings === "function") root.host.resetSettings()
      }
    }
  }

  component FlagRow: Item {
    id: flagRow

    property string label: ""
    property bool bold: false
    property bool checked: false
    property real indent: 0

    signal toggled()

    width: parent ? parent.width : implicitWidth
    height: Style.space(26)

    Text {
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.leftMargin: flagRow.indent
      anchors.right: flagSwitch.left
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      text: flagRow.label
      color: root.foreground
      opacity: flagRow.checked ? 0.9 : 0.6
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: flagRow.bold
      elide: Text.ElideRight
    }

    ToggleSwitch {
      id: flagSwitch
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      checked: flagRow.checked
      trackHeight: Style.space(18)
      foreground: root.foreground
      onToggled: flagRow.toggled()
    }

    MouseArea {
      anchors.fill: parent
      anchors.rightMargin: flagSwitch.width + Style.space(10)
      cursorShape: Qt.PointingHandCursor
      onClicked: flagRow.toggled()
    }
  }

  // Label on the left, a chip group on the right.
  component ChoiceRow: Item {
    id: choiceRow

    property string label: ""
    property var options: []
    property string value: ""
    property real indent: 0

    signal changed(string value)

    width: parent ? parent.width : implicitWidth
    height: Math.max(Style.space(30), chips.implicitHeight + Style.space(4))

    Text {
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.leftMargin: choiceRow.indent
      anchors.right: chips.left
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      text: choiceRow.label
      color: root.foreground
      opacity: 0.9
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }

    ButtonGroup {
      id: chips
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      options: choiceRow.options
      value: choiceRow.value
      foreground: root.foreground
      background: Color.popups.background
      fontFamily: root.fontFamily
      fontSize: Style.font.caption
      focusable: false
      onChanged: function(value) { choiceRow.changed(value) }
    }
  }

  // Label on the left, "− value unit +" on the right.
  component StepperRow: Item {
    id: stepper

    property string label: ""
    property real value: 0
    property string unit: ""
    property real minimum: 0
    property real maximum: 100
    property real step: 1
    // When set, the value walks these stops instead of min/max/step.
    property var stops: []

    readonly property bool stepped: Array.isArray(stops) && stops.length > 0
    readonly property int stopIndex: stepped ? Model.nearestStopIndex(value) : -1
    readonly property bool canDecrease: stepped ? stopIndex > 0 : value > minimum
    readonly property bool canIncrease: stepped ? stopIndex < stops.length - 1 : value < maximum
    readonly property string valueText: stepped ? Model.intervalText(value) : String(Math.round(value))

    signal changed(real value)

    function nudge(direction) {
      if (stepped) {
        var idx = Math.max(0, Math.min(stops.length - 1, stopIndex + direction))
        if (stops[idx] !== value) changed(stops[idx])
        return
      }
      var next = Math.max(minimum, Math.min(maximum, value + direction * step))
      if (next !== value) changed(next)
    }

    width: parent ? parent.width : implicitWidth
    height: Style.space(26)

    Text {
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.right: controls.left
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      text: stepper.label
      color: root.foreground
      opacity: 0.9
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }

    Row {
      id: controls
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(4)

      PanelActionButton {
        iconText: "󰍴"
        enabled: stepper.canDecrease
        foreground: root.foreground
        fontFamily: root.fontFamily
        size: Style.space(22)
        onClicked: stepper.nudge(-1)
      }

      Item {
        width: Style.space(84)
        height: Style.space(22)

        Measure {
          anchors.centerIn: parent
          value: stepper.valueText
          unit: stepper.unit
          foreground: root.foreground
          fontFamily: root.fontFamily
        }
      }

      PanelActionButton {
        iconText: "󰐕"
        enabled: stepper.canIncrease
        foreground: root.foreground
        fontFamily: root.fontFamily
        size: Style.space(22)
        onClicked: stepper.nudge(1)
      }
    }
  }
}
