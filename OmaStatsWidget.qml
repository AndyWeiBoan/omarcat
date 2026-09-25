import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "ui" as UI

// Bar entry point. One instance per bar per monitor; every instance shares
// the single OmaStatsService for data and opens its own popup panel.
Panel {
  id: root
  moduleName: "io.github.andyweiboan.omarcat"
  // 讓外部可以叫開／關這個面板（omarchy-shell omarcat open）。其他外掛都有，
  // 少了它連開發時要截圖驗證都得靠人手動點。
  ipcTarget: "io.github.andyweiboan.omarcat"
  // 自己擁有這個 target，才能多掛一個「直接開到某一頁」的方法。
  manageIpc: false

  readonly property var service: bar && bar.shell ? bar.shell.serviceFor("io.github.andyweiboan.omarcat") : null
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal
  readonly property string temperatureUnit: String(setting("temperatureUnit", "Celsius")).toLowerCase() === "fahrenheit" ? "Fahrenheit" : "Celsius"
  readonly property bool publicIpEnabled: Model.flag(settings, "publicIp")
  readonly property var configuredModules: Model.parseModules(setting("modules", Model.SETTINGS.modules))
  readonly property bool hasGpu: !!(service && service.hasGpu)
  readonly property bool hasBattery: !!(service && service.hasBattery)
  // The cat IS this plugin's presence in the bar. The upstream project put a
  // row of configurable CPU/MEM/NET readouts here and kept the cat as one
  // option among them; omarcat keeps only the cat. That is the whole identity
  // of the thing -- there are already thousands of bar widgets that draw a
  // number, and the readout configuration was most of a 559-line settings page
  // for a feature this fork does not ship.
  //
  // Original note, still true of the cat itself: it is an animated
  // cat that runs faster the busier the CPU is (ui/RunCat.qml, fed from this
  // widget's own samples). It lives inside this widget rather than as a
  // separate plugin so there is exactly one bar entry: the panel then anchors
  // to the cat, and its indicator sits under the cat instead of under a hidden
  // placeholder widget.

  // ------------------------------------------------------------ theme icons
  // A theme may replace the row badges by shipping `omarcat.json` in its own
  // directory -- the same route the dock's dock.json and the Control Center's
  // controlcenter.json take, and `omarchy-theme-set` copies the whole theme
  // directory, so the file simply appears next to colors.toml.
  //
  // It exists for one reason: **SF Symbols**. The Nerd Font glyphs the modules
  // carry are Material Design's, a different drawing tradition -- heavier,
  // more literal, and carrying detail a 14px badge cannot show (its CPU icon
  // has the characters "64" inside it). SF Symbols are the macOS set. But they
  // live in the PUA of a specific build of SF Pro Display, and their codepoints
  // drift between versions, so they cannot be hardcoded in a plugin that has to
  // draw on machines that have never heard of that font.
  //
  // Codepoints are numbers, not string escapes: this plane is exactly where
  // editors and JSON tools silently mangle characters.
  property var themeIcons: ({})

  function loadThemeIcons(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      root.themeIcons = (parsed && typeof parsed === "object") ? parsed : ({})
    } catch (e) {
      root.themeIcons = ({})
    }
  }

  // {glyph, family}. The theme wins where it has an entry; anything it says
  // nothing about keeps the Nerd Font glyph and the bar's own font, so a theme
  // with no file is untouched by any of this. The badge's fill and ink are not
  // here -- they come from the panel's own foreground, in OverviewRow.
  // `id` is the most specific name -- "battery.charging", "battery.50" -- and
  // `baseId` the general one to fall back on when neither the theme nor Model
  // has that variant. A theme only has to map the states it cares to draw.
  function badgeFor(id, baseId) {
    var table = root.themeIcons && root.themeIcons.badges ? root.themeIcons.badges : null
    var entry = table ? table[id] : null
    if ((!entry || !isFinite(Number(entry.codepoint))) && baseId)
      entry = table ? table[baseId] : null
    var fallback = Model.rowBadge(id)
    if (!fallback.glyph && baseId) fallback = Model.rowBadge(baseId)
    if (!entry || !isFinite(Number(entry.codepoint)))
      return { glyph: fallback.glyph, family: root.fontFamily }
    return {
      glyph: String.fromCodePoint(Number(entry.codepoint)),
      family: String(root.themeIcons.badgeFont || root.fontFamily)
    }
  }

  // A theme switch does not change this path, and Color's own FileViews are
  // startup-only -- runtime switches push the payload through shell IPC -- so
  // without this the panel would keep the previous theme's badges until the
  // next restart. Watching the palette the IPC path writes is the available
  // signal; two themes would have to agree on all four to be missed.
  readonly property string themeStamp: [Color.background, Color.foreground,
                                        Color.accent, Color.popups.background].join("|")
  onThemeStampChanged: themeIconFile.reload()

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    // 直接開到指定的頁（overview / cpu / memory / disks / network / settings）。
    // 綁快捷鍵可以一鍵跳到某一頁；開發時要截某一頁也靠它。
    function show(tab: string): void { root.currentTab = tab; root.open() }
  }

  FileView {
    id: themeIconFile
    path: Color.currentThemePath + "/omarcat.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.loadThemeIcons(text())
    onLoadFailed: root.themeIcons = ({})
  }

  // ONE gap, everywhere. The Control Center measurements in the theme give
  // `edge` -- 10 logical px on this machine, solved for rather than eyeballed
  // (see the theme's provenance/controlcenter-material.txt) -- and it is the
  // popup's own inset, the space between tiles, and a tile's own padding, all
  // three. Style's tokens gave 14 / 11 / 13 for those, and three values that
  // are nearly but not quite equal is precisely what reads as uneven padding.
  //
  // 0 when the theme says nothing, which is the signal for every caller to
  // keep the figure it used before: a theme without the key is untouched.
  readonly property int themeEdge: {
    var v = Number(root.themeIcons ? root.themeIcons.edge : NaN)
    return (isFinite(v) && v > 0) ? Math.round(v) : 0
  }
  readonly property int panelEdge: aPanelInset > 0 ? aPanelInset
    : (themeEdge > 0 ? themeEdge : Style.spacing.popupPadding)

  // How deep the Overview sets its ink. Multiplies each level's REMAINING
  // LIGHTNESS rather than its alpha: a' = 1 - k(1 - a). Scaling alpha runs the
  // top level into 1.0 and closes the gap between it and the one below, which
  // flattens the hierarchy exactly where it matters; scaling the lightness
  // keeps every step in the same proportion to the step above it, which is
  // what "deeper, same proportions" has to mean.
  //
  // This is a PREFERENCE, not a restoration. Model.INK already carries the
  // measured macOS figures (0.847 / 0.498 / 0.259) and they are what macOS
  // really uses on a lifted Control Center tile. They read lighter here
  // because macOS composites label text with vibrancy -- a blend against the
  // material underneath, not flat alpha -- and Quickshell has no equivalent,
  // so a straight alpha under-delivers the same number.
  //
  // 1.0 leaves Model.INK exactly as it is, which is what a theme without the
  // key gets.
  // The gap between the panel's chrome and the page below it -- and ZERO when
  // there is no chrome, which is the Overview's normal state. It used to be an
  // unconditional Style.space(10) separating the page from the tab strip; with
  // the strip hidden that became 10 of panel padding plus 11 of nothing, so
  // the first tile sat twice as far from the top edge as it did from the
  // sides. Same figure as every other gap when it is needed at all.
  readonly property int pageGap: (tabs.visible || statusLine.visible) ? panelEdge : 0

  // ---- design/DESIGN.md 方案 A 的共用視覺規格 ----
  //
  // 每一個都以「主題沒講就維持改動前的畫法」為預設（數字 0、顏色 transparent），
  // 所以沒有 omarcat.json 的主題逐像素不變，不外溢。
  //
  // 面板與卡片是**實色不透明**，這是設計稿的明確決定，不是 HTML 原型的限制：
  // 「不把 Apple 風格等同大量模糊或透明」，以可讀性優先。
  function themeNum(key, dflt) {
    var v = Number(root.themeIcons ? root.themeIcons[key] : NaN)
    return (isFinite(v) && v > 0) ? v : dflt
  }
  function themeColor(key) {
    var v = root.themeIcons ? root.themeIcons[key] : null
    return (typeof v === "string" && v.length > 0) ? Qt.color(v) : "transparent"
  }

  readonly property int   aPanelWidth:  Math.round(themeNum("panelWidth", 0))
  readonly property int   aPanelRadius: Math.round(themeNum("panelRadius", 0))
  readonly property int   aPanelInset:  Math.round(themeNum("panelInset", 0))
  readonly property int   aCardRadius:  Math.round(themeNum("cardRadius", 0))
  readonly property int   aCardPadding: Math.round(themeNum("cardPadding", 0))
  readonly property int   aCardGap:     Math.round(themeNum("cardGap", 0))
  readonly property color aPanelFill:   themeColor("panelFill")
  readonly property color aCardFill:    themeColor("cardFill")
  readonly property color aInk:         themeColor("ink")
  readonly property color aSecondary:   themeColor("secondary")
  // 只有在面板底和卡片都給了顏色時才切換到實色模式。
  readonly property bool  aSolid:       aPanelFill.a > 0 && aCardFill.a > 0

  readonly property real themeInkDepth: {
    var v = Number(root.themeIcons ? root.themeIcons.inkDepth : NaN)
    return (isFinite(v) && v > 0 && v <= 1) ? v : 1.0
  }

  // What the machine IS, as opposed to what it is doing. Lives up here rather
  // than on a page because the probe should run once for the panel, not once
  // per page visit, and because more than one page wants an answer from it.
  //
  // It used to be the subtitle of every Overview row. Tiles have no subtitle
  // -- that was one of the five channels the grid exists to refuse -- and for
  // one pass the strings were probed and then shown nowhere at all, which was
  // a plain loss, not a cut. A part number is identity: it never changes, so a
  // glance pane is the wrong place for it and the page you opened on purpose
  // is the right one.
  UI.HardwareInfo { id: hw }

  // Pages reach the probe through here rather than through the id: `host` is
  // this widget seen as a plain property, and an id is not one.
  function modelFor(key) { return hw.modelOf(key) }
  function partFor(key) { return hw.partOf(key) }

  // Tab ids and hwinfo keys are separate vocabularies -- the page is "disks",
  // the part is one "disk" -- so the join is spelled out rather than assumed.
  readonly property var hwKeyForTab: ({
    "cpu": "cpu", "memory": "memory", "disks": "disk", "network": "network"
  })

  readonly property var moduleTabs: Model.panelTabs(hasBattery, setting("tabs", Model.SETTINGS.tabs))
  readonly property var panelTabs: moduleTabs.concat(["settings"])
  readonly property color fg: Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string instanceKey: moduleName + ":" + Math.random().toString(36).slice(2, 8)

  readonly property string runner: {
    var want = String(setting("runner", Model.SETTINGS.runner) || "").trim().toLowerCase()
    return Model.RUNNERS.indexOf(want) !== -1 ? want : Model.SETTINGS.runner
  }

  readonly property string disksSource: String(setting("disksSource", Model.SETTINGS.disksSource) || "all")

  property string currentTab: "overview"
  property int tabCursor: -1

  // Expanded process list + its search, shared by every page.
  property bool processesExpanded: false
  property string processQuery: ""
  property bool searchActive: false
  property var searchField: null
  property bool fullHeld: false

  function setProcessesExpanded(value) {
    processesExpanded = value === true
    if (!processesExpanded) {
      processQuery = ""
      searchActive = false
    }
    syncFull()
  }

  // Hold a "full process list" reference on the service only while the
  // panel is open with the list unfolded.
  function syncFull() {
    var want = opened && processesExpanded
    if (!service || want === fullHeld) return
    fullHeld = want
    if (want) service.acquireFull()
    else service.releaseFull()
  }

  function focusSearch() {
    if (!processesExpanded) setProcessesExpanded(true)
    Qt.callLater(function() { if (root.searchField) root.searchField.forceActiveFocus() })
  }


  function showTab(id) {
    var tab = Model.tabFor(id)
    if (panelTabs.indexOf(tab) === -1) tab = panelTabs[0]
    if (currentTab !== tab) {
      currentTab = tab
      resetScroll()
    }
  }

  // Bar click: open on that module; a second click on the same module closes.
  function toggleModule(id) {
    var tab = Model.tabFor(id)
    if (opened && currentTab === tab) { close(); return }
    showTab(tab)
    if (!opened) open()
  }

  function cycleTab(delta) {
    var idx = panelTabs.indexOf(currentTab)
    if (idx < 0) idx = 0
    idx = (idx + delta + panelTabs.length) % panelTabs.length
    showTab(panelTabs[idx])
  }

  function resetScroll() {
    var flick = scrollArea.contentItem
    if (flick && flick.contentY !== undefined) flick.contentY = 0
  }

  function scrollBy(steps) {
    var flick = scrollArea.contentItem
    if (!flick || flick.contentY === undefined) return
    var max = Math.max(0, flick.contentHeight - flick.height)
    flick.contentY = Math.max(0, Math.min(max, flick.contentY + steps * Style.space(48)))
  }

  function refresh() {
    if (service && publicIpEnabled) service.requestPublicIp(true)
  }

  function pushSettings() {
    if (!service) return
    service.registerSettings(instanceKey, {
      refreshSeconds: setting("refreshSeconds", 1),
      historySeconds: setting("historySeconds", 240)
    })
  }

  // ---------------------------------------------------------- persistence

  // Where this instance lives in shell.json, so a change touches only this
  // copy even when the widget appears several times in the bar.
  function locateSelf() {
    if (!bar || typeof bar.layoutEntries !== "function" || !Array.isArray(bar.moduleSlots)) return null
    var mine = null
    for (var i = 0; i < bar.moduleSlots.length; i++) {
      var slot = bar.moduleSlots[i]
      if (slot && slot.activeItem === root) { mine = slot; break }
    }
    if (!mine) return null
    var region = String(mine.region || "")
    var entries = bar.layoutEntries(region)
    var direct = entries.indexOf(mine.entry)
    if (direct !== -1) return { section: region, index: direct }
    var candidates = []
    for (var j = 0; j < entries.length; j++) {
      if (typeof bar.entryId === "function" && bar.entryId(entries[j]) === moduleName) candidates.push(j)
    }
    if (candidates.length === 1) return { section: region, index: candidates[0] }
    if (candidates.length === 0) return null
    // Several copies in this region: rank this slot among its siblings on the same screen.
    var siblings = []
    for (var k = 0; k < bar.moduleSlots.length; k++) {
      var other = bar.moduleSlots[k]
      if (!other || other.region !== region || other.moduleName !== moduleName) continue
      if (typeof bar.sameWindow === "function" && typeof bar.slotWindow === "function"
          && !bar.sameWindow(bar.slotWindow(other), bar.slotWindow(mine))) continue
      siblings.push(other)
    }
    siblings.sort(function(a, b) { return root.vertical ? a.y - b.y : a.x - b.x })
    var ordinal = siblings.indexOf(mine)
    if (ordinal < 0 || ordinal >= candidates.length) return null
    return { section: region, index: candidates[ordinal] }
  }

  function persist(key, value) {
    var next = {}
    for (var k in settings) next[k] = settings[k]
    next[key] = value
    settings = next
    if (!bar || !bar.shell) return
    var registry = bar.shell.pluginRegistry
    var where = locateSelf()
    if (registry && where && typeof registry.setBarWidget === "function") {
      var error = registry.setBarWidget(moduleName, key, value, { section: where.section, index: where.index })
      if (!error) return
      console.warn("io.github.andyweiboan.omarcat: per-instance setting failed, falling back:", error)
    }
    if (typeof bar.shell.updateEntryInline === "function") {
      var entry = { id: moduleName }
      for (var e in next) if (e !== "id") entry[e] = next[e]
      bar.shell.updateEntryInline(moduleName, entry)
    }
  }

  function resetSettings() {
    var defaults = Model.SETTINGS
    for (var key in defaults) persist(key, defaults[key])
  }

  // LOCAL EDIT: in cat mode the cat is the readout, so it sizes the widget.
  implicitWidth: runcat.implicitWidth
  implicitHeight: vertical ? runcat.implicitHeight : barSize

  onOpenedChanged: {
    if (!service) return
    if (opened) {
      service.acquireDetail()
      service.setFocus(currentTab)
      tabCursor = -1
    } else {
      service.releaseDetail()
      service.setFocus("")
      searchActive = false
    }
    syncFull()
  }

  onCurrentTabChanged: if (opened && service) service.setFocus(currentTab)

  onPanelTabsChanged: if (panelTabs.indexOf(currentTab) === -1) currentTab = panelTabs[0]
  onSettingsChanged: pushSettings()
  onServiceChanged: {
    pushSettings()
    if (service) service.registerInstance(root)
  }
  Component.onCompleted: {
    pushSettings()
    if (service) service.registerInstance(root)
  }
  Component.onDestruction: {
    if (service) {
      if (opened) service.releaseDetail()
      if (fullHeld) service.releaseFull()
      service.unregisterSettings(instanceKey)
      service.unregisterInstance(root)
    }
  }

  // The cat itself.
  UI.RunCat {
    id: runcat
    runner: root.runner
    anchors.centerIn: parent
    // 這隻貓是畫在選單列上的，要跟旁邊的字符同一個顏色 —— 那個出口是
    // bar.barForeground，不是 Color.bar.text（後者是主題的文字色，
    // 選單列自己另外設白色時不會跟著動）。
    foreground: root.bar ? root.bar.barForeground : Color.bar.text
    cpu: {
      const snap = root.service ? root.service.snapshot : null
      return snap && snap.cpu ? (snap.cpu.total || 0) : 0
    }
    memory: {
      const snap = root.service ? root.service.snapshot : null
      const mem = snap ? snap.mem : null
      return mem && mem.total > 0 ? (mem.used / mem.total * 100) : 0
    }
    onActivated: function(button) {
      // Overview, not CPU: the cat is not a CPU readout, it is the whole
      // machine's mood, so clicking it should land on the page that says
      // what the whole machine is doing.
      if (button === Qt.LeftButton) root.toggleModule("overview")
      else if (button === Qt.RightButton && root.bar) root.bar.run("omarchy-launch-or-focus-tui btop")
      else if (button === Qt.MiddleButton) root.refresh()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    // Wide enough to name every tab in full; the strip abbreviates only if
    // the screen cannot give it that much.
    // The same width as Omarchy's own panels (audio, bluetooth, power all use
    // 380). It used to be "however wide the tab strip spells out", which made
    // every page as wide as the longest row of page names.
    padding: root.panelEdge
    contentWidth: panel.fittedContentWidth(Style.space(root.aPanelWidth > 0 ? root.aPanelWidth : 380))
    // Grow with the page; KeyboardPanel caps this at the screen, which is the
    // only point at which the page scrolls.
    contentHeight: panel.fittedContentHeight(
      tabs.height + root.pageGap + statusLine.height + pageLoader.implicitHeight)

    // 實色面板底。負 margin 是為了連 padding 那一圈也蓋掉，否則四邊會露出
    // 底下半透明的材質。
    Rectangle {
      anchors.fill: parent
      anchors.margins: -root.panelEdge
      visible: root.aSolid
      color: root.aPanelFill
      radius: root.aPanelRadius > 0 ? root.aPanelRadius : Style.cornerRadius
      z: -1
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // While the process search has focus, keys belong to it.
      blocked: root.searchActive

      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.cycleTab(dx)
        else if (dy !== 0) root.scrollBy(dy)
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        var digit = parseInt(text, 10)
        if (isFinite(digit) && digit >= 1 && digit <= root.moduleTabs.length) {
          root.showTab(root.moduleTabs[digit - 1])
          return
        }
        if (text === "r") root.refresh()
        if (text === "," || text === "s") root.showTab("settings")
        if (text === "/") root.focusSearch()
      }

      UI.PanelHeader {
        id: tabs
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        // No title bar on the Overview. The pane is five tiles and a Settings
        // button; a header saying "omarcat" over them is a row of chrome
        // telling you the name of the thing you just clicked. Control Center
        // does not have one either. The module pages keep it, because there
        // the back chevron is the only way out.
        visible: root.currentTab !== "overview"
        height: visible ? implicitHeight : 0
        title: Model.moduleDef(root.currentTab).label
        subtitle: hw.modelOf(root.hwKeyForTab[root.currentTab] || "")
        canGoBack: root.currentTab !== "overview"
        foreground: root.fg
        fontFamily: root.fontFamily
        onBackRequested: root.showTab("overview")
        onSettingsRequested: root.showTab(root.currentTab === "settings" ? "overview" : "settings")
      }

      Text {
        id: statusLine
        anchors.top: tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        textFormat: Text.PlainText
        readonly property string message: {
          if (!root.service) return "The Omarcat service is not loaded — re-enable the plugin."
          if (!root.service.ready) return "Starting the sampler…"
          return root.service.samplerError ? "Sampler: " + root.service.samplerError : ""
        }
        visible: message !== ""
        height: visible ? implicitHeight + Style.space(10) : 0
        verticalAlignment: Text.AlignBottom
        text: message
        color: root.fg
        opacity: 0.6
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      ScrollView {
        id: scrollArea
        anchors.top: statusLine.bottom
        anchors.topMargin: root.pageGap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: pageLoader.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Binding {
          target: scrollArea.contentItem
          property: "interactive"
          value: pageLoader.implicitHeight > scrollArea.height
        }

        Loader {
          id: pageLoader
          width: scrollArea.availableWidth
          active: root.opened || panel.visible
          source: Qt.resolvedUrl("ui/" + Model.pageFile(root.currentTab))
        }

        Binding { target: pageLoader.item; property: "service"; value: root.service; when: pageLoader.status === Loader.Ready }
        Binding { target: pageLoader.item; property: "settings"; value: root.settings; when: pageLoader.status === Loader.Ready }
        Binding { target: pageLoader.item; property: "host"; value: root; when: pageLoader.status === Loader.Ready && pageLoader.item && pageLoader.item.hasOwnProperty("host") }
        Binding { target: pageLoader.item; property: "temperatureUnit"; value: root.temperatureUnit; when: pageLoader.status === Loader.Ready }
        Binding { target: pageLoader.item; property: "publicIpEnabled"; value: root.publicIpEnabled; when: pageLoader.status === Loader.Ready }
        Binding { target: pageLoader.item; property: "foreground"; value: root.fg; when: pageLoader.status === Loader.Ready }
        Binding { target: pageLoader.item; property: "fontFamily"; value: root.fontFamily; when: pageLoader.status === Loader.Ready }
      }
    }
  }
}
