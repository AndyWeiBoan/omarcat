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

  readonly property var cpu: snap.cpu || ({})
  readonly property var gpu: snap.gpu || null
  readonly property var procs: snap.procs || null
  readonly property var cores: Array.isArray(cpu.cores) ? cpu.cores : []
  readonly property var efficiency: Array.isArray(cpu.efficiency) ? cpu.efficiency : []
  readonly property bool hybrid: efficiency.length > 0 && efficiency.length < cores.length

  readonly property color warn: service ? service.warn : Color.urgent
  readonly property color danger: service ? service.danger : Color.urgent

  // `Number(null)` is 0 and `isFinite(0)` is true, so the obvious
  // `isFinite(Number(v))` test lets a null through and prints it as a reading.
  // That is how the GPU card came to show "0%" on a machine that reports no
  // utilisation at all. Null and zero are different answers; only one of them
  // is a measurement.
  function hasNumber(value) {
    return value !== null && value !== undefined && isFinite(Number(value));
  }

  // An Intel integrated GPU reports its name and its clock and nothing else --
  // utilisation lives behind i915 perf, which needs privileges the shell does
  // not have. A card holding one clock and four dashes is worse than no card,
  // so it appears only when the hardware actually answers.
  readonly property bool gpuHasReadings: !!root.gpu && (
       root.hasNumber(root.gpu.util)
    || root.hasNumber(root.gpu.temp)
    || root.hasNumber(root.gpu.power)
    || Model.num(root.gpu.memTotal) > 0)

  // The package sensor drives the ring: it is the die as a whole, which is what
  // throttles, rather than whichever core happens to be hottest this instant.
  // `cpu.temp` is the sampler's own pick and the fallback when the chip exposes
  // no labelled package sensor.
  readonly property var packageSensor: {
    const temps = (snap.sensors && snap.sensors.temps) || [];
    for (let i = 0; i < temps.length; i++)
      if (/^Package id/.test(String(temps[i].label || "")))
        return temps[i];
    return null;
  }
  readonly property real packageTemp: {
    if (packageSensor)
      return Model.num(packageSensor.value, -1);
    const t = Number(root.cpu.temp);
    return isFinite(t) ? t : -1;
  }
  readonly property real packageCeiling:
      packageSensor && Model.num(packageSensor.max) > 0 ? Model.num(packageSensor.max) : 100

  // Per-core temperatures, keyed by physical core id. coretemp labels its
  // sensors "Core 0".."Core N"; AMD's k10temp usually reports one package
  // figure and no per-core sensors at all, in which case this stays empty and
  // the rows quietly drop their temperature bar rather than inventing one.
  readonly property var coreTemps: {
    const out = ({});
    const temps = (snap.sensors && snap.sensors.temps) || [];
    for (let i = 0; i < temps.length; i++) {
      const match = /^Core\s+(\d+)$/.exec(String(temps[i].label || ""));
      if (match)
        out[parseInt(match[1], 10)] = temps[i];
    }
    return out;
  }

  CpuTopology {
    id: topology
    threadCount: Model.num(root.cpu.threadCount, root.cores.length)
  }

  function headerDetail(mhz, temp) {
    var parts = []
    var freq = Model.freqText(mhz)
    if (freq) parts.push(freq)
    if (root.hasNumber(temp)) parts.push(Model.tempText(temp, temperatureUnit))
    return parts.join(", ")
  }

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(10)

  Card {
    foreground: root.foreground

    CardHeader {
      title: "CPU"
      // Uptime, not frequency or temperature: those two are inside the ring to
      // the right, and printing them twice on one card was pure repetition.
      // Uptime belongs up here precisely because it is NOT a live reading --
      // it was sharing a card with the load average, which invited reading the
      // two as comparable, and they are not.
      detail: "up " + Model.uptimeText(root.cpu.uptime)
      inlineDetail: true
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    // Graph and gauge on one line: the graph is the last few minutes, the ring
    // is right now. Temperature goes in the ring rather than on the graph
    // because it moves on a different scale and would need a second axis.
    Row {
      id: chartRow
      width: parent.width
      spacing: Style.space(10)

      // Two thirds history, one third gauge. The ring is square, so its width
      // also sets the height of the whole band -- which is why the graph is
      // bound to the same number rather than to a constant.
      readonly property real gaugeWidth: (width - spacing) / 3
      readonly property real graphWidth: width - gaugeWidth - spacing

      // Graph and its key in one column, so the left side has a single height
      // that the ring can centre against. With the legend hanging below the
      // whole row instead, the taller ring left a band of dead space between
      // the chart and its own labels.
      Column {
        width: chartRow.graphWidth
        spacing: Style.space(6)

        HistoryGraph {
          width: parent.width
          // Leaves room for the two legend rows underneath without the column
          // overshooting the ring beside it.
          height: Math.round(gauge.size * 0.62)
          series: [root.hist.cpuUser || [], root.hist.cpuSystem || []]
          colors: [root.s1, root.s2]
          ceiling: 100
          baselineColor: Util.alpha(root.foreground, 0.14)
        }

        // The graph's colours, named, with what they read right now. One row
        // each rather than both on a line: the earlier single-line version left
        // the second figure stranded against the far edge of the card.
        StatRow {
          width: parent.width
          label: "User"
          dot: root.s1
          value: Model.percentText(Model.num(root.cpu.user))
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        StatRow {
          width: parent.width
          label: "System"
          dot: root.s2
          value: Model.percentText(Model.num(root.cpu.system))
          foreground: root.foreground
          fontFamily: root.fontFamily
        }
      }

      // The gauge sits in a slot the full third wide and hugs its right edge.
      // Without the slot the Row packs the ring straight after the graph and
      // strands the leftover space on the far right of the band.
      Item {
        width: chartRow.gaugeWidth
        height: gauge.size

        RingGauge {
          id: gauge
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter

          // The slot is a third of the row, but the ring does not fill it: at
          // full width the square gauge would set the height of the whole band
          // and the graph beside it would gain a lot of dead vertical space.
          // The floor matters because the line under the figure now carries
          // both the frequency and the temperature -- too small and it elides.
          size: Math.max(Style.space(86), Math.min(chartRow.gaugeWidth, Style.space(120)))

          // The arc is CPU load, matching the figure inside it. It used to be
          // temperature, which put an arc and a number on the ring that
          // measured two different things -- temperature now lives beside the
          // card title, next to the frequency it explains.
          //
          // Thresholds match the Overview page's CPU bar on purpose: the same
          // reading should not turn yellow on one page and stay blue on another.
          value: Math.min(1, Math.max(0, Model.num(root.cpu.total) / 100))
          color: Model.num(root.cpu.total) >= 90 ? root.danger
               : Model.num(root.cpu.total) >= 70 ? root.warn
               : root.s1

          foreground: root.foreground
          fontFamily: root.fontFamily
          topText: "CPU"
          valueText: String(Math.round(Model.num(root.cpu.total)))
          unitText: "%"
          // Temperature beside the load figure rather than under it: the two
          // are read together ("busy, and how hot that is making it"), and the
          // line underneath is left to the frequency alone.
          trailingText: root.packageTemp >= 0
            ? Model.tempText(root.packageTemp, root.temperatureUnit)
            : ""
          subText: Model.freqText(root.cpu.mhz)
        }
      }
    }

    // The graph's colours, named, with what they read right now. Without this
    // the chart is two anonymous colours -- and the earlier version put both
    // values on one line, which left the second one stranded against the far
    // edge of the card. One row each instead, so the figures line up.
  }

  Card {
    foreground: root.foreground
    spacing: Style.space(10)

    // One row per PHYSICAL core, not per thread. A temperature sensor belongs
    // to a core -- two hyperthreads share one reading -- so a per-thread list
    // would print the same degrees twice and imply precision the hardware does
    // not have. Load is averaged across the core's threads; see CpuTopology for
    // why the thread-to-core mapping is read from sysfs rather than assumed.
    Column {
      width: parent.width
      spacing: Style.space(8)

      Repeater {
        model: topology.ready ? topology.coreIds : []

        delegate: CoreRow {
          required property var modelData
          width: parent.width
          title: "Core " + modelData
          usage: topology.usageOf(modelData, root.cores)
          temperature: root.coreTemps[modelData] !== undefined
            ? Model.num(root.coreTemps[modelData].value, -1)
            : -1
          temperatureCeiling: root.coreTemps[modelData] !== undefined && Model.num(root.coreTemps[modelData].max) > 0
            ? Model.num(root.coreTemps[modelData].max)
            : 100
          temperatureText: root.coreTemps[modelData] !== undefined
            ? Model.tempText(Model.num(root.coreTemps[modelData].value), root.temperatureUnit)
            : ""
          foreground: root.foreground
          normalColor: root.s1
          warnColor: root.warn
          dangerColor: root.danger
          fontFamily: root.fontFamily
        }
      }
    }


  }

  Card {
    visible: root.gpuHasReadings
    foreground: root.foreground

    CardHeader {
      title: "GPU"
      detail: root.gpu ? root.headerDetail(root.gpu.mhz, root.gpu.temp) : ""
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    HistoryGraph {
      width: parent.width
      height: Style.space(48)
      series: [root.hist.gpu || []]
      colors: [root.s1]
      ceiling: 100
      baselineColor: Util.alpha(root.foreground, 0.14)
    }

    StatRow {
      label: root.gpu ? Model.shortGpuName(root.gpu.name) : "Processor"
      dot: root.s1
      value: root.hasNumber(root.gpu && root.gpu.util) ? String(Math.round(root.gpu.util)) : "—"
      unit: root.hasNumber(root.gpu && root.gpu.util) ? "%" : ""
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    StatRow {
      visible: !!(root.gpu && root.gpu.memTotal > 0)
      label: "Memory"
      detail: root.gpu && root.gpu.memTotal > 0 ? Model.percentText(root.gpu.memUsed / root.gpu.memTotal * 100) : ""
      value: root.gpu ? Model.pairText(root.gpu.memUsed, root.gpu.memTotal).replace(/ [A-Z]+$/, "") : ""
      unit: root.gpu ? Model.bytesParts(root.gpu.memTotal).unit : ""
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    StatRow {
      visible: root.hasNumber(root.gpu && root.gpu.power)
      label: "Power"
      value: root.gpu && root.gpu.power !== null ? String(Math.round(root.gpu.power)) : ""
      unit: "W"
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }

  Card {
    visible: root.flag("showProcesses")
    foreground: root.foreground

    ProcessList {
      host: root.host
      items: root.procs ? (root.procs.cpu || []) : []
      allItems: root.procs ? (root.procs.all || []) : []
      total: root.procs ? Model.num(root.procs.total) : 0
      columns: [{ key: "cpu", kind: "percent", title: "" }]
      emptyText: root.procs ? "Nothing busy" : "Measuring…"
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }
}
