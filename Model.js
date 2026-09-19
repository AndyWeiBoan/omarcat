.pragma library

// Pure helpers shared by the service, bar readouts, and panel pages.
// No state lives here — everything is a function of its arguments.

var MODULES = [
  // Panel-only: the Overview tab is a summary of the others, so it has no bar
  // readout of its own. `panelOnly` keeps it out of the bar module list while
  // still letting pageFile() and the tab parser see it.
  { id: "overview", icon: "", short: "SUM", label: "Overview", page: "OverviewPage.qml", graph: false, ring: false, panelOnly: true },
  // Labelled "Processor" rather than "CPU" because the same page carries the
  // GPU when one is present. The id stays "cpu": it appears verbatim in user
  // settings strings (modules, tabs) and in the manifest aliases, so renaming
  // it would silently break existing configurations.
  { id: "cpu",     icon: "󰻠", short: "CPU", label: "Processor", page: "CpuPage.qml",   graph: true,  ring: true },
  { id: "gpu",     icon: "󰢮", short: "GPU", label: "GPU",     page: "CpuPage.qml",     graph: true,  ring: true },
  { id: "memory",  icon: "󰍛", short: "MEM", label: "Memory",  page: "MemoryPage.qml",  graph: true,  ring: true },
  { id: "disks",   icon: "󰋊", short: "DSK", label: "Disks",   page: "DisksPage.qml",   graph: true,  ring: true },
  { id: "network", icon: "󰛳", short: "NET", label: "Network", page: "NetworkPage.qml", graph: true,  ring: false },
  { id: "settings", icon: "󰒓", short: "SET", label: "Settings", page: "SettingsPage.qml", graph: false }
]

// Apple's ink levels, as alphas over the panel's own text colour. These are
// AppKit's semantic label colours, read straight off the Mac:
//
//     labelColor            black @ 0.847
//     secondaryLabelColor   black @ 0.498
//     tertiaryLabelColor    black @ 0.259
//     separatorColor        black @ 0.098
//
// Expressed as alphas rather than colours so they work in a dark theme too,
// where AppKit uses the same numbers over white.
//
// **The accent is not on this list.** In macOS blue means interactive or
// selected; it is never a heading. Titles, section names and row labels all
// come from here, and the accent is kept for the back chevron, links, the
// selected segment and a graph's primary series.
var INK = {
  label: 0.85,
  secondary: 0.50,
  tertiary: 0.26,
  separator: 0.10,
  // A grouped list's own fill, over the popup surface.
  groupFill: 0.05,
  groupBorder: 0.07
}

// Overview row badges: a glyph and the colour of the rounded square it sits in.
//
// The shape is macOS System Settings': a small filled squircle with a white
// symbol, one per row. Activity Monitor has no badges at all, so this is the
// Settings convention rather than a copy of any one window.
//
// **Every badge is the same neutral grey, on purpose.** Apple's system palette
// was measured out of AppKit and tried here first -- blue CPU, purple memory,
// orange disk, green battery -- and it looked good and was wrong. In this panel
// colour already has a job: LevelBar uses it for severity, blue through red,
// and CoreRow says so in as many words ("colour here is already spoken for").
// A permanently orange disk badge sitting over a blue "nothing is wrong" bar
// reads as a warning, and a green battery makes a judgement a badge has no
// business making. The symbols are distinct enough to tell the rows apart by
// shape; the colour channel stays free to mean one thing.
//
// systemGray, read out of AppKit rather than eyeballed.
//
// Glyphs stay numeric (see the README): the font's codepoints sit in a plane
// that some editing tools silently mangle.
var BADGE_TINT = "#8e8e93"

var ROW_BADGE = {
  cpu:     { glyph: String.fromCodePoint(0xf0ee0), tint: BADGE_TINT },
  memory:  { glyph: String.fromCodePoint(0xf035b), tint: BADGE_TINT },
  disks:   { glyph: String.fromCodePoint(0xf02ca), tint: BADGE_TINT },
  battery: { glyph: String.fromCodePoint(0xf0079), tint: BADGE_TINT },
  network: { glyph: String.fromCodePoint(0xf06f3), tint: BADGE_TINT },
  fans:    { glyph: String.fromCodePoint(0xf0210), tint: BADGE_TINT }
}

function rowBadge(id) {
  return ROW_BADGE[id] || { glyph: "", tint: BADGE_TINT }
}

var PANEL_TABS = ["overview", "cpu", "memory", "disks", "network"]

// Every user-tunable key with its default. Flat keys keep the entry in
// shell.json readable and editable from Setup → Plugins as well as from the
// in-panel Settings page. Per-module bar styles live in "<module>Style" and
// fall back to "style" when empty.
// Sprite sets shipped with the plugin. Each is 4 fatness levels x 5 gait
// frames in ui/frames/, generated from a spec by tools/make-runner.py.
var RUNNERS = ["cat", "catalpha", "dog", "dancer", "sway"]

// Scale each runner so its DRAWN CONTENT is exactly one bar icon tall.
//
// Every runner shares a 60x32 box but none of them fills it, and they do not
// all leave the same margin. The factor here is 32 / (content height), measured
// off the rendered frames -- so a value of 1.10 means that runner's ink covers
// 29 of the 32 units and has to be scaled up a touch to match the rest.
//
// This replaces numbers picked by eye. Those had the upright figures at 1.25
// and the cats at 0.85, on the theory that a tall thin runner needed more
// height to hold its own. Measuring showed the premise was wrong: all five fill
// the height to within 5% of each other. What actually differs is WIDTH -- the
// cat spans the whole box, the dancer about a third of it -- and inflating the
// height was compensating for that in the wrong dimension, which just made the
// figures taller than every other icon in the bar.
var RUNNER_SCALE = { cat: 1.10, catalpha: 0.65, dog: 1.06, dancer: 1.06, sway: 1.07 }

function runnerScale(name) {
  var v = RUNNER_SCALE[name]
  return typeof v === "number" ? v : 0.85
}

var SETTINGS = {
  runner: "cat",
  // What the panel shows. Everything that used to configure bar readouts is
  // gone: the cat is this plugin's bar presence, so there is nothing to lay
  // out, style or label there.
  tabs: "overview,cpu,memory,disks,network",
  temperatureUnit: "Celsius",
  refreshSeconds: 1,
  historySeconds: 240,
  showProcesses: true,
  // Off by default: looking this up is an outbound request to a third party
  // (api.ipify.org) that tells them this machine's address. Fine to switch on
  // deliberately, not fine to do on everyone's behalf the first time the panel
  // opens.
  publicIp: false,
  // Deliberately not in the settings UI. The Disks page names the one physical
  // disk when every volume sits on it and aggregates otherwise, which covers
  // every machine that is not a multi-disk workstation. Somebody who needs to
  // pin it can still set it in shell.json.
  disksSource: "all"
}

// Multiple-choice options per page, shown after that page's toggles.
var PANEL_CHOICES = {}

// Sampling intervals offered by the Settings page, in seconds.
var REFRESH_STOPS = [0.1, 0.2, 0.5, 1, 2, 5, 10]

function nearestStopIndex(value) {
  var v = Number(value)
  var best = 3
  var bestDistance = Infinity
  for (var i = 0; i < REFRESH_STOPS.length; i++) {
    var d = Math.abs(Math.log(REFRESH_STOPS[i]) - Math.log(isFinite(v) && v > 0 ? v : 1))
    if (d < bestDistance) { bestDistance = d; best = i }
  }
  return best
}

function intervalText(seconds) {
  var v = Number(seconds)
  if (!isFinite(v) || v <= 0) return "1"
  return v < 1 ? v.toFixed(1) : String(Math.round(v))
}

function parseList(raw) {
  var text = Array.isArray(raw) ? raw.join(",") : String(raw || "")
  var out = []
  var parts = text.split(/[\s,;]+/)
  for (var i = 0; i < parts.length; i++) if (parts[i] && out.indexOf(parts[i]) === -1) out.push(parts[i])
  return out
}

// ---------------------------------------------------------------- sensors

// Friendly row label for a hwmon temperature entry.
function sensorLabel(temp) {
  var chip = String(temp.chip || "")
  var label = String(temp.label || "")
  if (!label || label === chip) return chip
  if (chip === "Board" || chip.indexOf("Board") === 0) return label
  if (label.indexOf(chip) === 0) return label
  return chip + " " + label
}

// Everything the bar's sensor readout can show, as {value, label, kind}.
function sensorOptions(snapshot) {
  var s = snapshot || {}
  var cpu = s.cpu || {}
  var gpu = s.gpu || null
  var sensors = s.sensors || {}
  var out = []
  if (isFinite(Number(cpu.temp)) && cpu.temp !== null) out.push({ value: "cpu", label: "CPU temperature", kind: "temp" })
  var gpuTemp = gpu && gpu.temp !== null && isFinite(Number(gpu.temp)) ? gpu.temp : sensors.gpuTemp
  if (gpuTemp !== null && gpuTemp !== undefined && isFinite(Number(gpuTemp))) out.push({ value: "gpu", label: "GPU temperature", kind: "temp" })
  var temps = Array.isArray(sensors.temps) ? sensors.temps : []
  for (var i = 0; i < temps.length; i++) out.push({ value: String(temps[i].id), label: sensorLabel(temps[i]), kind: "temp" })
  var fans = Array.isArray(sensors.fans) ? sensors.fans : []
  for (var j = 0; j < fans.length; j++) out.push({ value: String(fans[j].id), label: String(fans[j].label || "Fan"), kind: "fan" })
  return out
}

// One reading for the bar: {icon, label, text, unit, kind} or null.
function sensorReading(snapshot, id, unit) {
  var s = snapshot || {}
  var cpu = s.cpu || {}
  var gpu = s.gpu || null
  var sensors = s.sensors || {}
  if (id === "cpu") {
    if (!(isFinite(Number(cpu.temp)) && cpu.temp !== null)) return null
    var c = tempParts(cpu.temp, unit)
    return { icon: "󰻠", short: "CPU", label: "CPU", text: c.value, unit: c.unit, kind: "temp", celsius: cpu.temp }
  }
  if (id === "gpu") {
    var gpuTemp = gpu && gpu.temp !== null && isFinite(Number(gpu.temp)) ? gpu.temp : sensors.gpuTemp
    if (gpuTemp === null || gpuTemp === undefined || !isFinite(Number(gpuTemp))) return null
    var g = tempParts(gpuTemp, unit)
    return { icon: "󰢮", short: "GPU", label: "GPU", text: g.value, unit: g.unit, kind: "temp", celsius: gpuTemp }
  }
  var temps = Array.isArray(sensors.temps) ? sensors.temps : []
  for (var i = 0; i < temps.length; i++) {
    if (String(temps[i].id) === id) {
      var t = tempParts(temps[i].value, unit)
      return { icon: "󰔏", short: "TMP", label: sensorLabel(temps[i]), text: t.value, unit: t.unit, kind: "temp", celsius: temps[i].value }
    }
  }
  var fans = Array.isArray(sensors.fans) ? sensors.fans : []
  for (var j = 0; j < fans.length; j++) {
    if (String(fans[j].id) === id) {
      var rpm = num(fans[j].rpm)
      return { icon: "󰈐", short: "FAN", label: String(fans[j].label || "Fan"), text: rpm > 0 ? String(Math.round(rpm)) : "Off", unit: rpm > 0 ? "rpm" : "", kind: "fan", rpm: rpm }
    }
  }
  return null
}

// ------------------------------------------------------------------ disks

function diskOptions(snapshot) {
  var s = snapshot || {}
  var disks = s.disks || {}
  var perDisk = disks.perDisk || {}
  var volumes = Array.isArray(disks.volumes) ? disks.volumes : []
  var models = {}
  for (var i = 0; i < volumes.length; i++) if (volumes[i].disk && volumes[i].model) models[volumes[i].disk] = volumes[i].model
  var out = [{ value: "all", label: "All disks" }]
  var names = Object.keys(perDisk).sort()
  for (var j = 0; j < names.length; j++) {
    var model = models[names[j]] ? " · " + String(models[names[j]]).slice(0, 22) : ""
    out.push({ value: names[j], label: names[j] + model })
  }
  return out
}

// ------------------------------------------------------------- processes

function processSortValue(item, key) {
  if (!item) return 0
  if (key === "io") return num(item.read) + num(item.write)
  if (key === "net") return num(item.rx) + num(item.tx)
  return num(item[key])
}

function filterProcesses(list, query, key) {
  var items = Array.isArray(list) ? list.slice() : []
  var q = String(query || "").trim().toLowerCase()
  if (q) items = items.filter(function(item) { return String(item.name || "").toLowerCase().indexOf(q) !== -1 })
  items.sort(function(a, b) {
    var d = processSortValue(b, key) - processSortValue(a, key)
    return d !== 0 ? d : String(a.name || "").localeCompare(String(b.name || ""))
  })
  return items
}

function settingValue(settings, key) {
  var value = settings ? settings[key] : undefined
  return value === undefined || value === null ? SETTINGS[key] : value
}

function truthy(value, fallback) {
  if (typeof value === "boolean") return value
  if (typeof value === "number") return value !== 0
  if (typeof value === "string") {
    var s = value.trim().toLowerCase()
    if (s === "true" || s === "on" || s === "yes" || s === "1") return true
    if (s === "false" || s === "off" || s === "no" || s === "0") return false
  }
  return value === undefined || value === null ? fallback : !!value
}

function flag(settings, key) {
  return truthy(settingValue(settings, key), SETTINGS[key] === true)
}

// Bar readout looks: graph, ring, text (figure only), both (graph + figure),
// ring-text (ring + figure).
var STYLES = ["graph", "ring", "text", "both", "ring-text"]

function normalizeStyle(value) {
  var mode = String(value || "").toLowerCase().replace("+", "-").replace("_", "-")
  if (mode === "ringtext" || mode === "ring-figure") mode = "ring-text"
  if (mode === "graph-text") mode = "both"
  return STYLES.indexOf(mode) !== -1 ? mode : ""
}

// Style choices offered for one module: rings only where fullness means something.
function styleOptions(module) {
  var def = moduleDef(module)
  var out = []
  if (def.graph) out.push({ value: "graph", label: "Graph" })
  if (def.ring) out.push({ value: "ring", label: "Ring" })
  out.push({ value: "text", label: "Figure" })
  if (def.graph) out.push({ value: "both", label: "Graph and figure" })
  if (def.ring) out.push({ value: "ring-text", label: "Ring and figure" })
  return out
}

// Effective bar style for one module: its own override, else the global one.
function moduleStyle(settings, module) {
  var own = normalizeStyle(settingValue(settings, module + "Style"))
  if (own) return own
  return normalizeStyle(settingValue(settings, "style")) || "both"
}

function moveInList(list, id, delta) {
  var out = list.slice()
  var from = out.indexOf(id)
  if (from < 0) return out
  var to = Math.max(0, Math.min(out.length - 1, from + delta))
  if (to === from) return out
  out.splice(from, 1)
  out.splice(to, 0, id)
  return out
}

function moduleDef(id) {
  for (var i = 0; i < MODULES.length; i++) if (MODULES[i].id === id) return MODULES[i]
  return MODULES[0]
}

function pageFile(tab) {
  return moduleDef(tab).page
}

// The panel tab that shows a given bar module (GPU lives on the CPU page).
function tabFor(module) {
  return module === "gpu" ? "cpu" : module
}

// allowPanelOnly is for the panel's tab list. The bar's module list must not
// offer "overview": it is a summary page, not a readout, and a BarReadout built
// from it would have nothing to draw.
function parseModules(raw, allowPanelOnly) {
  var text = Array.isArray(raw) ? raw.join(",") : String(raw || "")
  var parts = text.toLowerCase().split(/[\s,;]+/)
  var out = []
  for (var i = 0; i < parts.length; i++) {
    var id = parts[i]
    if (id === "mem" || id === "ram") id = "memory"
    if (id === "disk" || id === "storage") id = "disks"
    if (id === "net" || id === "wifi") id = "network"
    var known = false
    for (var j = 0; j < MODULES.length; j++)
      if (MODULES[j].id === id && (allowPanelOnly || !MODULES[j].panelOnly)) known = true
    if (known && out.indexOf(id) === -1) out.push(id)
  }
  return out
}

// Module tabs in canonical order, filtered by the "tabs" setting and by the
// hardware present. Never empty: the CPU tab is the floor.
// hasBattery is vestigial: the battery tab is gone, and the caller still
// passes it. Kept in the signature so the call sites do not have to change.
function panelTabs(hasBattery, tabsSetting) {
  var wanted = parseModules(tabsSetting === undefined ? SETTINGS.tabs : tabsSetting, true)
  var out = []
  for (var i = 0; i < PANEL_TABS.length; i++) {
    var id = PANEL_TABS[i]
    if (wanted.indexOf(id) === -1) continue
    out.push(id)
  }
  return out.length > 0 ? out : ["cpu"]
}

// ------------------------------------------------------------------ numbers

function clamp(v, lo, hi) {
  var n = Number(v)
  if (!isFinite(n)) return lo
  return Math.max(lo, Math.min(hi, n))
}

function num(v, fallback) {
  var n = Number(v)
  return isFinite(n) ? n : (fallback === undefined ? 0 : fallback)
}

var BYTE_UNITS = ["B", "KB", "MB", "GB", "TB", "PB"]

function bytesParts(n) {
  var v = Number(n)
  if (!isFinite(v) || v < 0) v = 0
  var i = 0
  while (v >= 1024 && i < BYTE_UNITS.length - 1) { v /= 1024; i++ }
  var text
  if (i <= 1 || v >= 100) text = String(Math.round(v))
  else text = v.toFixed(1)
  return { value: text, unit: BYTE_UNITS[i] }
}

function bytesText(n) {
  var p = bytesParts(n)
  return p.value + " " + p.unit
}

function rateParts(n) {
  var p = bytesParts(n)
  return { value: p.value, unit: p.unit + "/s" }
}

function rateText(n) {
  var p = rateParts(n)
  return p.value + " " + p.unit
}

// Ultra-compact rate for the bar: "0", "34K", "1.2M".
function compactRate(n) {
  var v = Number(n)
  if (!isFinite(v) || v < 512) return "0"
  var p = bytesParts(v)
  return p.value + p.unit.charAt(0)
}

// "1.2 / 24 GB" — drop the unit from the first number when both share it.
function pairText(a, b) {
  var pa = bytesParts(a), pb = bytesParts(b)
  if (pa.unit === pb.unit) return pa.value + " / " + pb.value + " " + pb.unit
  return pa.value + " " + pa.unit + " / " + pb.value + " " + pb.unit
}

function percentParts(v) {
  return { value: String(Math.round(clamp(v, 0, 100))), unit: "%" }
}

function percentText(v) {
  return Math.round(clamp(v, 0, 100)) + "%"
}

function tempValue(celsius, unit) {
  var c = Number(celsius)
  if (!isFinite(c)) return NaN
  return unit === "Fahrenheit" ? c * 9 / 5 + 32 : c
}

function tempParts(celsius, unit) {
  var v = tempValue(celsius, unit)
  if (!isFinite(v)) return { value: "—", unit: "" }
  return { value: String(Math.round(v)), unit: "°" }
}

function tempText(celsius, unit) {
  var p = tempParts(celsius, unit)
  return p.value + p.unit
}

function tempLongText(celsius, unit) {
  var v = tempValue(celsius, unit)
  if (!isFinite(v)) return "—"
  return Math.round(v) + (unit === "Fahrenheit" ? "°F" : "°C")
}

function freqText(mhz) {
  var m = Number(mhz)
  if (!isFinite(m) || m <= 0) return ""
  return m >= 1000 ? (m / 1000).toFixed(2) + " GHz" : Math.round(m) + " MHz"
}

function uptimeText(seconds) {
  var s = Math.max(0, Math.floor(Number(seconds) || 0))
  var d = Math.floor(s / 86400)
  var h = Math.floor((s % 86400) / 3600)
  var m = Math.floor((s % 3600) / 60)
  if (d > 0) return d + "d " + h + "h"
  if (h > 0) return h + "h " + m + "m"
  if (m > 0) return m + "m"
  return "<1m"
}

function clockText(minutes) {
  var m = Math.max(0, Math.round(Number(minutes) || 0))
  var h = Math.floor(m / 60)
  var r = m % 60
  return h + ":" + (r < 10 ? "0" : "") + r
}

function loadText(load) {
  if (!Array.isArray(load) || load.length < 3) return "—"
  return load.map(function(v) { return Number(v).toFixed(2) }).join("  ")
}

function volumeName(mount) {
  var m = String(mount || "")
  if (m === "/") return "Root"
  if (m === "/home") return "Home"
  if (m === "/boot" || m === "/boot/efi" || m === "/efi") return "Boot"
  var parts = m.split("/")
  return parts[parts.length - 1] || m
}

function shortGpuName(name) {
  return String(name || "GPU")
    .replace(/^NVIDIA\s+/i, "")
    .replace(/^GeForce\s+/i, "")
    .replace(/^AMD\s+/i, "")
    .replace(/^Radeon\s+/i, "")
    .replace(/^Intel\s+(Corporation\s+)?/i, "")
    .replace(/\s+Graphics$/i, "")
}

function batteryIcon(percent, charging) {
  if (charging) return "󰂄"
  var icons = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
  return icons[Math.round(clamp(percent, 0, 100) / 10)]
}

function wifiIcon(dbm) {
  var d = Number(dbm)
  if (!isFinite(d)) return "󰤨"
  if (d >= -55) return "󰤨"
  if (d >= -65) return "󰤥"
  if (d >= -75) return "󰤢"
  if (d >= -85) return "󰤟"
  return "󰤯"
}

function ifaceIcon(iface) {
  if (!iface) return "󰈀"
  if (iface.wireless) return wifiIcon(iface.dbm)
  if (/^(tun|tap|wg|tailscale|proton|nord|vpn)/.test(iface.name || "")) return "󰖂"
  return "󰈀"
}

function linkSpeedText(iface) {
  if (!iface) return ""
  if (iface.wireless && iface.bitrate) return Math.round(iface.bitrate) + " Mb/s"
  var mbps = Number(iface.speed)
  if (!isFinite(mbps) || mbps <= 0) return ""
  return mbps >= 1000 ? (mbps / 1000) + " Gb/s" : mbps + " Mb/s"
}

// ------------------------------------------------------------------ history

function emptyHistory() {
  return {
    cpuUser: [], cpuSystem: [], cpuTotal: [], gpu: [],
    memUsed: [], memPressure: [],
    netRx: [], netTx: [], diskRead: [], diskWrite: [], disks: {},
    battery: [], batteryCharging: []
  }
}

function pushHistory(arr, value, max) {
  var list = Array.isArray(arr) ? arr : []
  var keep = Math.max(1, max - 1)
  var out = list.length > keep ? list.slice(list.length - keep) : list.slice()
  out.push(Number(value) || 0)
  return out
}

function maxOf(arr, count) {
  if (!Array.isArray(arr) || arr.length === 0) return 0
  var start = count > 0 ? Math.max(0, arr.length - count) : 0
  var m = 0
  for (var i = start; i < arr.length; i++) if (arr[i] > m) m = arr[i]
  return m
}

function last(arr, fallback) {
  if (!Array.isArray(arr) || arr.length === 0) return fallback
  return arr[arr.length - 1]
}

// ------------------------------------------------------------------ palette

function parseColorsToml(text) {
  var out = {}
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var m = lines[i].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
    if (m) out[m[1]] = m[2]
  }
  return out
}

function hueOf(c) {
  var q = Qt.color(c)
  return q.hslHue < 0 ? -1 : q.hslHue * 360
}

function hueDistance(a, b) {
  if (a < 0 || b < 0) return 0
  var d = Math.abs(a - b) % 360
  return d > 180 ? 360 - d : d
}

function shiftHue(c, degrees, minSaturation) {
  var q = Qt.color(c)
  var h = q.hslHue < 0 ? 0.6 : (q.hslHue + degrees / 360 + 1) % 1
  return Qt.hsla(h, Math.max(minSaturation || 0.45, q.hslSaturation), clamp(q.hslLightness, 0.45, 0.72), 1)
}

// Derive the two-hue iStat scheme from the active theme: series1 is the
// accent; series2 is the theme colour furthest around the wheel from it
// (magenta/cyan/blue preferred), and a tertiary colour covers a third
// category where one is needed. Warn/danger are the theme's yellow/red.
function pickPalette(theme, accent, foreground, background, urgent) {
  var t = theme || {}
  var accentHue = hueOf(accent)
  var bgLight = Qt.color(background).hslLightness
  var names = ["blue", "magenta", "cyan", "green", "yellow", "orange", "red"]
  var candidates = []
  for (var i = 0; i < names.length; i++) {
    var c = t[names[i]]
    if (!c) continue
    var q = Qt.color(c)
    if (q.hslSaturation < 0.2 || Math.abs(q.hslLightness - bgLight) < 0.25) continue
    candidates.push({ name: names[i], color: c, hue: hueOf(c), dist: hueDistance(accentHue, hueOf(c)) })
  }
  candidates.sort(function(a, b) { return b.dist - a.dist })

  var second = null
  for (var j = 0; j < candidates.length; j++) {
    var cand = candidates[j]
    if ((cand.name === "magenta" || cand.name === "cyan" || cand.name === "blue") && cand.dist >= 50) { second = cand; break }
  }
  if (!second && candidates.length > 0 && candidates[0].dist >= 30) second = candidates[0]
  var series2 = second ? second.color : shiftHue(accent, 180)
  var series2Hue = hueOf(series2)

  var tertiary = null
  for (var k = 0; k < candidates.length; k++) {
    var alt = candidates[k]
    if (alt === second) continue
    if (alt.dist >= 35 && hueDistance(alt.hue, series2Hue) >= 35) { tertiary = alt.color; break }
  }
  if (!tertiary) tertiary = t.yellow || shiftHue(accent, 120)

  return {
    series1: accent,
    series2: series2,
    tertiary: tertiary,
    warn: t.yellow || t.orange || tertiary,
    danger: t.red || urgent,
    good: t.green || accent
  }
}
