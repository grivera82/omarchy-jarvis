import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Owns the single `jarvis daemon` process (microphone, speech recognition,
// Claude planning, text-to-speech) and the listening bubble shown on the
// focused monitor. Keybindings reach the daemon through `jarvis press/release`
// over its socket; bar widgets reach it through send().
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string cli: String(Qt.resolvedUrl("bin/jarvis")).replace(/^file:\/\//, "")

  property var state: ({ status: "starting" })
  property real level: 0
  property string lastError: ""
  property int serial: 0

  readonly property bool running: daemon.running
  readonly property string status: state.status || "starting"
  readonly property var config: state.config || ({})
  readonly property var history: state.history || []
  readonly property var ready: state.ready || ({})
  readonly property bool needsSetup: !!state.ready && !(ready.libs && ready.kokoro && (ready.stt || []).length > 0)
  readonly property bool busy: ["listening", "transcribing", "thinking", "acting", "speaking"].indexOf(status) >= 0

  // The bubble stays up a moment after a turn ends so you can read the result.
  property bool lingering: false
  readonly property bool overlayShown: config.overlay !== false && (busy || lingering)
  readonly property string focusedScreen: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""

  property int lastTurn: -1
  onStateChanged: {
    var t = state.turn || 0
    if (lastTurn >= 0 && t !== lastTurn) {
      linger.interval = state.error ? 5000 : (state.reply || (state.done || []).length) ? 3500 : 1800
      lingering = true
      linger.restart()
    }
    lastTurn = t
  }

  onStatusChanged: if (status !== "listening") level = 0

  function send(cmd, args) {
    if (!daemon.running) return false
    daemon.write(JSON.stringify(Object.assign({ cmd: cmd, id: ++serial }, args || {})) + "\n")
    return true
  }

  function setConfig(key, value) { var a = {}; a[key] = value; return send("config", a) }
  function toggle() { return send("toggle") }
  function cancel() { return send("cancel") }
  function ask(text) { return text ? send("ask", { text: text }) : false }

  function handleLine(line) {
    var msg
    try { msg = JSON.parse(line) } catch (e) { return }
    if (msg.type === "level") {
      root.level = root.level * 0.4 + (msg.level || 0) * 0.6
    } else if (msg.type === "state") {
      root.state = msg.state || {}
    } else if (msg.type === "result" && !msg.ok && msg.error) {
      root.lastError = msg.error
      clearError.restart()
    } else if (msg.type === "restart") {
      restart.interval = 500
    } else if (msg.type === "log" && msg.error) {
      console.warn("grivera.jarvis:", msg.error)
    }
  }

  Process {
    id: daemon
    command: [root.cli, "daemon"]
    running: true
    stdinEnabled: true
    stdout: SplitParser { onRead: function(line) { root.handleLine(line) } }
    onRunningChanged: {
      if (running) return
      root.state = Object.assign({}, root.state, { status: "stopped" })
      restart.restart()
    }
  }

  Timer {
    id: restart
    interval: 10000
    onTriggered: { daemon.running = true; interval = 10000 }
  }

  Timer {
    id: clearError
    interval: 8000
    onTriggered: root.lastError = ""
  }

  Timer {
    id: linger
    onTriggered: root.lingering = false
  }

  Variants {
    model: Quickshell.screens
    Overlay {
      service: root
    }
  }
}
