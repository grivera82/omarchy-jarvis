import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// The listening bubble at the bottom of the focused monitor: live mic level
// while you talk, what was heard while it thinks, then the result. It never
// takes input (empty mask), so it can't get in the way of clicks.
PanelWindow {
  id: win

  required property var modelData
  property var service: null

  screen: modelData

  readonly property var st: service ? service.state : ({})
  readonly property string status: service ? service.status : "idle"
  readonly property bool wanted: !!service && service.overlayShown && modelData.name === service.focusedScreen
  readonly property bool failed: !service || !service.busy ? !!st.error : false

  readonly property color fg: Color.popups.text
  readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.62)
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent

  anchors.bottom: true
  margins.bottom: Style.space(56)
  implicitWidth: Style.space(620)
  implicitHeight: Style.space(110)
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "grivera-jarvis"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}

  visible: card.opacity > 0.01

  function quoted(s) { return s ? "“" + s + "”" : "" }

  function primary() {
    if (status === "listening") return "Listening…"
    if (status === "transcribing") return "…"
    if (status === "thinking" || status === "acting") return quoted(st.heard)
    if (status === "speaking") return st.reply || ""
    if (st.error) return st.error
    if (st.reply) return st.reply
    if ((st.done || []).length) return st.done.join(", ")
    return quoted(st.heard)
  }

  function secondary() {
    if (status === "listening") return st.pending ? st.pending
      : st.samples > 0 ? "Test recording · " + st.samples + " left, nothing will run"
      : "Speak now · press again to stop"
    if (status === "transcribing") return "Recognizing"
    if (status === "thinking") return "Thinking"
    if (status === "acting") return "Working on it"
    if (status === "speaking") return quoted(st.heard)
    return quoted(st.heard)
  }

  Rectangle {
    id: card
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: win.wanted ? 0 : -Style.space(10)
    width: Math.min(parent.width, Math.max(Style.space(260), textCol.implicitWidth + indicator.width + Style.space(52)))
    height: Math.max(Style.space(54), textCol.implicitHeight + Style.space(22))
    radius: Math.min(height / 2, Style.space(27))
    color: Color.popups.background
    border.color: win.failed ? win.urgent : Color.popups.border
    border.width: Math.max(1, Style.space(2))
    opacity: win.wanted ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on anchors.bottomMargin { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    Item {
      id: indicator
      anchors.left: parent.left
      anchors.leftMargin: Style.space(18)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(34)
      height: Style.space(26)

      // Mic level (listening) or a gentle wave (speaking).
      Row {
        anchors.centerIn: parent
        spacing: Style.space(3)
        visible: win.status === "listening" || win.status === "speaking"

        Repeater {
          model: 5
          Rectangle {
            required property int index
            readonly property real shape: [0.55, 0.8, 1.0, 0.8, 0.55][index]
            property real wave: 0.3
            width: Style.space(4)
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            height: Math.max(width, indicator.height * shape *
              (win.status === "listening" ? Math.min(1, 0.18 + (win.service ? win.service.level : 0) * (0.7 + 0.3 * wave)) : wave))
            color: win.accent
            Behavior on height { NumberAnimation { duration: 70 } }

            SequentialAnimation on wave {
              running: win.visible && (win.status === "listening" || win.status === "speaking")
              loops: Animation.Infinite
              NumberAnimation { to: 0.95; duration: 260 + index * 70; easing.type: Easing.InOutSine }
              NumberAnimation { to: 0.3; duration: 260 + index * 70; easing.type: Easing.InOutSine }
            }
          }
        }
      }

      // Thinking dots.
      Row {
        anchors.centerIn: parent
        spacing: Style.space(5)
        visible: win.status === "transcribing" || win.status === "thinking" || win.status === "acting"

        Repeater {
          model: 3
          Rectangle {
            required property int index
            property real lift: 0
            width: Style.space(6)
            height: width
            radius: width / 2
            color: win.accent
            opacity: 0.45 + lift * 0.55
            transform: Translate { y: -lift * Style.space(5) }

            SequentialAnimation on lift {
              running: parent.visible && win.visible
              loops: Animation.Infinite
              PauseAnimation { duration: index * 140 }
              NumberAnimation { to: 1; duration: 260; easing.type: Easing.OutSine }
              NumberAnimation { to: 0; duration: 260; easing.type: Easing.InSine }
              PauseAnimation { duration: (2 - index) * 140 + 120 }
            }
          }
        }
      }

      // Result mark.
      Text {
        anchors.centerIn: parent
        visible: !win.service || !win.service.busy
        textFormat: Text.PlainText
        text: String.fromCodePoint(win.failed ? 0xF0026 : 0xF05DD)
        color: win.failed ? win.urgent : win.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.display
      }
    }

    Column {
      id: textCol
      anchors.left: indicator.right
      anchors.leftMargin: Style.space(14)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(22)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        width: Math.min(implicitWidth, Style.space(500))
        textFormat: Text.PlainText
        text: win.primary()
        color: win.failed ? win.urgent : win.fg
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
        elide: Text.ElideRight
        maximumLineCount: 2
        wrapMode: Text.WordWrap
      }

      Text {
        visible: text !== ""
        width: Math.min(implicitWidth, Style.space(500))
        textFormat: Text.PlainText
        text: win.secondary()
        color: win.dim
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
  }
}
