// Which physical core each logical thread belongs to.
//
// The sampler reports per-THREAD usage (`cpu.cores` has one entry per thread)
// and a `coreCount`, but not the mapping between the two -- and the mapping
// cannot be assumed. On a 4-core/8-thread i7-1185G7 the siblings are
// thread i and thread i + coreCount; other CPUs enumerate siblings adjacently
// (0 and 1 on one core, 2 and 3 on the next). Either guess is wrong on half the
// machines in the world, so read the truth out of sysfs instead.
//
// Topology does not change while the machine is running, so this loads once and
// then never touches the filesystem again.

import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property int threadCount: 0

  // threadIndex -> physical core id, as a plain object because QML property
  // change notification on an array element is not reliable.
  property var coreOf: ({})

  // Sorted, de-duplicated physical core ids -- the rows to draw.
  readonly property var coreIds: {
    const seen = {};
    const out = [];
    for (const key in root.coreOf) {
      const id = root.coreOf[key];
      if (seen[id] === undefined) {
        seen[id] = true;
        out.push(id);
      }
    }
    out.sort((a, b) => a - b);
    return out;
  }

  readonly property bool ready: root.coreIds.length > 0

  function record(thread, core) {
    if (!isFinite(core))
      return;
    const next = ({});
    for (const key in root.coreOf)
      next[key] = root.coreOf[key];
    next[thread] = core;
    root.coreOf = next;
  }

  // Mean usage of the threads that share one physical core. Averaging rather
  // than taking the max: two hyperthreads on one core share its execution
  // resources, so "this core is half busy" is the honest reading when one
  // sibling is pegged and the other is idle.
  function usageOf(coreId, threadUsage) {
    if (!Array.isArray(threadUsage))
      return 0;
    let sum = 0;
    let n = 0;
    for (const key in root.coreOf) {
      if (root.coreOf[key] !== coreId)
        continue;
      const value = Number(threadUsage[Number(key)]);
      if (isFinite(value)) {
        sum += value;
        n++;
      }
    }
    return n > 0 ? sum / n : 0;
  }

  Instantiator {
    model: root.threadCount
    active: root.threadCount > 0

    delegate: QtObject {
      id: entry
      required property int index

      property FileView file: FileView {
        path: "/sys/devices/system/cpu/cpu" + entry.index + "/topology/core_id"
        // Missing on some kernels and architectures; a thread that cannot be
        // placed is simply left out rather than guessed into the wrong core.
        printErrors: false
        onLoaded: root.record(entry.index, parseInt(text(), 10))
      }
    }
  }
}
