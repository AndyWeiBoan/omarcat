import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "ui" as UI

// Bar entry point. One instance per bar per monitor; every instance shares
// the single OmaStatsService for data and opens its own popup panel.
Panel {
  id: root
  moduleName: "io.github.andyweiboan.omarcat"
  ipcTarget: ""

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
    foreground: Color.bar.text
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
    contentWidth: panel.fittedContentWidth(Style.space(380))
    // Grow with the page; KeyboardPanel caps this at the screen, which is the
    // only point at which the page scrolls.
    contentHeight: panel.fittedContentHeight(
      tabs.height + Style.space(10) + statusLine.height + pageLoader.implicitHeight)

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
        title: root.currentTab === "overview" ? "omarcat" : Model.moduleDef(root.currentTab).label
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
        anchors.topMargin: Style.space(10)
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
