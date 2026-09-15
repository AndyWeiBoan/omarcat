# Omarcat

A system monitor for the [Omarchy](https://omarchy.org) bar with a runner that
speeds up as the CPU gets busier, and an [iStat Menus](https://bjango.com/mac/istatmenus/)-style
panel behind it: an overview of the whole machine at a glance, then a page each
for the processor, memory, disks and network.

> **Omarcat is a fork of [OmaStats](https://github.com/crmne/omastats) by
> Carmine Paolino**, MIT licensed. The sampler, `Model.js`, the panel framework
> and the original running-cat artwork are his work; this repository is his
> history with the changes below on top. See [LICENSE](LICENSE), which carries
> both copyrights, and the fork commit message for the file-by-file split.

Omarcat is an independent project and is not affiliated with Bjango.

## What this fork changes

| | |
|---|---|
| **The bar is a runner, not readouts** | Upstream puts configurable mini graphs, rings and figures in the bar. Omarcat puts one animated sprite there and nothing else, so every bar-layout setting is gone. |
| **Five sprite sets** | `cat`, `catalpha`, `dog`, `dancer`, `sway` — each 4 body sizes × 5 gait frames, 100 SVGs in `ui/frames/`, generated from a spec by `tools/make-runner.py`. The body size follows memory pressure; the gait speed follows the CPU. |
| **An Overview page** | A new first tab summarising CPU, memory, disks and network on one screen. The other pages are reached from it, and the panel header walks back to it. |
| **Fewer pages** | Sensors and Battery pages are dropped; tabs are `overview, cpu, memory, disks, network`. |
| **Public IP off by default** | Upstream defaults `publicIp` to `true`. That is an outbound request to a third party that hands them this machine's address, so here it is opt-in. |
| **Extra helpers** | `bin/omarcat-hwinfo` and `bin/omarcat-storage`, plus `ui/HardwareInfo.qml`, `CpuTopology.qml`, `StorageScan.qml`. |
| **No release automation** | Upstream's `.github/` workflows, `PACKAGING.md` and `native-packages.yaml` are removed — they are his release pipeline, not applicable to a fork. |

> ⚠️ `preview.png` and `preview-pages.png` are still upstream's screenshots and
> show OmaStats, not Omarcat. They have not been retaken yet.

## Install

```bash
omarchy plugin add https://github.com/AndyWeiBoan/omarcat --enable
```

By hand: copy this directory to
`~/.config/omarchy/plugins/io.github.andyweiboan.omarcat/`, then
`omarchy plugin enable io.github.andyweiboan.omarcat`.

## Remove

```bash
omarchy plugin remove io.github.andyweiboan.omarcat
```

That disables the plugin and deletes its directory. By hand:
`omarchy plugin disable io.github.andyweiboan.omarcat`, then remove
`~/.config/omarchy/plugins/io.github.andyweiboan.omarcat/`. Nothing is written
outside that directory except this widget's own entry in
`~/.config/omarchy/shell.json`, which `omarchy plugin disable` removes.

## What it needs

The plugin runs one small sampler process that reads procfs and sysfs. Two
implementations ship with the same JSON protocol, both from upstream:

- `bin/omastats-sampler` — a Rust binary, x86-64, about 3 MB resident and 0.3%
  CPU. Built from `sampler/`; run `make` to rebuild it for your machine. Its
  checksum, reproducible build and signed GitHub attestation are documented in
  [BINARY_PROVENANCE.md](BINARY_PROVENANCE.md). **That attestation is upstream's
  and covers upstream's binary** — this fork ships it unchanged and has not
  re-attested it.
- `sampler.py` — a Python 3 fallback used whenever that binary is missing or
  cannot run here (another architecture, for instance). No third-party modules.
  **On aarch64 this is the one that runs** unless you rebuild the Rust binary.

The service starts `/usr/bin/python3` in isolated mode with a cleared
environment. That entry point immediately replaces itself with the Rust binary
when it can run, retaining the same process ID; otherwise it continues as the
Python sampler. No shell participates in the runtime launch path. Every emitted
JSON record is capped before it reaches the shell's streaming parser, and the
sampler is explicitly stopped when the plugin service is destroyed.

Optional command-line tools, each used only for the feature named, and each
degrading to "unavailable" when missing: `nvidia-smi` (NVIDIA GPU readings; AMD
and Intel come from sysfs), `ip` and `iw` (addresses, Wi-Fi signal), `ss` from
iproute2 (per-process network traffic), `curl` (public IP lookup), `wl-copy`
(copy an address), `xdg-open` (open a volume in your file manager).

Nothing runs as root, and no data leaves the machine unless you switch the
public-IP lookup on in Settings. It then tries `api.ipify.org`, `icanhazip.com`,
then `ifconfig.me` over HTTPS and stops after the first valid response.

## Configuring

Open the panel and click the gear in the header.

Changes are written to this widget's entry in `~/.config/omarchy/shell.json`, so
they survive restarts and each bar instance keeps its own. The same keys can be
edited there by hand or through Setup → Plugins:

| Key | Default | Meaning |
|---|---|---|
| `runner` | `cat` | Sprite set: `cat`, `catalpha`, `dog`, `dancer`, `sway` |
| `tabs` | `overview,cpu,memory,disks,network` | Which panel tabs appear |
| `temperatureUnit` | `Celsius` | `Celsius` or `Fahrenheit` |
| `refreshSeconds` | `1` | Sampling interval: 0.1, 0.2, 0.5, 1, 2, 5 or 10 |
| `historySeconds` | `240` | How far back the graphs reach, in seconds |
| `showProcesses` | `true` | Top processes on every page |
| `publicIp` | `false` | Look up the public address on the Network page |
| `disksSource` | `all` | `all`, or a device like `nvme0n1`. Not in the settings UI — the Disks page names the single physical disk when every volume sits on it and aggregates otherwise |

## Interaction

- **Left click** the runner opens the Overview; clicking it again closes the panel.
- **Right click** launches `btop` (`omarchy-launch-or-focus-tui btop`).
- **Middle click** forces a refresh.
- The header's back arrow returns to the Overview; the gear opens Settings.
- Every process list has an **All** toggle that unfolds into every process with
  a search field, sorted by that page's column. `Esc` leaves the search.
- Addresses on the Network page copy to the clipboard when clicked. Volumes on
  the Disks page open in the file manager.

The sampler reads cheap counters at the chosen interval and everything that
walks many files (processes, sensors, socket mapping) at most once a second, so
0.1 s refresh stays inexpensive. Per-process network traffic comes from the
kernel's per-socket TCP byte counters (the same ones `ss -ti` shows), differenced
once a second and tied to processes through `/proc`, so it needs no root. UDP,
and therefore QUIC, carries no such counters and is not attributed.

IPC:

```bash
omarchy-shell io.github.andyweiboan.omarcat show cpu    # open on a tab (or "settings")
omarchy-shell io.github.andyweiboan.omarcat toggle network
omarchy-shell io.github.andyweiboan.omarcat hide
omarchy-shell io.github.andyweiboan.omarcat status      # JSON summary
```

## Design notes

Graph colours come from the active theme: the accent is the first series and the
theme colour furthest around the hue wheel (magenta, cyan or blue preferred) is
the second, so user/system, upload/download and read/write always read as a pair
in any theme. Warnings use the theme's yellow and red. Text never wears a data
colour; identity comes from the dot beside it. *(Upstream's design, kept.)*

Each runner is scaled so its **drawn content** is exactly one bar icon tall, not
its 60×32 box — the five sprite sets leave different margins, and the factors in
`RUNNER_SCALE` are measured off the rendered frames rather than picked by eye.

See [NOTES.md](NOTES.md) for the rest.

## License

MIT — Copyright (c) 2026 Carmine Paolino (OmaStats, the work this is derived
from) and Copyright (c) 2026 Andy Wei (Omarcat modifications). See
[LICENSE](LICENSE).
