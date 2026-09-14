// Runs bin/omarcat-storage on demand and exposes what it found.
//
// On demand, never on a timer. The scan walks the home directory, which is
// cheap here (0.2s with warm metadata) and is not cheap everywhere -- a cold
// cache, a spinning disk or a home full of small files turns it into seconds of
// I/O. A storage breakdown is something you look up when you are hunting for
// space, not something that has to be true every second.

import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  readonly property string scriptPath:
      Qt.resolvedUrl("../bin/omarcat-storage").toString().replace(/^file:\/\//, "")

  property bool scanning: false
  // True once a scan has completed, so the card can tell "never run" from
  // "ran and found nothing".
  property bool scanned: false

  // key -> { bytes, extra }. A bytes of -1 means the thing exists but could not
  // be measured without privileges.
  property var rows: ({})

  function bytesOf(key) {
    const row = root.rows[key];
    return row === undefined ? 0 : row.bytes;
  }

  function scan() {
    if (root.scanning)
      return;
    root.pending = ({});
    root.scanning = true;
    scanner.running = true;
  }

  property var pending: ({})

  Process {
    id: scanner
    command: ["/bin/sh", root.scriptPath]
    clearEnvironment: false
    running: false

    stdout: SplitParser {
      onRead: function(line) {
        const parts = String(line || "").split("\t");
        if (parts.length < 2)
          return;
        const key = parts[0];
        const bytes = Number(parts[1]);
        if (!key || !isFinite(bytes))
          return;
        root.pending[key] = { bytes: bytes, extra: parts[2] || "" };
      }
    }

    onExited: function(code, status) {
      root.scanning = false;
      // Only publish on a clean exit: a half-read scan would show categories
      // that do not add up and invite the reader to draw conclusions from the
      // gap, which is exactly what this card is trying not to do.
      if (code === 0) {
        root.rows = root.pending;
        root.scanned = true;
      }
    }
  }
}
