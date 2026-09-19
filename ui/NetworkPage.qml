import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "../Model.js" as Model

Column {
  id: root

  property var service: null
  property var host: null
  property var settings: ({})
  property string temperatureUnit: "Celsius"
  property bool publicIpEnabled: true
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family

  function flag(key) { return Model.flag(settings, key) }
  property string copiedValue: ""

  readonly property var snap: service ? service.snapshot : ({})
  readonly property var hist: service ? service.history : Model.emptyHistory()
  readonly property color s1: service ? service.series1 : Color.accent
  readonly property color s2: service ? service.series2 : Color.accent
  readonly property color warn: service ? service.warn : Color.urgent
  readonly property color danger: service ? service.danger : Color.urgent

  readonly property var net: snap.net || ({})
  readonly property var connections: Array.isArray(net.procs) ? net.procs : []
  readonly property var ifaces: Array.isArray(net.ifaces) ? net.ifaces : []
  readonly property var primary: {
    for (var i = 0; i < ifaces.length; i++) if (ifaces[i].default) return ifaces[i]
    for (var j = 0; j < ifaces.length; j++) if (ifaces[j].up) return ifaces[j]
    return ifaces.length > 0 ? ifaces[0] : null
  }
  readonly property var shownIfaces: {
    var out = []
    for (var i = 0; i < ifaces.length; i++) if (ifaces[i].up || ifaces[i].default || ifaces[i].wireless) out.push(ifaces[i])
    return out
  }
  readonly property var upParts: Model.rateParts(net.tx)
  readonly property var downParts: Model.rateParts(net.rx)
  readonly property var addresses: {
    var out = []
    if (!primary) return out
    var v4 = Array.isArray(primary.ipv4) ? primary.ipv4 : []
    var v6 = Array.isArray(primary.ipv6) ? primary.ipv6 : []
    for (var i = 0; i < v4.length; i++) out.push(v4[i])
    for (var j = 0; j < Math.min(2, v6.length); j++) out.push(v6[j])
    return out
  }

  // Wi-Fi signal, as dBm and as a share of a usable range.
  //
  // Unlike fan RPM this one HAS a meaningful scale, which is why it gets a bar:
  // about -30 dBm is as good as it gets, -67 is the usual floor for streaming,
  // and below -80 the link is not worth having. Mapping -90..-30 onto 0..100
  // makes the bar mean "how much usable signal is left".
  readonly property real signalDbm: root.primary && root.primary.wireless
      && root.primary.dbm !== null && root.primary.dbm !== undefined
      && isFinite(Number(root.primary.dbm))
    ? Number(root.primary.dbm) : NaN
  readonly property bool hasSignal: isFinite(root.signalDbm)
  readonly property real signalPercent:
      Math.max(0, Math.min(100, (root.signalDbm + 90) / 60 * 100))

  readonly property string signalQuality: {
    if (!root.hasSignal) return "";
    if (root.signalDbm >= -50) return "excellent";
    if (root.signalDbm >= -60) return "good";
    if (root.signalDbm >= -67) return "fair";
    if (root.signalDbm >= -80) return "weak";
    return "unusable";
  }

  // Band, channel and link rate on one line. A bare "72 Mbps" says nothing --
  // paired with "2.4 GHz" it says the radio is on the slow band, which is the
  // most actionable thing this page can tell anyone.
  readonly property string radioDetail: {
    if (!root.primary || !root.primary.wireless)
      return "";
    const parts = [];
    const freq = Number(root.primary.freq);
    if (isFinite(freq) && freq > 0) {
      parts.push(freq >= 5900 ? "6 GHz" : freq >= 4900 ? "5 GHz" : "2.4 GHz");
      const channel = root.channelOf(freq);
      if (channel > 0)
        parts.push("ch " + channel);
    }
    const rate = Number(root.primary.bitrate);
    if (isFinite(rate) && rate > 0)
      parts.push(Math.round(rate) + " Mbps");
    return parts.join("  ·  ");
  }

  // Standard channel numbering, so the figure matches what a router's settings
  // page calls it.
  function channelOf(mhz) {
    if (mhz >= 2412 && mhz <= 2484)
      return mhz === 2484 ? 14 : Math.round((mhz - 2407) / 5);
    if (mhz >= 5000 && mhz < 5900)
      return Math.round((mhz - 5000) / 5);
    if (mhz >= 5900)
      return Math.round((mhz - 5950) / 5);
    return 0;
  }

  readonly property real wifiTemp: {
    const temps = (snap.sensors && snap.sensors.temps) || [];
    for (let i = 0; i < temps.length; i++)
      if (String(temps[i].chip || "") === "Wi-Fi")
        return Model.num(temps[i].value, -1);
    return -1;
  }

  // Interfaces that are not the one carrying traffic: listed, but as one quiet
  // line each rather than a card apiece.
  readonly property var otherIfaces: {
    const out = [];
    for (let i = 0; i < root.ifaces.length; i++)
      if (root.ifaces[i] !== root.primary)
        out.push(root.ifaces[i]);
    return out;
  }

  function copy(text) {
    if (!text) return
    Quickshell.execDetached(["/usr/bin/wl-copy", "--", String(text)])
    copiedValue = text
    copiedTimer.restart()
  }

  Timer {
    id: copiedTimer
    interval: 1400
    onTriggered: root.copiedValue = ""
  }

  function lookupPublicIp() {
    if (service && publicIpEnabled) service.requestPublicIp(false)
  }

  Component.onCompleted: lookupPublicIp()
  onServiceChanged: lookupPublicIp()
  onPublicIpEnabledChanged: lookupPublicIp()

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(10)

  Card {
    foreground: root.foreground

    CardHeader {
      title: root.primary ? String(root.primary.name || "Network") : "Network"
      detail: root.wifiTemp >= 0 ? Model.tempText(root.wifiTemp, root.temperatureUnit) : ""
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Row {
      width: parent.width

      BigStat {
        width: parent.width / 2
        value: root.upParts.value
        unit: root.upParts.unit
        label: "Upload"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      BigStat {
        width: parent.width / 2
        value: root.downParts.value
        unit: root.downParts.unit
        label: "Download"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }
    }

    MirrorGraph {
      id: graph
      width: parent.width
      height: Style.space(72)
      up: root.hist.netTx || []
      down: root.hist.netRx || []
      upColor: root.s2
      downColor: root.s1
      floor: 10240
      midlineColor: Util.alpha(root.foreground, 0.18)
    }

    Legend {
      foreground: root.foreground
      fontFamily: root.fontFamily
      items: [
        { color: root.s2, label: "Peak ↑", value: Model.rateParts(graph.peakUp).value, unit: Model.rateParts(graph.peakUp).unit },
        { color: root.s1, label: "Peak ↓", value: Model.rateParts(graph.peakDown).value, unit: Model.rateParts(graph.peakDown).unit }
      ]
    }
  }

  // Signal, with a bar -- this reading has a real scale, unlike fan RPM.
  Card {
    visible: root.hasSignal
    foreground: root.foreground
    spacing: Style.space(6)

    Item {
      width: parent.width
      implicitHeight: Math.max(signalTitle.implicitHeight, signalValue.implicitHeight)

      Text {
        id: signalTitle
        textFormat: Text.PlainText
        anchors.left: parent.left
        anchors.baseline: signalValue.baseline
        text: "Signal"
        // The name of the thing, not a link. See Model.INK -- the accent is
        // kept for the chevron, the "Show all" link and the selected segment.
        color: Util.alpha(root.foreground, Model.INK.label)
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.weight: Font.DemiBold
      }

      Text {
        id: signalValue
        textFormat: Text.PlainText
        anchors.right: parent.right
        anchors.top: parent.top
        text: Math.round(root.signalDbm) + " dBm"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.display
        font.weight: Font.Normal
      }
    }

    LevelBar {
      width: parent.width
      value: root.signalPercent
      // Inverted: here a LOW reading is the bad one. The thresholds are the
      // familiar ones -- below -67 dBm streaming starts to suffer, below -80
      // the link is not worth having.
      inverted: true
      warnAt: (-67 + 90) / 60 * 100
      dangerAt: (-80 + 90) / 60 * 100
      foreground: root.foreground
      normalColor: root.s1
      warnColor: root.warn
      dangerColor: root.danger
    }

    Text {
      textFormat: Text.PlainText
      width: parent.width
      text: root.radioDetail
          + (root.signalQuality ? "  ·  " + root.signalQuality : "")
      color: root.foreground
      opacity: 0.6
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  // Addresses. Click to copy -- the reason anybody opens this page.
  Card {
    visible: root.addresses.length > 0
    foreground: root.foreground
    spacing: Style.space(2)

    SectionTitle { text: "Addresses"; fontFamily: root.fontFamily }

    Repeater {
      model: root.addresses

      delegate: StatRow {
        required property var modelData
        width: parent.width
        label: String(modelData).indexOf(":") >= 0 ? "IPv6" : "IPv4"
        value: root.copiedValue === String(modelData) ? "copied" : String(modelData)
        foreground: root.foreground
        fontFamily: root.fontFamily

        TapHandler { onTapped: root.copy(String(modelData)) }
      }
    }

    // Public IP is an outbound request to a third party (api.ipify.org), so it
    // is off unless asked for -- see the note on the setting's default.
    StatRow {
      visible: root.publicIpEnabled
      width: parent.width
      label: "Public"
      value: root.net.publicIp
        ? (root.copiedValue === String(root.net.publicIp) ? "copied" : String(root.net.publicIp))
        : "looking up…"
      foreground: root.foreground
      fontFamily: root.fontFamily

      TapHandler { onTapped: root.copy(String(root.net.publicIp || "")) }
    }
  }

  // Counted from boot, which is what makes it useful on a metered connection:
  // the rate tells you nothing about how much of an allowance is gone.
  Card {
    visible: !!root.primary
    foreground: root.foreground
    spacing: Style.space(2)

    SectionTitle { text: "Since boot"; fontFamily: root.fontFamily }

    StatRow {
      width: parent.width
      label: "Downloaded"
      dot: root.s1
      value: Model.bytesText(Model.num(root.primary ? root.primary.rxTotal : 0))
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    StatRow {
      width: parent.width
      label: "Uploaded"
      dot: root.s2
      value: Model.bytesText(Model.num(root.primary ? root.primary.txTotal : 0))
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }

  // Everything else the machine has, one quiet line each. A down USB adapter
  // does not deserve the same billing as the link carrying your traffic.
  Card {
    visible: root.otherIfaces.length > 0
    foreground: root.foreground
    spacing: Style.space(2)

    SectionTitle { text: "Other interfaces"; fontFamily: root.fontFamily }

    Repeater {
      model: root.otherIfaces

      delegate: StatRow {
        required property var modelData
        width: parent.width
        label: String(modelData.name || "")
        value: modelData.up ? "up" : "down"
        labelOpacity: 0.55
        boldValue: false
        foreground: root.foreground
        fontFamily: root.fontFamily
      }
    }
  }

  Card {
    visible: root.flag("showProcesses")
    foreground: root.foreground

    ProcessList {
      host: root.host
      title: "Processes"
      caption: "TCP traffic per process from the kernel's socket counters. QUIC and other UDP traffic cannot be attributed without root."
      items: root.connections.slice(0, 6)
      allItems: root.connections
      total: root.connections.length
      sortKey: "net"
      columns: [
        { key: "rx", kind: "rate", title: "Down" },
        { key: "tx", kind: "rate", title: "Up" }
      ]
      columnWidth: Style.space(70)
      emptyText: net.procs === null || net.procs === undefined ? "Measuring…" : "No traffic"
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }

  // Click-to-copy line for an address.
  component AddressRow: Item {
    id: addr

    property string value: ""
    property string placeholder: "—"
    readonly property bool copied: root.copiedValue !== "" && root.copiedValue === value

    width: parent ? parent.width : implicitWidth
    height: Style.space(22)

    Rectangle {
      anchors.fill: parent
      anchors.leftMargin: -Style.space(6)
      anchors.rightMargin: -Style.space(6)
      radius: Style.cornerRadius
      color: mouse.containsMouse && addr.value !== "" ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
    }

    Text {
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.right: hint.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: addr.value !== "" ? addr.value : addr.placeholder
      color: root.foreground
      opacity: addr.value !== "" ? 0.92 : 0.45
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideMiddle
    }

    Text {
      id: hint
      textFormat: Text.PlainText
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: addr.copied ? "Copied" : "󰆏"
      visible: addr.value !== "" && (mouse.containsMouse || addr.copied)
      color: root.foreground
      opacity: addr.copied ? 0.9 : 0.5
      font.family: root.fontFamily
      font.pixelSize: addr.copied ? Style.font.caption : Style.font.icon
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: addr.value !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: root.copy(addr.value)
    }
  }
}
