import QtQuick
import qs.Commons

// iStat-style bar history: one thin vertical bar per sample, newest at the
// right, stacked bottom-to-top when several series are given. Bars are
// snapped to device pixels so 1px marks stay crisp on fractional scales.
Canvas {
  id: root

  property var series: []
  property var colors: []
  property real ceiling: 0        // 0 = auto-scale to the visible window
  property real floor: 1          // minimum auto ceiling, keeps idle noise flat
  property real headroom: 1.06
  property int barWidth: 2
  property int gap: 1
  property bool showBaseline: true
  // 折線模式。設計稿的處理器卡用的是一條細折線，不是長條 —— 長條在滿格前
  // 會留一大片空白，看起來像圖表壞掉。
  property bool line: false
  property real lineWidth: 1.5
  property color baselineColor: Util.alpha(Color.popups.text, 0.14)

  readonly property int pitch: Math.max(1, barWidth + gap)
  readonly property int capacity: Math.max(1, Math.floor((width + gap) / pitch))

  antialiasing: false
  renderStrategy: Canvas.Cooperative

  onSeriesChanged: requestPaint()
  onColorsChanged: requestPaint()
  onCeilingChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onBaselineColorChanged: requestPaint()
  onVisibleChanged: if (visible) requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.clearRect(0, 0, width, height)
    if (width <= 0 || height <= 0) return

    var dpr = (Screen && Screen.devicePixelRatio) ? Screen.devicePixelRatio : 1
    var snap = function(v) { return Math.round(v * dpr) / dpr }
    var list = Array.isArray(root.series) ? root.series : []
    var count = list.length
    var n = root.capacity
    var len = 0
    for (var s = 0; s < count; s++) if (list[s] && list[s].length > len) len = list[s].length

    var baseH = root.showBaseline ? 1 : 0
    var usable = Math.max(1, height - baseH)
    var max = Number(root.ceiling)
    if (!(max > 0)) {
      max = Math.max(0.000001, Number(root.floor) || 0)
      for (var i = Math.max(0, len - n); i < len; i++) {
        var sum = 0
        for (var k = 0; k < count; k++) sum += Number(list[k] ? list[k][i] : 0) || 0
        if (sum > max) max = sum
      }
      max *= root.headroom
    }

    if (root.line) {
      // **折線把現有的樣本攤滿整個寬度**，不像長條那樣預留格位。長條預留是
      // 為了讓「還沒存滿」看得出來；但一條只畫在右端一小截的折線，看起來
      // 就只是壞掉。折線要表達的是形狀，不是進度。
      var pts = []
      var first = Math.max(0, len - n)
      var avail = len - first
      var step = avail > 1 ? width / (avail - 1) : width
      for (var lb = 0; lb < avail; lb++) {
        var lv = Number(list[0] ? list[0][first + lb] : 0) || 0
        pts.push([lb * step, height - baseH - Math.min(usable, lv / max * usable)])
      }
      if (pts.length > 1) {
        ctx.strokeStyle = root.colors[0] || Color.accent
        ctx.lineWidth = Math.max(1 / dpr, root.lineWidth)
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.beginPath()
        ctx.moveTo(pts[0][0], pts[0][1])
        for (var lp = 1; lp < pts.length; lp++) ctx.lineTo(pts[lp][0], pts[lp][1])
        ctx.stroke()
      }
      return
    }

    for (var b = 0; b < n; b++) {
      var idx = len - n + b
      if (idx < 0) continue
      var x = width - (n - b) * root.pitch + root.gap
      var y = height - baseH
      for (var c = 0; c < count; c++) {
        var v = Number(list[c] ? list[c][idx] : 0) || 0
        if (v <= 0) continue
        var h = Math.min(usable, v / max * usable)
        if (h < 1 / dpr) h = 1 / dpr
        var top = snap(y - h)
        var bottom = snap(y)
        if (bottom - top < 1 / dpr) top = bottom - 1 / dpr
        ctx.fillStyle = root.colors[c] || Color.accent
        ctx.fillRect(snap(x), top, Math.max(1 / dpr, snap(root.barWidth)), bottom - top)
        y -= h
      }
    }

    if (root.showBaseline) {
      ctx.fillStyle = root.baselineColor
      ctx.fillRect(0, height - 1, width, 1)
    }
  }
}
