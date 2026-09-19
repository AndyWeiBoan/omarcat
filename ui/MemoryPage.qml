import QtQuick
import qs.Commons
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

  readonly property var snap: service ? service.snapshot : ({})
  readonly property var hist: service ? service.history : Model.emptyHistory()
  readonly property color s1: service ? service.series1 : Color.accent
  readonly property color s2: service ? service.series2 : Color.accent
  readonly property color s3: service ? service.tertiary : Color.accent
  readonly property color warn: service ? service.warn : Color.urgent
  readonly property color danger: service ? service.danger : Color.urgent
  readonly property color track: Util.alpha(foreground, 0.16)

  readonly property var mem: snap.mem || ({})
  readonly property var procs: snap.procs || null
  readonly property real total: Math.max(1, Model.num(mem.total, 1))
  readonly property real pressure: Math.max(Model.num(mem.pressureSome), Model.num(mem.pressureFull))
  readonly property bool hasCompression: Model.num(mem.compressed) >= 1048576
  readonly property bool hasSwap: Model.num(mem.swapTotal) > 0
  readonly property real swapTotal: Model.num(mem.swapTotal)
  readonly property real swapUsed: Model.num(mem.swapUsed)
  readonly property real cached: Model.num(mem.cached)

  // Linux's `used` excludes reclaimable cache, so it reads far lower than the
  // memory actually spoken for and invites "plenty left" on a machine that has
  // none. `available` is the kernel's own estimate of what a new allocation
  // could get, so this is the honest headline.
  readonly property real committedPercent: (total - Model.num(root.mem.available)) / total * 100

  readonly property var breakdown: {
    const out = [
      { label: "Apps",   color: root.s1, bytes: Model.num(root.mem.apps) },
      { label: "Cached", color: root.s2, bytes: Model.num(root.mem.cached) },
      { label: "Shared", color: root.s3, bytes: Model.num(root.mem.shared) },
      { label: "Free",   color: root.track, bytes: Model.num(root.mem.free) }
    ];
    // zram reports a few kilobytes even when nothing is compressed; showing
    // "4 KB" implies a feature is doing work when it is idle.
    if (root.hasCompression)
      out.splice(3, 0, { label: "Compressed", color: root.warn, bytes: Model.num(root.mem.compressed) });
    for (let i = 0; i < out.length; i++)
      out[i].text = Model.bytesText(out[i].bytes);
    // Pressure only when there IS pressure. It reads 0 almost always, and a
    // permanent zero teaches people to ignore the one number on this page that
    // actually says whether memory is hurting them.
    if (root.pressure >= 0.5)
      out.push({ label: "Pressure", color: root.danger, bytes: 0,
                 text: Math.round(root.pressure) + "%" });
    return out;
  }


  width: parent ? parent.width : implicitWidth
  spacing: Style.space(10)

  // One card: how much is spoken for, what it is spoken for by, and how that
  // has moved. The composition bar doubles as the progress bar -- a plain
  // single-colour bar above a three-colour one said the same thing twice.
  Card {
    foreground: root.foreground
    spacing: Style.space(10)

    Item {
      width: parent.width
      implicitHeight: Math.max(memTitle.implicitHeight, memValue.implicitHeight)

      Text {
        id: memTitle
        textFormat: Text.PlainText
        anchors.left: parent.left
        anchors.baseline: memValue.baseline
        text: "Memory"
        // The name of the thing, not a link. See Model.INK -- the accent is
        // kept for the chevron, the "Show all" link and the selected segment.
        color: Util.alpha(root.foreground, Model.INK.label)
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.weight: Font.DemiBold
      }

      Text {
        id: memValue
        textFormat: Text.PlainText
        anchors.right: parent.right
        anchors.top: parent.top
        // Linux's `used` excludes reclaimable cache, so it reads far lower than
        // the memory actually spoken for. `available` is the kernel's own
        // estimate of what a new allocation could get -- the honest headline.
        text: Model.percentText(root.committedPercent)
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.display
        font.weight: Font.Normal
      }
    }

    // The parts and the whole. These sum to `total` exactly -- verified against
    // the sampler, to the byte -- which is why this is one stacked bar rather
    // than several independent ones: separate bars would hide that they are
    // dividing up one fixed amount.
    StackBar {
      width: parent.width
      foreground: root.foreground
      segments: [
        { value: Model.num(root.mem.apps) / root.total, color: root.s1 },
        { value: Model.num(root.mem.cached) / root.total, color: root.s2 },
        { value: Model.num(root.mem.shared) / root.total, color: root.s3 }
      ]
    }

    Flow {
      width: parent.width
      spacing: Style.space(14)

      Repeater {
        model: root.breakdown

        delegate: Row {
          required property var modelData
          spacing: Style.space(5)

          Rectangle {
            width: Style.space(7)
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: modelData.color
          }

          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.label
            color: root.foreground
            opacity: 0.6
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.text
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }

    HistoryGraph {
      width: parent.width
      height: Style.space(64)
      // One series, not an apps/cache split: the history records a single
      // memory figure (OmaStatsService.qml), and it is already a PERCENTAGE --
      // feeding this a byte-sized ceiling flattens the line to nothing.
      series: [root.hist.memUsed || []]
      colors: [root.s1]
      ceiling: 100
      baselineColor: Util.alpha(root.foreground, 0.14)
    }
  }

  // Swap is its own card, not a row in the breakdown: it is a different
  // resource with a different total, and stacking it with RAM would imply the
  // two add up. Hidden entirely on a machine with no swap configured.
  Card {
    visible: root.hasSwap
    foreground: root.foreground
    spacing: Style.space(6)

    CardHeader {
      title: "Swap"
      detail: Model.pairText(Model.num(root.mem.swapUsed), Model.num(root.mem.swapTotal))
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    LevelBar {
      width: parent.width
      // Any swap in use on a machine with free RAM is worth noticing, so the
      // thresholds sit low -- this is not a capacity to fill, it is a fallback
      // you would rather not be touching.
      value: Model.num(root.mem.swapTotal) > 0
        ? Model.num(root.mem.swapUsed) / Model.num(root.mem.swapTotal) * 100
        : 0
      warnAt: 10
      dangerAt: 50
      foreground: root.foreground
      normalColor: root.s1
      warnColor: root.warn
      dangerColor: root.danger
    }
  }

  Card {
    visible: root.flag("showProcesses")
    foreground: root.foreground

    ProcessList {
      host: root.host
      items: root.procs ? (root.procs.mem || []) : []
      allItems: root.procs ? (root.procs.all || []) : []
      total: root.procs ? Model.num(root.procs.total) : 0
      columns: [{ key: "mem", kind: "bytes", title: "" }]
      emptyText: root.procs ? "Nothing resident" : "Measuring…"
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }
}
