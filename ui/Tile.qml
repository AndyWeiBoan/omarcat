import QtQuick
import qs.Commons
import "../Model.js" as Model

// One Control Center tile: a badge, a name, a figure, and at most one more
// thing -- a footnote or a graph, never both.
//
// This replaces the row-per-subsystem list the Overview used to be. The rows
// were not wrong, they were just a LIST, and a list invites one more column:
// the old row carried a title, a subtitle, a value, a capacity bar and a
// detail line of three or four figures, which is five channels for a surface
// you are meant to glance at. A tile has room for two and no room for a fifth,
// so the question "does this belong" gets asked by the layout instead of by
// whoever is editing it.
//
// The badge carries no colour, exactly as OverviewRow's did: in macOS a
// coloured icon means STATE (Wi-Fi is blue because it is on), not category.
// Saturated per-subsystem badges are System Settings' language, where a
// full-height sidebar needs them to be told apart; a five-tile pane does not.
Item {
  id: root

  property string target: ""
  property string title: ""
  property string icon: ""
  property string iconFont: ""
  property string value: ""
  property string unit: ""
  // The part, under the name. Like `foot`, an empty one still reserves its
  // line: two tiles sharing a Grid row are only the same height while they
  // have the same shape, and the Battery has no part number to show.
  property string caption: ""
  // The one extra fact. Empty still reserves its line, which is what keeps two
  // tiles side by side the same height without either of them being told what
  // the other contains.
  property string foot: ""

  // A graph instead of a footnote, for the tile that gets the full width.
  property var series: null
  property color seriesColor: Color.accent
  property real seriesCeiling: 100
  // How many samples the history will hold once it is full. The strip sizes
  // its bars to that, not to the default 2px+1px pitch: at a five-second
  // refresh the service keeps sixty samples, which at the default pitch draws
  // a third of the way across and leaves the tile looking broken for the four
  // minutes before anyone realises it is simply not full yet. 0 keeps the
  // component's own pitch.
  property int seriesSlots: 0

  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family
  // The same figure as the gap between tiles and the panel's own inset. See
  // OmaStatsWidget.themeEdge for why all three are one number.
  property real padding: Style.space(12)
  // 只讀的一列（風扇）：名稱和數值同一行，沒有大數字、沒有 chevron。
  property bool compact: false
  property color cardFill: "transparent"
  property real cardMaxRadius: 0
  // See OmaStatsWidget.themeInkDepth. 1.0 = Model.INK untouched.
  property real inkDepth: 1.0
  function ink(level) { return 1 - root.inkDepth * (1 - level) }

  signal drillRequested(string id)

  readonly property real badgeSize: Style.space(20)
  readonly property bool hasGraph: Array.isArray(series)

  // Two tiles sharing a row have to be the same height, and the taller one is
  // whichever has the taller content -- which neither of them knows. So the
  // row measures both and hands the answer back as `minHeight`. That only
  // works if the measurement itself cannot be affected by the answer, hence
  // the split: `naturalHeight` is what the content wants, `implicitHeight` is
  // what the tile ends up being. Binding a row off `implicitHeight` instead
  // would be a loop.
  readonly property real naturalHeight: card.implicitHeight
  property real minHeight: 0

  implicitHeight: Math.max(naturalHeight, minHeight)
  height: implicitHeight

  Card {
    id: card
    // Explicit: a tile is a share of a row, and Card's own binding would take
    // the whole row's width instead.
    width: root.width
    height: root.height
    fill: root.cardFill
    maxRadius: root.cardMaxRadius
    foreground: root.foreground
    padding: root.padding
    spacing: Style.space(4)

    Row {
      width: parent.width
      spacing: Style.space(7)

      Rectangle {
        visible: root.icon !== ""
        width: root.badgeSize
        height: root.badgeSize
        radius: width / 2
        color: Util.alpha(root.foreground, 0.11)
        // On the middle of the whole block, not of the name: with a part
        // number under it the badge belongs to both lines. Control Center's
        // own two-line tiles centre their orb the same way.
        anchors.verticalCenter: head.verticalCenter

        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: root.icon
          color: Util.alpha(root.foreground, root.ink(Model.INK.label))
          font.family: root.iconFont !== "" ? root.iconFont : root.fontFamily
          font.pixelSize: Math.round(root.badgeSize * 0.58)
        }
      }

      // 標題列：徽章、名稱，右端一個 chevron 表示可以進去。
      // 型號不放在這裡 —— 設計稿把它擺在卡片底部當註腳（見下面的 footText），
      // 那一行才是「關於這個東西的補充」，放在標題下會跟標題爭同一個位置。
      Item {
        id: head
        width: parent.width - (root.icon !== "" ? root.badgeSize + parent.spacing : 0)
        height: name.implicitHeight

        Text {
          id: name
          textFormat: Text.PlainText
          anchors.left: parent.left
          width: root.compact ? implicitWidth : undefined
          anchors.right: root.compact ? undefined
            : (chevron.visible ? chevron.left : parent.right)
          anchors.rightMargin: (!root.compact && chevron.visible) ? Style.space(4) : 0
          anchors.verticalCenter: parent.verticalCenter
          text: root.title
          color: root.foreground
          opacity: root.ink(Model.INK.label)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        // compact 時數值跟名稱同一行。
        Text {
          id: inlineValue
          visible: root.compact
          anchors.left: name.right
          anchors.leftMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: root.value + (root.unit !== "" ? " " + root.unit : "")
          color: root.foreground
          opacity: root.ink(Model.INK.label)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          id: chevron
          visible: root.target !== "" && !root.compact
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: "\u203A"
          color: root.foreground
          opacity: root.ink(Model.INK.tertiary)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }

    // The figure, in a box cut down to roughly its cap height. A Text at this
    // size carries about a third of its line box as leading, nearly all of it
    // under the baseline, which on a tile reads as the number having drifted
    // upwards and left a hole under it. Clipping the box is safe here because
    // nothing in a tile descends: these are digits and a unit.
    Item {
      width: parent.width
      visible: !root.compact
      height: visible ? Math.round(Style.font.displayLarge * 1.05) : 0

      // 設計稿把折線擺在數值的右邊、同一個高度帶上，不是壓在卡片底部。
      HistoryGraph {
        id: strip
        visible: root.hasGraph
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(parent.width * 0.52)
        height: Math.round(parent.height * 0.62)
        series: root.hasGraph ? [root.series] : []
        colors: [root.seriesColor]
        ceiling: root.seriesCeiling
        line: true
        showBaseline: false
      }

      Measure {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        value: root.value
        unit: root.unit
        foreground: root.foreground
        fontFamily: root.fontFamily
        valueSize: Style.font.displayLarge
        unitSize: Style.font.bodySmall
        unitOpacity: root.ink(Model.INK.secondary)
      }
    }

    // 卡片底部的註腳。設計稿每一張卡片都有一行：處理器是型號與溫度、記憶體
    // 是「壓力正常・共 16 GB」。型號（caption）優先，沒有才用 foot。
    Text {
      id: footText
      visible: text !== "" && !root.compact
      textFormat: Text.PlainText
      width: parent.width
      text: root.caption !== "" ? root.caption : root.foot
      color: root.foreground
      opacity: root.ink(Model.INK.tertiary)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }

  }

  HoverHandler {
    id: hover
    enabled: root.target !== ""
    cursorShape: Qt.PointingHandCursor
  }

  TapHandler {
    enabled: root.target !== ""
    onTapped: root.drillRequested(root.target)
  }

  // Above the card rather than under its content: at 5% the tint is below the
  // threshold where it reads on the text, and putting it under the fill would
  // hide it entirely.
  Rectangle {
    anchors.fill: card
    radius: card.radius
    color: Util.alpha(root.foreground, 0.05)
    opacity: hover.hovered ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 110 } }
  }
}
