// The Overview tab: the whole machine at a glance, so the common case -- "is
// anything wrong right now?" -- needs no tab switching at all.
//
// Strictly present tense. There is not a time axis anywhere on this page, on
// purpose: every other tab already answers "how did it get here", and mixing
// the two makes the page something you read rather than something you glance
// at. Each subsystem gets one bar, one large number, and one line of detail.
//
// The bar carries two channels: its length is how full, its colour is whether
// full is bad. The thresholds differ per subsystem because the same percentage
// means different things -- 80% of RAM is ordinary, 80% of a disk is not, and a
// battery is upside down.

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

  readonly property var snap: service ? service.snapshot : ({})
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
  readonly property color warn: service ? service.warn : Color.urgent
  readonly property color danger: service ? service.danger : Color.urgent

  spacing: Style.space(8)

  // Hardware identity, read once at startup. Not part of `snap`: the sampler
  // publishes things that change, and none of these do.
  HardwareInfo { id: hw }

  // ---------------------------------------------------------------- sources

  readonly property var cpu: snap.cpu || ({})
  readonly property var mem: snap.mem || ({})
  readonly property var net: snap.net || ({})
  readonly property var bat: snap.battery || ({})

  // Fans used to live on a Sensors tab that also carried temperatures. Those
  // temperatures already had homes -- the CPU's on the Processor tab, the
  // NVMe's on Disks -- so the tab went, and the fans came here rather than
  // disappearing with it. They belong on a glance page: a fan at full tilt is
  // something you can already HEAR, and this is the page that says what the
  // machine is doing right now.
  readonly property var fans: {
    const list = (snap.sensors && snap.sensors.fans) || [];
    const out = [];
    for (let i = 0; i < list.length; i++) {
      const rpm = Model.num(list[i].rpm);
      if (rpm > 0)
        out.push({ label: String(list[i].label || "Fan"), rpm: rpm });
    }
    return out;
  }

  // The busiest fan, not the average: the question is how hard this machine is
  // working to stay cool, and one fan at full tilt answers it whatever the
  // other one is doing.
  readonly property real peakRpm: {
    let peak = 0;
    for (let i = 0; i < root.fans.length; i++)
      peak = Math.max(peak, root.fans[i].rpm);
    return peak;
  }

  readonly property real cpuPercent: Model.num(cpu.total)

  // Temperature by sensor chip, for the subsystems that expose one. Returns a
  // negative when nothing reports, which the callers treat as "no sensor"
  // rather than "cold" -- memory and the battery genuinely have none here, and
  // an empty slot in their rows would read as a fault.
  function tempOfChip(chip) {
    const temps = (snap.sensors && snap.sensors.temps) || [];
    for (let i = 0; i < temps.length; i++)
      if (String(temps[i].chip || "") === chip)
        return Model.num(temps[i].value, -1);
    return -1;
  }

  // The die as a whole, which is what throttles -- the labelled package sensor
  // where the chip exposes one, otherwise the sampler's own pick. Negative
  // means no reading rather than a cold CPU.
  readonly property real cpuTemp: {
    const temps = (snap.sensors && snap.sensors.temps) || [];
    for (let i = 0; i < temps.length; i++)
      if (/^Package id/.test(String(temps[i].label || "")))
        return Model.num(temps[i].value, -1);
    const fallback = Number(root.cpu.temp);
    return isFinite(fallback) ? fallback : -1;
  }
  readonly property real memTotal: Math.max(1, Model.num(mem.total, 1))
  readonly property real memPercent: Model.num(mem.used) / memTotal * 100

  // The volume the system actually lives on. A machine can have a dozen mounts
  // -- /boot, EFI, external drives -- and "how full is my disk" almost always
  // means the root one; the Disks tab is where the rest belong.
  readonly property var rootVolume: {
    const vols = (snap.disks && snap.disks.volumes) || [];
    for (let i = 0; i < vols.length; i++)
      if (vols[i].mount === "/")
        return vols[i];
    return vols.length > 0 ? vols[0] : null;
  }
  readonly property real diskTotal: rootVolume ? Math.max(1, Model.num(rootVolume.size, 1)) : 1
  readonly property real diskUsed: rootVolume ? Model.num(rootVolume.used) : 0
  readonly property real diskPercent: diskUsed / diskTotal * 100

  // Hidden rather than shown empty on a desktop. `present` is the sampler's own
  // answer, so this does not have to infer it from a zero percentage.
  readonly property bool hasBattery: bat.present === true
  readonly property bool charging: bat.acOnline === true

  // Which battery symbol the row wears. Charging outranks the level: "is it
  // plugged in" and "how much is left" are two questions, and while it is
  // plugged in the first one is the answer. Full is not charging -- a bolt on a
  // topped-up battery reads as still drawing power.
  readonly property string batteryBadgeId: {
    if (!root.hasBattery) return "battery";
    const pct = Math.max(0, Math.min(100, Model.num(root.bat.percent)));
    if (root.charging && pct < 100 && String(root.bat.status || "") !== "Full")
      return "battery.charging";
    return "battery." + (Math.round(pct / 25) * 25);
  }

  // ------------------------------------------------------------------- CPU

  // One group, not one card per subsystem. See OverviewRow for why.
  Card {
    width: root.width
    foreground: root.foreground
    // The rows carry their own inset and their own hairlines, so the group is
    // nothing but a rounded surface to sit them on.
    padding: 0
    spacing: 0

    OverviewRow {
        showSeparator: false
        width: parent.width
        title: "CPU"
        icon: root.host ? root.host.badgeFor("cpu").glyph : Model.rowBadge("cpu").glyph
        iconFont: root.host ? root.host.badgeFor("cpu").family : root.fontFamily
        subtitle: hw.modelOf("cpu")
        target: "cpu"
        onDrillRequested: function(id) { if (root.host) root.host.showTab(id) }
        value: Model.percentText(root.cpuPercent)
        level: root.cpuPercent
        warnAt: 70
        dangerAt: 90
        foreground: root.foreground
        fontFamily: root.fontFamily
        normalColor: root.barColor
        warnColor: root.warn
        dangerColor: root.danger

        // Not idle: idle is 100 minus the rest and carries no information.
        // I/O wait does -- it is the difference between "busy" and "stuck waiting
        // on disk" -- but it is a footnote here rather than a headline, because
        // the sampler excludes it from the CPU figure above (cpu.rs computes busy
        // as 100 - idle - iowait) and two numbers that disagree read as a bug.
        detail: {
          const parts = ["User " + Model.percentText(Model.num(root.cpu.user)),
                         "System " + Model.percentText(Model.num(root.cpu.system)),
                         "I/O wait " + Model.percentText(Model.num(root.cpu.iowait))];
          // Temperature last, and only when the chip reports one: it is a
          // different kind of reading from the three shares before it, and on a
          // machine with no sensor an empty slot would look like a fault.
          if (root.cpuTemp >= 0)
            parts.push(Model.tempText(root.cpuTemp, root.temperatureUnit));
          return parts.join("     ");
        }
      }

      // Hidden where the hardware exposes none, which is most desktops and a fair
      // number of laptops -- rather than a card reading "0 rpm", which looks like
      // a stopped fan instead of an absent sensor.
    OverviewRow {
        visible: root.fans.length > 0
        width: parent.width
        title: "Fans"
        icon: root.host ? root.host.badgeFor("fans").glyph : Model.rowBadge("fans").glyph
        iconFont: root.host ? root.host.badgeFor("fans").family : root.fontFamily
        value: Math.round(root.peakRpm) + " rpm"
        // No bar: a fan has no capacity to be a fraction of. Its maximum is
        // undocumented, varies per model, and scaling against the fastest speed
        // seen this boot would move the denominator under the reader.
        showBar: false
        foreground: root.foreground
        fontFamily: root.fontFamily
        detail: {
          if (root.fans.length <= 1)
            return "";
          const parts = [];
          for (let i = 0; i < root.fans.length; i++)
            parts.push(root.fans[i].label + "  " + Math.round(root.fans[i].rpm));
          return parts.join("     ");
        }
      }

    OverviewRow {
        width: parent.width
        title: "Memory"
        icon: root.host ? root.host.badgeFor("memory").glyph : Model.rowBadge("memory").glyph
        iconFont: root.host ? root.host.badgeFor("memory").family : root.fontFamily
        subtitle: hw.modelOf("memory")
        target: "memory"
        onDrillRequested: function(id) { if (root.host) root.host.showTab(id) }
        value: Model.percentText(root.memPercent)
        level: root.memPercent
        // 85% is where the original OmaStats memory page already calls it danger
        // (MemoryPage.qml). Matching it keeps the two pages telling one story.
        warnAt: 70
        dangerAt: 85
        foreground: root.foreground
        fontFamily: root.fontFamily
        normalColor: root.barColor
        warnColor: root.warn
        dangerColor: root.danger
        detail: Model.pairText(Model.num(root.mem.used), root.memTotal)
      }

    OverviewRow {
        visible: root.rootVolume !== null
        width: parent.width
        title: "Disk"
        icon: root.host ? root.host.badgeFor("disks").glyph : Model.rowBadge("disks").glyph
        iconFont: root.host ? root.host.badgeFor("disks").family : root.fontFamily
        subtitle: hw.modelOf("disk")
        target: "disks"
        onDrillRequested: function(id) { if (root.host) root.host.showTab(id) }
        value: Model.percentText(root.diskPercent)
        level: root.diskPercent
        warnAt: 80
        dangerAt: 90
        foreground: root.foreground
        fontFamily: root.fontFamily
        normalColor: root.barColor
        warnColor: root.warn
        dangerColor: root.danger
        // Capacity, not throughput. Read/write rates are transient and live on
        // the Disks tab; free space is the thing worth knowing without asking.
        detail: {
          const parts = ["Used " + Model.bytesText(root.diskUsed),
                         "Free " + Model.bytesText(root.rootVolume ? Model.num(root.rootVolume.avail) : 0)];
          // The drive's own sensor, which the sampler attaches to each volume on
          // it. Two volumes on one NVMe report the same figure, which is fine
          // here -- this row only ever shows the volume the system lives on.
          const temp = root.rootVolume ? Model.num(root.rootVolume.temp, -1) : -1;
          if (temp >= 0)
            parts.push(Model.tempText(temp, root.temperatureUnit));
          return parts.join("  ·  ");
        }
      }

    OverviewRow {
        visible: root.hasBattery
        width: parent.width
        title: "Battery"
        icon: root.host ? root.host.badgeFor(root.batteryBadgeId, "battery").glyph : Model.rowBadge("battery").glyph
        iconFont: root.host ? root.host.badgeFor(root.batteryBadgeId, "battery").family : root.fontFamily
        subtitle: hw.modelOf("battery")
        value: Model.percentText(Model.num(root.bat.percent))
        level: Model.num(root.bat.percent)
        // Upside down: here a LOW reading is the bad one.
        inverted: true
        warnAt: 30
        dangerAt: 15
        // Plugged in and filling is never a warning, however low the number --
        // a red bar on a charging laptop is noise, not information.
        forceNormal: root.charging
        foreground: root.foreground
        fontFamily: root.fontFamily
        normalColor: root.barColor
        warnColor: root.warn
        dangerColor: root.danger
        detail: {
          const parts = [String(root.bat.status || "")];
          // Whichever clock applies: to full while charging, to empty otherwise.
          // Both are minutes and both read 0 before the sampler has an estimate,
          // so say nothing rather than "0:00".
          const mins = root.charging ? Model.num(root.bat.timeToFull) : Model.num(root.bat.timeToEmpty);
          // Only a believable one. UPower on this machine reports the port
          // controller as always-on-AC, which makes the remaining-time estimate
          // run to four figures of hours -- "25560:00 left" is not a reading,
          // it is a missing one wearing a number.
          if (mins > 0 && mins <= 24 * 60)
            parts.push(Model.clockText(mins) + " left");
          // Health came here when the Battery tab went. It is the one number on
          // that page that was not already on this one or on the bar, and it is
          // worth a glance once in a while even though it changes over years
          // rather than seconds.
          const health = Model.num(root.bat.health);
          if (health > 0)
            parts.push("health " + Math.round(health) + "%");
          return parts.join("  ·  ");
        }
      }

      // No bar. A bar means "this fraction of a capacity is gone", and a network
      // link has no capacity worth dividing by: 100 KB/s is fast or slow
      // depending on the line. Scaling to the largest rate seen this boot was the
      // alternative, and a denominator that keeps moving makes the bar lie.
    OverviewRow {
        width: parent.width
        title: "Network"
        icon: root.host ? root.host.badgeFor("network").glyph : Model.rowBadge("network").glyph
        iconFont: root.host ? root.host.badgeFor("network").family : root.fontFamily
        subtitle: hw.modelOf("network")
        target: "network"
        onDrillRequested: function(id) { if (root.host) root.host.showTab(id) }
        value: String(root.net.default || (root.net.online === false ? "offline" : ""))
        showBar: false
        valueIsText: true
        foreground: root.foreground
        fontFamily: root.fontFamily
        detail: {
          const parts = ["↓ " + Model.rateText(Model.num(root.net.rx)),
                         "↑ " + Model.rateText(Model.num(root.net.tx))];
          const temp = root.tempOfChip("Wi-Fi");
          if (temp >= 0)
            parts.push(Model.tempText(temp, root.temperatureUnit));
          return parts.join("     ");
        }
      }


    // The way into Settings, spelled out, at the bottom of the list -- which is
    // where macOS puts it ("Wi-Fi Settings..." at the foot of Control Center's
    // Wi-Fi pane) rather than as a gear in the corner of the title bar. No
    // badge, like the reference, but indented to the same left edge as the
    // rows above it so the list keeps one column.
    OverviewRow {
      width: parent.width
      reserveIcon: true
      title: "Settings"
      target: "settings"
      onDrillRequested: function(id) { if (root.host) root.host.showTab(id) }
      showBar: false
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

  }
}
