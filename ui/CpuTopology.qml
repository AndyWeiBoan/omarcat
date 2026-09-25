// Which physical core each logical thread belongs to.
//
// The sampler reports per-THREAD usage (`cpu.cores` has one entry per thread)
// and a `coreCount`, but not the mapping between the two -- and the mapping
// cannot be assumed. On a 4-core/8-thread i7-1185G7 the siblings are
// thread i and thread i + coreCount; other CPUs enumerate siblings adjacently
// (0 and 1 on one core, 2 and 3 on the next). Either guess is wrong on half the
// machines in the world, so read the truth out of sysfs instead.
//
// A core's identity is its cluster AND its core id. core_id alone is unique
// only within a cluster: an Apple part numbers its two efficiency cores 0 and
// 1 and then starts again at 0 in each performance cluster, so keying on the
// core id folds its eight cores into three rows. x86 has no cluster_id at all,
// where the identity falls back to the core id alone and nothing changes.
//
// Topology does not change while the machine is running, so this loads once and
// then never touches the filesystem again.

import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property int threadCount: 0

  // thread -> core id, and thread -> cluster id. Two maps rather than one
  // composite because the two sysfs reads land independently; plain objects
  // because QML property change notification on an array element is not
  // reliable.
  property var coreNum: ({})
  property var clusterNum: ({})

  // One entry per physical core: { key, cluster, core, threads }, ordered by
  // cluster then core so the rows follow the kernel's own cpu numbering.
  readonly property var coreList: {
    const byKey = ({});
    for (const thread in root.coreNum) {
      const core = Number(root.coreNum[thread]);
      if (!isFinite(core))
        continue;
      const raw = root.clusterNum[thread];
      const cluster = raw === undefined ? -1 : Number(raw);
      const key = String(cluster) + ":" + String(core);
      if (byKey[key] === undefined)
        byKey[key] = ({ key: key, cluster: cluster, core: core, threads: [] });
      byKey[key].threads.push(Number(thread));
    }
    const out = [];
    for (const key in byKey)
      out.push(byKey[key]);
    out.sort((a, b) => a.cluster !== b.cluster ? a.cluster - b.cluster : a.core - b.core);
    return out;
  }

  // True where the cores span more than one cluster, which is where the core
  // ids repeat and cannot be used as labels.
  readonly property bool multiCluster: {
    const list = root.coreList;
    for (let i = 1; i < list.length; i++)
      if (list[i].cluster !== list[0].cluster)
        return true;
    return false;
  }

  // The labels the rows carry, and what usageOf and the page's temperature
  // lookup are keyed by. One cluster keeps the kernel's own core id, which is
  // what coretemp labels its sensors with ("Core 3"); more than one cluster
  // numbers the rows in order instead, because the ids are no longer unique.
  readonly property var coreIds: {
    const out = [];
    for (let i = 0; i < root.coreList.length; i++)
      out.push(root.multiCluster ? i : root.coreList[i].core);
    return out;
  }

  readonly property bool ready: root.coreIds.length > 0

  function record(map, thread, value) {
    const next = ({});
    for (const key in map)
      next[key] = map[key];
    next[thread] = value;
    return next;
  }

  // The threads sharing one physical core, by row label.
  function threadsOf(coreId) {
    const list = root.coreList;
    for (let i = 0; i < list.length; i++)
      if ((root.multiCluster ? i : list[i].core) === coreId)
        return list[i].threads;
    return [];
  }

  // Mean usage of the threads that share one physical core. Averaging rather
  // than taking the max: two hyperthreads on one core share its execution
  // resources, so "this core is half busy" is the honest reading when one
  // sibling is pegged and the other is idle.
  function usageOf(coreId, threadUsage) {
    if (!Array.isArray(threadUsage))
      return 0;
    const threads = root.threadsOf(coreId);
    let sum = 0;
    let n = 0;
    for (let i = 0; i < threads.length; i++) {
      const value = Number(threadUsage[threads[i]]);
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

      property FileView core: FileView {
        path: "/sys/devices/system/cpu/cpu" + entry.index + "/topology/core_id"
        // Missing on some kernels and architectures; a thread that cannot be
        // placed is simply left out rather than guessed into the wrong core.
        printErrors: false
        onLoaded: root.coreNum = root.record(root.coreNum, entry.index, parseInt(text(), 10))
      }

      // Absent on x86 and on kernels too old to publish it. Its absence is not
      // an error: it leaves every core in one nameless cluster, which is what
      // those machines actually have.
      property FileView cluster: FileView {
        path: "/sys/devices/system/cpu/cpu" + entry.index + "/topology/cluster_id"
        printErrors: false
        onLoaded: root.clusterNum = root.record(root.clusterNum, entry.index, parseInt(text(), 10))
      }
    }
  }
}
