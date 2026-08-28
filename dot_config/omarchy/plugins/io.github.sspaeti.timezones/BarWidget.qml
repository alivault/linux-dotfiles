import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// World-clock pill: a globe icon that expands to the client zones' current
// times on hover; left click opens the worldtimebuddy-style hour grid.
BarWidget {
  id: root
  moduleName: "io.github.sspaeti.timezones"

  // Sanitized because WidgetButton's internal Text uses AutoText, which
  // would rich-text-parse a crafted setting. See README's Configure section
  // for why this glyph rather than the plain earth/globe ones, and for other
  // icon choices.
  readonly property string icon: Model.plainText(setting("icon", "󱉊"))
  readonly property string wtbUrl: setting("worldtimebuddyUrl", "https://www.worldtimebuddy.com/pdt-to-switzerland-bern")

  // Set "hoverExpand": false on the widget entry to keep the pill a static
  // icon — the expansion shifts neighboring bar widgets, which not everyone
  // wants.
  readonly property bool hoverExpand: setting("hoverExpand", true) === true

  // What the right button does: open worldtimebuddy (the default) or flip the
  // widget between 24-hour and AM/PM.
  readonly property string rightClick: String(setting("rightClick", "worldtimebuddy"))

  readonly property string compact: panelLoader.item ? panelLoader.item.compactLabel : ""

  // Hover is tracked on the whole pill, not just the icon button: once the
  // times are out, the pointer is free to travel across them without the
  // pill collapsing out from under it.
  readonly property bool pillHovered: button.tooltipHovered || pillHover.hovered
  readonly property bool expanded: hoverExpand && !vertical && pillHovered && compact !== ""

  // Gap between the icon button and the times, and the padding that keeps the
  // times off the next widget — the button only pads its own glyph.
  readonly property real revealLeadIn: Style.spaceReal(10)
  readonly property real revealTrail: button.scaledHorizontalMargin

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  // A bar surface exists per monitor, so flip every instance — otherwise the
  // format would change on one screen and not the others.
  function toggleHourFormat() {
    broadcast("toggleHourFormatHere")
  }

  function toggleHourFormatHere() {
    if (panelLoader.item && panelLoader.item.toggleHourFormat) panelLoader.item.toggleHourFormat()
  }

  function runRightClick() {
    if (root.rightClick === "toggleHourFormat") root.toggleHourFormat()
    else root.bar.run("omarchy-launch-browser " + Util.shellQuote(root.wtbUrl))
  }

  function handlePress(b) {
    if (!root.bar) return
    if (b === Qt.RightButton) root.runRightClick()
    else if (b === Qt.MiddleButton) root.refresh()
    else root.togglePanel()
  }

  // Shape contract for shell.summon/hide/toggle routing (Bar.findPanelWidget
  // requires open/close/opened on the bar-widget root).
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  // Forwarded so this widget can stand in for the panel as the bar's popout
  // identity: Bar.requestPopout prefers closeForPopoutSwitch over close, and
  // KeyboardPanel reads popoutSwitchClosing back off its owner.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth + reveal.width
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "io.github.sspaeti.timezones"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function refresh(): void { root.refresh() }
    function toggleHourFormat(): void { root.toggleHourFormat() }
  }

  HoverHandler { id: pillHover }

  // The button carries the glyph alone and never changes size. Folding the
  // times into its label instead re-centers the label on every hover, and
  // since the slack a centered label leaves depends on the string being
  // measured, the globe visibly jumps sideways as the times appear.
  WidgetButton {
    id: button
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: button.implicitWidth
    bar: root.bar
    text: root.icon
    tooltipText: ""

    onPressed: function(b) { root.handlePress(b) }
  }

  // The times wipe out from behind the globe rather than appearing at full
  // width, so the widgets downstream of the pill slide instead of jumping.
  Item {
    id: reveal
    anchors.left: button.right
    anchors.verticalCenter: button.verticalCenter
    height: button.height
    visible: !root.vertical
    clip: true

    width: root.expanded ? root.revealLeadIn + times.implicitWidth + root.revealTrail : 0

    Behavior on width {
      NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    Text {
      id: times
      x: root.revealLeadIn
      anchors.verticalCenter: parent.verticalCenter
      text: root.compact
      textFormat: Text.PlainText
      color: root.bar ? root.bar.barForeground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      renderType: Text.NativeRendering
      opacity: root.expanded ? 1 : 0

      Behavior on opacity {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }
    }

    // The revealed times stayed clickable when they were part of the button's
    // label; keep them so.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: function(mouse) { root.handlePress(mouse.button) }
    }
  }
}
