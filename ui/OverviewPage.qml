// The Overview tab: the whole machine at a glance, so the common case -- "is
// anything wrong right now?" -- needs no tab switching at all.
//
// Strictly present tense. There is not a time axis anywhere on this page
// except the one strip under the CPU tile, on purpose: every other tab already
// answers "how did it get here", and mixing the two makes the page something
// you read rather than something you glance at.
//
// TILES, not rows. The rows this page used to be were not wrong, they were
// just a LIST, and a list always has room for one more column -- the old row
// carried a title, a subtitle, a figure, a capacity bar and a detail line of
// three or four more figures. That is five channels on a surface meant to be
// glanced at, and the reason it happened is that nothing in the layout ever
// said no. A tile has room for a name, a figure and one more thing, so the
// question "does this belong here" is asked by the grid instead of by whoever
// is editing the file. What fell out: user/system/iowait splits, die
// temperatures, capacity bars, battery health, time-to-empty. Every one of
// them still exists one tap away, on the page that is about that subsystem.
//
// The bars went with them. A bar's length and its colour were carrying "how
// full" and "is full bad"; the figure already says how full, and a tile that
// only turns colour when something is wrong says the second thing louder than
// a bar that is always on screen. That state tint is not built yet -- see the
// note at the foot of this file.

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
  readonly property var hist: service ? service.history : Model.emptyHistory()
  readonly property color s1: service ? service.series1 : Color.accent

  spacing: root.gutter

  // ---------------------------------------------------------------- sources

  readonly property var cpu: snap.cpu || ({})
  readonly property var mem: snap.mem || ({})
  readonly property var net: snap.net || ({})
  readonly property var bat: snap.battery || ({})

  readonly property real cpuPercent: Model.num(cpu.total)
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
  readonly property real diskAvail: rootVolume ? Model.num(rootVolume.avail) : 0

  // Hidden rather than shown empty on a desktop. `present` is the sampler's own
  // answer, so this does not have to infer it from a zero percentage.
  readonly property bool hasBattery: bat.present === true
  readonly property bool charging: bat.acOnline === true

  // Which battery symbol the tile wears. Charging outranks the level: "is it
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

  // Only fans that are actually turning. A stopped or unreported fan leaves
  // the list rather than contributing a zero: "0 rpm" reads as a broken fan
  // instead of an absent sensor, and an empty list is what makes the tile
  // disappear and give its width back to the Processor.
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

  function badge(id, fallbackId) {
    return root.host ? root.host.badgeFor(id, fallbackId) : Model.rowBadge(id)
  }
  function drill(id) { if (root.host) root.host.showTab(id) }
  // The part, for the tile that has one. Identity rather than state, so it
  // sits under the name in tertiary rather than competing with the figure.
  function partOf(key) { return root.host ? root.host.partFor(key) : "" }

  // The theme's measured figure where there is one, otherwise exactly what
  // this page used before. See OmaStatsWidget.themeEdge.
  readonly property real gutter: (host && host.themeEdge > 0) ? host.themeEdge : Style.space(10)
  readonly property real inkDepth: host ? host.themeInkDepth : 1.0
  function ink(level) { return 1 - root.inkDepth * (1 - level) }
  readonly property real tilePad: (host && host.themeEdge > 0) ? host.themeEdge : Style.space(12)
  readonly property real half: Math.floor((width - gutter) / 2)

  readonly property bool showFans: fans.length > 0
  // Fans take the narrow share of the top row. The floor is what "2497 rpm"
  // needs at the figure size -- below it the unit elides and the tile starts
  // lying about the reading.
  readonly property real fanWidth: Math.max(Style.space(112), Math.round((width - gutter) * 0.36))

  // ------------------------------------------------------------------ tiles

  // The top row is the thermal story: how hard the machine is working, and how
  // hard it is working to stay cool. The CPU gets the long share because it is
  // the one subsystem whose SHAPE matters at a glance -- 34% now is a
  // different machine depending on whether it has been 34% for a minute or
  // just spiked -- and a strip needs width to have a shape at all. A fan speed
  // is a single number and needs none.
  //
  // When no fan reports -- most desktops, and Apple silicon laptops with the
  // tachometer idle -- the fan tile goes and the CPU simply takes the row.
  // Nothing here is a fixed fraction, so that transition needs no special
  // case: it is one binding reading `showFans`.
  Row {
    id: topRow
    width: root.width
    spacing: root.gutter

    // Both tiles are as tall as the taller one's content. Measured off
    // `naturalHeight`, which is content-only, so this cannot feed back.
    readonly property real rowHeight: Math.max(
      cpuTile.naturalHeight, root.showFans ? fanTile.naturalHeight : 0)

    Tile {
      id: cpuTile
      width: root.showFans ? root.width - root.gutter - root.fanWidth : root.width
      minHeight: topRow.rowHeight
      target: "cpu"
      title: "Processor"
      caption: root.partOf("cpu")
      icon: root.badge("cpu").glyph
      iconFont: root.badge("cpu").family
      value: Model.percentParts(root.cpuPercent).value
      unit: Model.percentParts(root.cpuPercent).unit
      series: root.hist.cpuTotal || []
      seriesColor: root.s1
      seriesCeiling: 100
      seriesSlots: root.service ? root.service.historyLength : 0
      padding: root.tilePad
      inkDepth: root.inkDepth
      foreground: root.foreground
      fontFamily: root.fontFamily
      onDrillRequested: function(id) { root.drill(id) }
    }

    // A fan at full tilt is something you can already HEAR, which is why it
    // earns a place on the glance page at all. It has no page of its own to
    // drill into: the reading is the whole of what there is to say.
    Tile {
      id: fanTile
      visible: root.showFans
      width: root.fanWidth
      minHeight: topRow.rowHeight
      title: "Fans"
      icon: root.badge("fans").glyph
      iconFont: root.badge("fans").family
      value: String(Math.round(root.peakRpm))
      unit: "rpm"
      // The peak is the headline -- one fan at full tilt is the answer
      // whatever the other one is doing -- so the footnote says how many are
      // behind that number rather than repeating it.
      foot: root.fans.length > 1 ? root.fans.length + " fans" : String(root.fans[0] ? root.fans[0].label : "")
      padding: root.tilePad
      inkDepth: root.inkDepth
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }

  // Two columns, and the Grid wraps -- so a machine with no battery and no fan
  // gets three tiles in a row and a half rather than a hole where the battery
  // was. Nothing here has to know how many of its neighbours exist.
  Grid {
    width: root.width
    columns: 2
    spacing: root.gutter

    Tile {
      width: root.half
      target: "memory"
      title: "Memory"
      caption: root.partOf("memory")
      icon: root.badge("memory").glyph
      iconFont: root.badge("memory").family
      value: Model.percentParts(root.memPercent).value
      unit: Model.percentParts(root.memPercent).unit
      foot: Model.pairText(Model.num(root.mem.used), root.memTotal)
      padding: root.tilePad
      inkDepth: root.inkDepth
      foreground: root.foreground
      fontFamily: root.fontFamily
      onDrillRequested: function(id) { root.drill(id) }
    }

    // Free space, not percent used. "16%" needs a second number before it
    // means anything; "191 GB" is the answer to the question people actually
    // have about a disk, and the percentage is on the Disks page.
    Tile {
      visible: root.rootVolume !== null
      width: root.half
      target: "disks"
      title: "Disk"
      caption: root.partOf("disk")
      icon: root.badge("disks").glyph
      iconFont: root.badge("disks").family
      value: Model.bytesParts(root.diskAvail).value
      unit: Model.bytesParts(root.diskAvail).unit
      foot: "free of " + Model.bytesText(root.diskTotal)
      padding: root.tilePad
      inkDepth: root.inkDepth
      foreground: root.foreground
      fontFamily: root.fontFamily
      onDrillRequested: function(id) { root.drill(id) }
    }

    // Download only. Up and down were two figures on one row here, and the
    // second one is almost always the smaller half of a question nobody was
    // asking; both are on the Network page.
    Tile {
      width: root.half
      target: "network"
      title: "Network"
      caption: root.partOf("network")
      icon: root.badge("network").glyph
      iconFont: root.badge("network").family
      value: Model.rateParts(Model.num(root.net.rx)).value
      unit: Model.rateParts(Model.num(root.net.rx)).unit
      foot: String(root.net.default || (root.net.online === false ? "offline" : ""))
      padding: root.tilePad
      inkDepth: root.inkDepth
      foreground: root.foreground
      fontFamily: root.fontFamily
      onDrillRequested: function(id) { root.drill(id) }
    }

    Tile {
      visible: root.hasBattery
      width: root.half
      title: "Battery"
      icon: root.badge(root.batteryBadgeId, "battery").glyph
      iconFont: root.badge(root.batteryBadgeId, "battery").family
      value: Model.percentParts(Model.num(root.bat.percent)).value
      unit: Model.percentParts(Model.num(root.bat.percent)).unit
      foot: String(root.bat.status || "")
      padding: root.tilePad
      inkDepth: root.inkDepth
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }

  // The way into Settings, spelled out, at the foot of the pane -- which is
  // where macOS puts it ("Wi-Fi Settings..." under Control Center's Wi-Fi
  // pane) rather than as a gear in a title bar. This pane has no title bar at
  // all, which is the other half of the same idea.
  Item {
    width: root.width
    height: settingsCard.height

    Card {
      id: settingsCard
      width: parent.width
      foreground: root.foreground
      padding: Math.round(root.tilePad * 0.7)
      spacing: 0

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        text: "Settings"
        color: root.foreground
        opacity: root.ink(Model.INK.secondary)
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }

    HoverHandler { id: setHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.drill("settings") }

    Rectangle {
      anchors.fill: settingsCard
      radius: settingsCard.radius
      color: Util.alpha(root.foreground, 0.05)
      opacity: setHover.hovered ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 110 } }
    }
  }

  // NOT BUILT YET: the state tint. In Control Center a tile goes coloured when
  // it is ON, and that is the only colour in the pane; here the equivalent is
  // "this subsystem is the reason your machine feels slow" -- a disk over 90%,
  // memory genuinely under pressure, a battery that is low and not charging.
  // The thresholds already exist (OverviewRow carried warnAt/dangerAt per
  // subsystem, and service.warn / service.danger are the colours), so this is
  // a tint on Tile plus a predicate per tile, not new plumbing. Left out of
  // this pass deliberately: getting it wrong means a pane that cries wolf,
  // and that is worth its own look at real thresholds on a machine that is
  // actually struggling rather than one sitting at 34%.
}
