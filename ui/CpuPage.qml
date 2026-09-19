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

  // What a capacity bar is filled with when the reading is unremarkable.
  //
  // The panel's own ink, not the accent. Omarchy's first-party widgets draw
  // their bars in the foreground colour, and a panel that draws them in blue
  // beside them looks like a different application. Blue stays for the things
  // you can act on -- chevrons, links, the switch that is on.
  //
  // `warnColor` and `dangerColor` are untouched: the bar still changes colour
  // when the number starts to matter, which is the whole reason it has one.
  readonly property color barColor: Util.alpha(foreground, Model.INK.label)
  readonly property color s2: service ? service.series2 : Color.accent
  readonly property color s3: service ? service.tertiary : Color.accent

  readonly property var cpu: snap.cpu || ({})
  readonly property var gpu: snap.gpu || null
  readonly property var procs: snap.procs || null
  readonly property var cores: Array.isArray(cpu.cores) ? cpu.cores : []
  readonly property var efficiency: Array.isArray(cpu.efficiency) ? cpu.efficiency : []
  readonly property bool hybrid: efficiency.length > 0 && efficiency.length < cores.length

  // `efficiency` lists THREADS, so a core is an efficiency core when every
  // thread on it is in that list. Asking the topology rather than assuming the
  // list is already per-core is the same reason CpuTopology exists at all.
  function isEfficiencyCore(coreId) {
    const threads = topology.threadsOf(coreId);
    if (threads.length === 0)
      return false;
    for (let i = 0; i < threads.length; i++)
      if (root.efficiency.indexOf(threads[i]) < 0)
        return false;
    return true;
  }

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
    // hasNumber, not isFinite(Number(...)): the sampler sends null where the
    // machine has no cpu sensor at all, Number(null) is 0, and a ring that
    // reads "0°" is the same invented measurement the GPU card once printed.
    return root.hasNumber(root.cpu.temp) ? Number(root.cpu.temp) : -1;
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
      // Everything that is true of the processor but not a live share: how
      // long it has been up, how fast it is clocked, how hot it is. These used
      // to be split between here and the ring; one line reads as one aside.
      detail: {
        const parts = ["up " + Model.uptimeText(root.cpu.uptime)];
        const speed = root.headerDetail(root.cpu.mhz, root.cpu.temp);
        if (speed) parts.push(speed);
        return parts.join("  \u00b7  ");
      }
      // The current reading sits on this line rather than on one of its own.
      // As its own row it cost 34pt to repeat a number that the Overview page
      // already shows, and it put the graph -- the thing this page has that the
      // Overview page does not -- below the fold on a short screen.
      value: Model.percentText(Model.num(root.cpu.total)).replace("%", "")
      unit: "%"
      inlineDetail: true
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    // The graph runs the full width now. It used to share the line with a ring
    // gauge showing the same percentage in a second shape -- so the card had
    // two headlines for one number and the history, which is the thing the
    // Overview page cannot show, got two thirds of the width. The ring's own
    // two facts, clock speed and die temperature, are on the header line above.
    HistoryGraph {
      width: parent.width
      // 40, not 64. At a third of the width the old height was proportionate;
      // at full width the same number is mostly empty sky, and a line chart
      // reads its shape from the horizontal anyway.
      height: Style.space(40)
      series: [root.hist.cpuUser || [], root.hist.cpuSystem || []]
      colors: [root.s1, root.s2]
      ceiling: 100
      baselineColor: Util.alpha(root.foreground, 0.14)
    }

    // The graph's colours, named, with what they read right now.
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

    // The graph's colours, named, with what they read right now. Without this
    // the chart is two anonymous colours -- and the earlier version put both
    // values on one line, which left the second one stranded against the far
    // edge of the card. One row each instead, so the figures line up.
  }

  SectionTitle {
    text: "Cores"
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  Card {
    foreground: root.foreground
    // The rows carry their own inset and hairlines; the group is only the
    // surface they sit on.
    padding: 0
    spacing: 0

    // One row per PHYSICAL core, not per thread. A temperature sensor belongs
    // to a core -- two hyperthreads share one reading -- so a per-thread list
    // would print the same degrees twice and imply precision the hardware does
    // not have. Load is averaged across the core's threads; see CpuTopology for
    // why the thread-to-core mapping is read from sysfs rather than assumed.
    Column {
      width: parent.width
      spacing: 0

      Repeater {
        model: topology.ready ? topology.coreIds : []

        delegate: CoreRow {
          required property var modelData
          required property int index
          showSeparator: index > 0
          width: parent.width
          // On a hybrid part the row says which kind of core it is: eight
          // rows that all read "Core n" hide the one thing that matters about
          // this layout, which is that two of them are not like the other six.
          title: "Core " + modelData + (root.hybrid ? (root.isEfficiencyCore(modelData) ? "  \u00b7  E" : "  \u00b7  P") : "")
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
          normalColor: root.barColor
          warnColor: root.warn
          dangerColor: root.danger
          fontFamily: root.fontFamily
        }
      }
    }


  }

  SectionTitle {
    visible: root.gpuHasReadings
    text: "Graphics"
    foreground: root.foreground
    fontFamily: root.fontFamily
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
