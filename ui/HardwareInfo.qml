// Runs bin/omarcat-hwinfo once and exposes what it found.
//
// Once, not on a timer and not on demand. None of these strings change while
// the session is up -- a CPU does not become a different part -- so this is the
// opposite of StorageScan, which has to be asked because its answer goes stale.
//
// Everything the script reads is available to an ordinary user. That is why
// memory reports capacity rather than a part number: the DIMM model lives in
// DMI, DMI needs root, and a monitor that asks for root to label a row is
// asking too much.

import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  readonly property string scriptPath:
      Qt.resolvedUrl("../bin/omarcat-hwinfo").toString().replace(/^file:\/\//, "")

  // key -> { model, spec }. Missing keys are normal, not an error: a desktop
  // has no battery and a machine whose network device has no PCI ids has no
  // resolvable product name.
  //
  // Kept apart rather than joined at parse time, because the two surfaces that
  // ask want different amounts. A page header has the width for the whole
  // thing; a half-width tile does not, and "APPLE SSD AP0512R · 500…" is a
  // worse answer than "APPLE SSD AP0512R" -- a truncated spec reads as a
  // number that got cut off, which is exactly the thing a part number must
  // never look like.
  property var models: ({})
  property var pending: ({})

  function entry(key) {
    const v = root.models[key];
    return (v && typeof v === "object") ? v : null;
  }

  // The part alone. What a tile shows.
  function partOf(key) {
    const e = root.entry(key);
    return e ? e.model : "";
  }

  // The part and what it is made of, joined here rather than in the script so
  // the separator is the UI's choice and a part with no spec gets no trailing
  // dot. What a page header shows.
  function modelOf(key) {
    const e = root.entry(key);
    if (!e) return "";
    return e.spec.length > 0 ? e.model + "  ·  " + e.spec : e.model;
  }

  Component.onCompleted: probe.running = true

  Process {
    id: probe
    command: ["/bin/sh", root.scriptPath]
    clearEnvironment: false
    running: false

    stdout: SplitParser {
      onRead: function(line) {
        const parts = String(line || "").split("\t");
        if (parts.length < 2)
          return;
        const key = String(parts[0] || "").trim();
        // Bounded: these are labels, and a label that needs more than this is
        // not one. The row elides anyway, but the cap is on the value that
        // gets kept rather than on the one that gets drawn.
        const model = String(parts[1] || "").trim().slice(0, 96);
        const spec = String(parts[2] || "").trim().slice(0, 48);
        if (key.length === 0 || model.length === 0)
          return;
        root.pending[key] = { model: model, spec: spec };
      }
    }

    // Published whatever the exit code: unlike the storage scan there is no
    // arithmetic here to come out wrong, so a partial read is five correct
    // labels and one missing, not a misleading total.
    onExited: function(code, status) {
      root.models = root.pending;
    }
  }
}
