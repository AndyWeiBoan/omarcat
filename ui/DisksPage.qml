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

  readonly property var snap: service ? service.snapshot : ({})
  readonly property var hist: service ? service.history : Model.emptyHistory()
  readonly property color s1: service ? service.series1 : Color.accent
  readonly property color s2: service ? service.series2 : Color.accent
  readonly property color warn: service ? service.warn : Color.urgent
  readonly property color danger: service ? service.danger : Color.urgent

  readonly property var disks: snap.disks || ({})
  readonly property var volumes: Array.isArray(disks.volumes) ? disks.volumes : []
  readonly property var procs: snap.procs || null
  readonly property string source: String(Model.settingValue(settings, "disksSource") || "all")
  readonly property bool singleDisk: source !== "all" && !!(disks.perDisk && disks.perDisk[source])
  readonly property real readRate: singleDisk ? Model.num(disks.perDisk[source].read) : Model.num(disks.read)
  readonly property real writeRate: singleDisk ? Model.num(disks.perDisk[source].write) : Model.num(disks.write)
  readonly property var readHistory: singleDisk && hist.disks && hist.disks[source] ? hist.disks[source].read : (hist.diskRead || [])
  readonly property var writeHistory: singleDisk && hist.disks && hist.disks[source] ? hist.disks[source].write : (hist.diskWrite || [])
  readonly property var readParts: Model.rateParts(readRate)
  readonly property var writeParts: Model.rateParts(writeRate)
  readonly property string sourceModel: {
    if (!singleDisk) return ""
    for (var i = 0; i < volumes.length; i++) if (volumes[i].disk === source && volumes[i].model) return String(volumes[i].model)
    return ""
  }

  // The physical disk behind the activity figures. With an explicit source
  // setting it is that device; otherwise, when every volume sits on one disk,
  // it is that disk. Anything more mixed stays generic rather than picking a
  // device arbitrarily.
  readonly property string activityDisk: {
    if (root.singleDisk)
      return root.source;
    const names = {};
    for (let i = 0; i < root.volumes.length; i++) {
      const name = String(root.volumes[i].disk || "");
      if (name)
        names[name] = true;
    }
    const list = Object.keys(names);
    return list.length === 1 ? list[0] : "";
  }

  readonly property string activityTitle: root.activityDisk || "Activity"

  readonly property string activityDetail: {
    const parts = [];
    if (root.sourceModel)
      parts.push(root.sourceModel);
    const perDisk = root.disks.perDisk || ({});
    const entry = root.activityDisk ? perDisk[root.activityDisk] : null;
    const temp = entry ? Number(entry.temp) : NaN;
    if (entry && temp !== null && isFinite(temp))
      parts.push(Model.tempText(temp, root.temperatureUnit));
    return parts.join("  ·  ");
  }

  // Every volume's capacity added together -- what the disk is divided into.
  // Deliberately the sum of the partitions rather than the raw device size: any
  // unpartitioned tail is space this page cannot say anything useful about.
  readonly property real volumesTotal: {
    let sum = 0;
    for (let i = 0; i < root.volumes.length; i++)
      sum += Model.num(root.volumes[i].size);
    return Math.max(1, sum);
  }

  readonly property real volumesUsed: {
    let sum = 0;
    for (let i = 0; i < root.volumes.length; i++)
      sum += Model.num(root.volumes[i].used);
    return sum;
  }

  readonly property real volumesPercent: root.volumesUsed / root.volumesTotal * 100

  readonly property var volumeColors: [root.s1, root.s2, root.warn]

  // Segments are sized by CAPACITY and filled by usage -- a partition map, not
  // a usage bar. Sizing them by usage instead made `/boot` 0.0135% of the width
  // (0.06 of a pixel) and therefore invisible, and padding it to a visible
  // minimum would have claimed it takes a hundred times the space it does.
  readonly property var volumeSegments: {
    const out = [];
    for (let i = 0; i < root.volumes.length; i++) {
      const volume = root.volumes[i];
      const size = Math.max(1, Model.num(volume.size, 1));
      out.push({
        value: size / root.volumesTotal,
        fill: Model.num(volume.used) / size,
        color: root.volumeColors[i % root.volumeColors.length]
      });
    }
    return out;
  }

  readonly property var volumeRows: {
    const out = [];
    for (let i = 0; i < root.volumes.length; i++) {
      const volume = root.volumes[i];
      const size = Math.max(1, Model.num(volume.size, 1));
      const used = Model.num(volume.used);
      const parts = Model.bytesParts(used);
      out.push({
        mount: volume.mount,
        label: Model.volumeName(volume.mount),
        // Its own fullness, not its share of the disk: a 2 GB /boot at 90% is
        // in trouble while contributing almost nothing to the bar above.
        detail: Model.percentText(used / size * 100) + " of "
              + Model.bytesText(size) + "  ·  " + String(volume.fstype || ""),
        value: parts.value,
        unit: parts.unit,
        color: root.volumeColors[i % root.volumeColors.length]
      });
    }
    return out;
  }

  function openVolume(mount) {
    if (!mount) return
    Util.execArgv(["xdg-open", String(mount)])
    if (host && typeof host.close === "function") host.close()
  }

  // Built only from what the scan actually returned. Anything the script could
  // not measure is reported as such rather than being folded into the gap.
  readonly property var storageRows: {
    const out = [];
    const push = function(label, bytes, detail, indented) {
      const parts = Model.bytesParts(bytes);
      out.push({ label: label, value: parts.value, unit: parts.unit,
                 detail: detail || "", indented: indented === true });
    };

    const packages = storage.bytesOf("packages");
    if (packages > 0) {
      const count = storage.rows["packages"].extra;
      push("Packages", packages, count ? count + " installed" : "");
    }

    const home = storage.bytesOf("home");
    if (home > 0)
      push("Home", home);

    // The three biggest things inside home, because "3.6 GB" on its own does
    // not tell anyone which directory to look at.
    const children = [];
    for (const key in storage.rows) {
      if (key.indexOf("home:") !== 0)
        continue;
      const name = key.slice(5);
      if (!name || name === ".cache")
        continue;
      children.push({ name: name, bytes: storage.rows[key].bytes });
    }
    children.sort(function(a, b) { return b.bytes - a.bytes; });
    for (let i = 0; i < Math.min(3, children.length); i++)
      if (children[i].bytes > 0)
        push(children[i].name, children[i].bytes, "", true);

    // Caches get their own billing because they are the actionable part: these
    // are the entries somebody can delete tonight and get the space back.
    for (const cacheKey in storage.rows) {
      if (cacheKey.indexOf("cache:") !== 0)
        continue;
      const path = cacheKey.slice(6);
      const bytes = storage.rows[cacheKey].bytes;
      const short = path.replace(String(Quickshell.env("HOME")), "~");
      if (bytes < 0)
        out.push({ label: short, value: "needs root", unit: "", detail: "", indented: true });
      else if (bytes > 0)
        push(short, bytes, "clearable", true);
    }

    // Snapshots: usually the largest single consumer on a btrfs root, and
    // unreadable without privileges. Naming it is the whole point -- an
    // unexplained gap invites guessing.
    let snapshotsUnknown = false;
    for (const snapKey in storage.rows) {
      if (snapKey.indexOf("snapshots:") !== 0)
        continue;
      const bytes = storage.rows[snapKey].bytes;
      if (bytes < 0) {
        snapshotsUnknown = true;
        out.push({ label: "Snapshots", value: "needs root", unit: "",
                   detail: snapKey.slice(10), indented: false });
      } else if (bytes > 0) {
        push("Snapshots", bytes, snapKey.slice(10));
      }
    }

    // What is left over after everything above. Named, not hidden -- and when
    // snapshots are present but unreadable, say so here too, because that is
    // almost certainly where it went.
    const accounted = packages + home + storage.bytesOf("cache:/var/cache/pacman/pkg");
    const unaccounted = storage.bytesOf("fs_used") - accounted;
    if (unaccounted > 0)
      push("Unaccounted", unaccounted, snapshotsUnknown ? "mostly snapshots" : "");

    return out;
  }

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(10)

  // One bar for the whole disk, split by volume -- the same shape as the memory
  // page, and for the same reason: these parts DO share one real total. `/` and
  // `/boot` are carved out of one 477 GB NVMe, so stacking them is the truth
  // about that disk rather than an implication that two unrelated numbers add
  // up.
  //
  // The caveat, which is why each volume also gets its own figure below: free
  // space is NOT fungible across partitions. A full `/boot` is not rescued by
  // the space left on `/`.
  Card {
    visible: root.volumes.length > 0
    foreground: root.foreground
    spacing: Style.space(10)

    Item {
      width: parent.width
      implicitHeight: Math.max(diskTitle.implicitHeight, diskValue.implicitHeight)

      Text {
        id: diskTitle
        textFormat: Text.PlainText
        anchors.left: parent.left
        anchors.baseline: diskValue.baseline
        text: root.activityDisk || "Storage"
        // The name of the thing, not a link. See Model.INK -- the accent is
        // kept for the chevron, the "Show all" link and the selected segment.
        color: Util.alpha(root.foreground, Model.INK.label)
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.weight: Font.DemiBold
      }

      Text {
        id: diskValue
        textFormat: Text.PlainText
        anchors.right: parent.right
        anchors.top: parent.top
        text: Model.percentText(root.volumesPercent)
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.display
        font.weight: Font.Normal
      }
    }

    StackBar {
      width: parent.width
      foreground: root.foreground
      segments: root.volumeSegments
    }

    // Per volume, because the stacked bar says how the disk is divided but not
    // how close any one partition is to full -- and that is the number that
    // actually bites.
    Repeater {
      model: root.volumeRows

      delegate: StatRow {
        required property var modelData
        width: parent.width
        label: modelData.label
        detail: modelData.detail
        value: modelData.value
        unit: modelData.unit
        dot: modelData.color
        foreground: root.foreground
        fontFamily: root.fontFamily

        TapHandler { onTapped: root.openVolume(modelData.mount) }
      }
    }
  }

  Card {
    foreground: root.foreground

    // The physical disk, named, with the temperature that belongs to it -- the
    // one place it is true rather than repeated per volume.
    CardHeader {
      title: root.activityTitle
      detail: root.activityDetail
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Row {
      width: parent.width

      BigStat {
        width: parent.width / 2
        value: root.readParts.value
        unit: root.readParts.unit
        label: "Read"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      BigStat {
        width: parent.width / 2
        value: root.writeParts.value
        unit: root.writeParts.unit
        label: "Write"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }
    }

    MirrorGraph {
      id: graph
      width: parent.width
      height: Style.space(72)
      up: root.readHistory
      down: root.writeHistory
      upColor: root.s2
      downColor: root.s1
      floor: 262144
      midlineColor: Util.alpha(root.foreground, 0.18)
    }

    Legend {
      foreground: root.foreground
      fontFamily: root.fontFamily
      items: [
        { color: root.s2, label: "Read peak", value: Model.rateParts(graph.peakUp).value, unit: Model.rateParts(graph.peakUp).unit },
        { color: root.s1, label: "Write peak", value: Model.rateParts(graph.peakDown).value, unit: Model.rateParts(graph.peakDown).unit }
      ]
    }
  }

  StorageScan { id: storage }

  // Where the disk went -- from sources that need no privileges, and honest
  // about the part it cannot reach.
  //
  // Explicitly NOT a macOS-style category pie. macOS gets Applications /
  // Documents / Photos out of Spotlight and system APIs; Linux has no
  // equivalent. Worse, on a btrfs root with snapshots the walkable paths do not
  // add up to the used space -- measured on this machine: 13 GB of live paths
  // against 40 GB used, with the difference held by snapper snapshots that sit
  // outside every live path and behind root-only subvolume calls. A pie built
  // from an unprivileged walk would put two thirds of the disk in "other",
  // which looks like an answer without being one.
  //
  // So: report what can be accounted for, name what cannot, and lean towards
  // the entries a person can actually act on.
  Card {
    foreground: root.foreground
    spacing: Style.space(6)

    Item {
      width: parent.width
      implicitHeight: Math.max(storageTitle.implicitHeight, scanButton.implicitHeight)

      SectionTitle {
        id: storageTitle
        text: "Where it went"
        fontFamily: root.fontFamily
      }

      Text {
        id: scanButton
        textFormat: Text.PlainText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: storage.scanning ? "Scanning…" : (storage.scanned ? "Rescan" : "Scan")
        // A link, like "Show all" on the process lists: blue at rest, because
        // blue is what says "you can act on this". While it is running it is
        // not a link any more, so it drops to the ordinary ink.
        color: storage.scanning ? root.foreground : Color.accent
        opacity: storage.scanning ? 0.5 : (scanArea.containsMouse ? 1 : 0.85)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption

        MouseArea {
          id: scanArea
          anchors.fill: parent
          anchors.margins: -Style.space(4)
          hoverEnabled: true
          cursorShape: storage.scanning ? Qt.ArrowCursor : Qt.PointingHandCursor
          onClicked: storage.scan()
        }
      }
    }

    Text {
      textFormat: Text.PlainText
      width: parent.width
      visible: !storage.scanned
      text: "Walks your home directory. Run it when you are hunting for space."
      color: root.foreground
      opacity: 0.45
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Repeater {
      model: storage.scanned ? root.storageRows : []

      delegate: StatRow {
        required property var modelData
        width: parent.width
        label: modelData.label
        detail: modelData.detail
        value: modelData.value
        unit: modelData.unit
        labelOpacity: modelData.indented ? 0.5 : 0.85
        boldValue: !modelData.indented
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
      items: root.procs ? (root.procs.io || []) : []
      allItems: root.procs ? (root.procs.all || []) : []
      total: root.procs ? Model.num(root.procs.total) : 0
      sortKey: "io"
      columns: [
        { key: "read", kind: "rate", title: "Read" },
        { key: "write", kind: "rate", title: "Write" }
      ]
      columnWidth: Style.space(70)
      emptyText: root.procs ? "No disk activity" : "Measuring…"
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }
}
