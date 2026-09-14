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

  // key -> "Model · spec". Missing keys are normal, not an error: a desktop has
  // no battery and a machine whose network device has no PCI ids has no
  // resolvable product name.
  //
  // Joined here rather than in the script so the separator is the UI's choice,
  // and so a row with no spec gets the model alone instead of a trailing dot.
  property var models: ({})
  property var pending: ({})

  function modelOf(key) {
    const v = root.models[key];
    return typeof v === "string" ? v : "";
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
        root.pending[key] = spec.length > 0 ? model + "  ·  " + spec : model;
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
