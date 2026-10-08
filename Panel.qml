import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Ui
import qs.Commons

// Jarvis panel. Listening, recognition and acting live in the daemon
// (Service.qml); this widget shows its state, recent requests and settings.
Panel {
  id: root
  moduleName: "grivera.jarvis"
  ipcTarget: "grivera.jarvis"

  readonly property var svc: root.bar && root.bar.shell ? root.bar.shell.serviceFor("grivera.jarvis") : null
  readonly property var st: svc ? svc.state : ({})
  readonly property string status: svc ? svc.status : "starting"
  readonly property var config: svc ? svc.config : ({})
  readonly property var history: svc ? svc.history : []
  readonly property bool busy: svc ? svc.busy : false
  readonly property bool needsSetup: svc ? svc.needsSetup : false

  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(fg, 1.4)
  readonly property color urgent: root.bar ? root.bar.urgent : Color.urgent
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  readonly property string glyph: String.fromCodePoint(0xF05DD)

  property real pulse: 1
  SequentialAnimation on pulse {
    running: root.busy
    loops: Animation.Infinite
    alwaysRunToEnd: true
    NumberAnimation { to: 0.45; duration: 600; easing.type: Easing.InOutSine }
    NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function label(s) {
    return ({
      starting: "Starting", stopped: "Backend stopped", idle: "Ready", listening: "Listening",
      transcribing: "Recognizing", thinking: "Thinking", acting: "Working", speaking: "Speaking",
      setup: "Setting up"
    })[s] || s
  }

  function summary() {
    if (!svc) return "SERVICE NOT LOADED"
    if (svc.lastError) return svc.lastError.toUpperCase()
    if (needsSetup && status !== "setup") return "SETUP NEEDED"
    if (status === "idle") return "READY · PRESS THE COPILOT KEY"
    return label(status).toUpperCase()
  }

  function clock(t) { return Qt.formatTime(new Date(t * 1000), "h:mm ap") }

  function talk() { if (svc) svc.toggle() }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph
    active: root.busy
    opacity: (root.needsSetup ? 0.5 : 1) * (root.busy ? root.pulse : 1)
    tooltipText: root.busy ? root.label(root.status) : "Jarvis · right-click to talk"
    onPressed: function(b) {
      if (b === Qt.RightButton) root.talk()
      else if (b === Qt.MiddleButton && root.svc) root.svc.cancel()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(720))

    onOpenChanged: if (open && root.svc) root.svc.send("refresh")

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "t" || t === " ") root.talk()
        else if (t === "/") input.forceActiveFocus()
      }

      Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: column
          width: parent.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "Jarvis"
            meta: root.summary()
            foreground: root.fg
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                textFormat: Text.PlainText
                text: root.glyph
                color: root.busy ? Color.accent : root.dim
                opacity: root.busy ? root.pulse : 1
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          // ---------- setup ----------
          Column {
            visible: root.needsSetup || root.status === "setup"
            width: parent.width
            spacing: Style.space(8)

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.status === "setup"
                ? (root.st.setup || "Working…")
                : "Jarvis needs its speech models: faster-whisper to understand you and Kokoro to talk back. They run on this laptop and take about 1.5 GB."
              color: root.status === "setup" ? Color.accent : root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            Button {
              visible: root.status !== "setup"
              text: "Set up"
              foreground: root.fg
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              bordered: true
              onClicked: if (root.svc) root.svc.send("setup")
            }
          }

          // ---------- ask ----------
          Row {
            visible: !root.needsSetup
            width: parent.width
            spacing: Style.space(8)

            TextField {
              id: input
              width: parent.width - talkButton.width - parent.spacing
              placeholderText: "Type a request, or press the Copilot key"
              foreground: root.fg
              font.family: root.fontFamily
              onAccepted: {
                if (root.svc && text.trim()) root.svc.ask(text.trim())
                text = ""
              }
              Keys.onEscapePressed: { text = ""; keyCatcher.forceActiveFocus() }
            }

            Button {
              id: talkButton
              anchors.verticalCenter: input.verticalCenter
              text: root.status === "listening" ? "Done" : root.busy ? "Stop" : "Talk"
              tooltipText: root.status === "listening" ? "Stop listening and act on it" : root.busy ? "Cancel" : "Start listening (t)"
              foreground: root.fg
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              bordered: true
              onClicked: {
                if (!root.svc) return
                if (root.busy && root.status !== "listening") root.svc.cancel()
                else root.talk()
              }
            }
          }

          // ---------- current / last turn ----------
          Column {
            visible: !!(root.st.heard || root.st.reply || root.st.error || root.st.pending)
            width: parent.width
            spacing: Style.space(4)

            Text {
              visible: !!root.st.heard
              width: parent.width
              textFormat: Text.PlainText
              text: "“" + (root.st.heard || "") + "”"
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              wrapMode: Text.WordWrap
            }

            Text {
              visible: text !== ""
              width: parent.width
              textFormat: Text.PlainText
              text: root.st.error || root.st.reply || ((root.st.done || []).join(", "))
              color: root.st.error ? root.urgent : root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            Text {
              readonly property var tm: root.st.timing || ({})
              visible: text !== ""
              width: parent.width
              textFormat: Text.PlainText
              text: [({ claude: "Claude", quick: "built-in", remembered: "remembered", phrase: "your phrase", codex: "Codex" })[root.st.via] || "",
                     tm.stt ? "heard in " + tm.stt + " s" : "",
                     tm.think ? "planned in " + tm.think + " s" : ""].filter(function(x) { return !!x }).join("  ·  ")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Row {
              visible: !!root.st.pending
              spacing: Style.space(8)
              topPadding: Style.space(4)

              Button {
                text: "Yes, do it"
                foreground: root.fg
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                bordered: true
                onClicked: if (root.svc) root.svc.send("confirm", { yes: true })
              }
              Button {
                text: "No"
                foreground: root.fg
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                bordered: true
                onClicked: if (root.svc) root.svc.send("confirm", { yes: false })
              }
            }
          }

          // ---------- history ----------
          Column {
            visible: root.history.length > 0
            width: parent.width
            spacing: Style.space(6)

            PanelSeparator { foreground: root.fg }
            PanelSectionHeader { text: "RECENT"; foreground: root.fg; fontFamily: root.fontFamily }

            Repeater {
              model: root.history.slice(0, 8)

              Item {
                required property var modelData
                width: column.width
                implicitHeight: entry.implicitHeight + Style.space(4)

                Column {
                  id: entry
                  width: parent.width
                  spacing: Style.space(1)

                  Item {
                    width: parent.width
                    implicitHeight: heardText.implicitHeight

                    Text {
                      id: heardText
                      anchors.left: parent.left
                      anchors.right: whenText.left
                      anchors.rightMargin: Style.space(10)
                      textFormat: Text.PlainText
                      text: modelData.heard
                      color: root.fg
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      elide: Text.ElideRight
                    }

                    Text {
                      id: whenText
                      anchors.right: parent.right
                      anchors.baseline: heardText.baseline
                      textFormat: Text.PlainText
                      text: root.clock(modelData.t) + (({ claude: "  ·  Claude", remembered: "  ·  remembered", phrase: "  ·  your phrase" })[modelData.via] || "")
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  Text {
                    width: parent.width
                    visible: text !== ""
                    textFormat: Text.PlainText
                    text: [modelData.reply, (modelData.done || []).join(", ")].filter(function(x) { return !!x }).join("  —  ")
                    color: modelData.ok === false ? root.urgent : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }
              }
            }
          }

          // ---------- couldn't do ----------
          Column {
            readonly property var items: root.st.missed || []
            visible: items.length > 0
            width: parent.width
            spacing: Style.space(6)

            PanelSeparator { foreground: root.fg }
            PanelSectionHeader { text: "COULDN'T DO"; foreground: root.fg; fontFamily: root.fontFamily }

            Repeater {
              model: parent.items

              Column {
                required property var modelData
                width: column.width
                spacing: Style.space(1)

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: "\u201c" + modelData.heard + "\u201d"
                  color: root.fg
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                }
                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: root.clock(modelData.t) + "  \u00b7  " + modelData.why
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }
            }

            Button {
              text: "Clear list"
              foreground: root.fg
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              bordered: true
              onClicked: if (root.svc) root.svc.send("clear_missed")
            }
          }

          // ---------- settings ----------
          Column {
            visible: !root.needsSetup
            width: parent.width
            spacing: Style.space(8)

            PanelSeparator { foreground: root.fg }
            PanelSectionHeader { text: "SPOKEN REPLIES"; foreground: root.fg; fontFamily: root.fontFamily }

            ButtonGroup {
              options: [
                { value: "auto", label: "When useful", tooltip: "Answers, questions and errors; a chime for everything else" },
                { value: "always", label: "Always", tooltip: "Also says what it did" },
                { value: "off", label: "Off", tooltip: "Chimes and the on-screen bubble only" }
              ]
              value: root.config.speak || "auto"
              foreground: root.fg
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              focusable: false
              onChanged: function(v) { if (root.svc) root.svc.setConfig("speak", v) }
            }

            Item {
              width: parent.width
              implicitHeight: voicePick.implicitHeight

              Dropdown {
                id: voicePick
                anchors.left: parent.left
                anchors.right: previewButton.left
                anchors.rightMargin: Style.space(8)
                label: "Voice"
                value: root.config.voice || "af_heart"
                options: root.st.voices || []
                foreground: root.fg
                fontFamily: root.fontFamily
                onChanged: function(v) {
                  if (!root.svc) return
                  root.svc.setConfig("voice", v)
                  root.svc.send("say", { text: "Hi, this is how I sound.", voice: v })
                }
              }

              Button {
                id: previewButton
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: "Preview"
                foreground: root.fg
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                bordered: true
                onClicked: if (root.svc) root.svc.send("say", { text: "Hi, this is how I sound." })
              }
            }

            Column {
              readonly property var sp: root.st.spotify || ({})
              visible: !!sp.installed
              width: parent.width
              spacing: Style.space(6)

              PanelSectionHeader { text: "SPOTIFY"; foreground: root.fg; fontFamily: root.fontFamily }

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: parent.sp.connected ? "Connected. \u201cPlay Radiohead\u201d, \u201cplay my workout playlist\u201d and \u201cplay my liked songs\u201d play in Spotifast."
                  : parent.sp.connecting ? "Approve the sign-in in your browser\u2026"
                  : !parent.sp.app ? "Add a personal Spotify app in Spotifast (Settings, Account) to play music by name."
                  : "Connect once so you can play music by name. Uses your Spotifast app; playback stays in Spotifast."
                color: parent.sp.error ? root.urgent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              Text {
                visible: !!parent.sp.error
                width: parent.width
                textFormat: Text.PlainText
                text: parent.sp.error || ""
                color: root.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              Button {
                visible: !!parent.sp.app && !parent.sp.connecting
                text: parent.sp.connected ? "Reconnect Spotify" : "Connect Spotify"
                foreground: root.fg
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                bordered: true
                onClicked: if (root.svc) root.svc.send("spotify_login")
              }
            }

            PanelSectionHeader { text: "YOUR PHRASES & LEARNED REQUESTS"; foreground: root.fg; fontFamily: root.fontFamily }

            Text {
              readonly property var ph: root.st.phrases || ({})
              width: parent.width
              textFormat: Text.PlainText
              text: ph.error ? ph.error
                : (ph.count || 0) + " phrase" + ((ph.count || 0) === 1 ? "" : "s") + " of your own, and "
                  + (root.st.learned || 0) + " request" + ((root.st.learned || 0) === 1 ? "" : "s")
                  + " learned from Claude (those run instantly next time), "
                  + (root.st.corrections || 0) + " mishearing" + ((root.st.corrections || 0) === 1 ? "" : "s") + " corrected and "
                  + (root.st.vocab || 0) + " name" + ((root.st.vocab || 0) === 1 ? "" : "s") + " picked up for recognition."
              color: ph.error ? root.urgent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Row {
              spacing: Style.space(8)

              Button {
                text: "Edit phrases"
                tooltipText: "Opens phrases.toml in your editor; saved changes apply right away"
                foreground: root.fg
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                bordered: true
                onClicked: if (root.svc) root.svc.send("edit_phrases")
              }
              Button {
                visible: (root.st.learned || 0) + (root.st.corrections || 0) + (root.st.vocab || 0) > 0
                text: "Forget learned"
                tooltipText: "Forgets learned requests, corrected mishearings and picked-up names"
                foreground: root.fg
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                bordered: true
                onClicked: if (root.svc) root.svc.send("forget_learned")
              }
            }

            PanelSectionHeader { text: "RECOGNITION"; foreground: root.fg; fontFamily: root.fontFamily }

            ButtonGroup {
              options: [
                { value: "base.en", label: "Fast", tooltip: "Whisper base.en: about 0.3 s, a little less accurate" },
                { value: "small.en", label: "Accurate", tooltip: "Whisper small.en: about 0.7 s" }
              ]
              value: root.config.sttModel || "small.en"
              foreground: root.fg
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              focusable: false
              onChanged: function(v) { if (root.svc) root.svc.setConfig("sttModel", v) }
            }

            Toggle {
              width: parent.width
              label: "Instant start"
              description: "Keeps the microphone open and holds only the last second in memory, so a word said as you press the key isn't lost. Nothing is saved or transcribed until you press it, but the mic shows as in use."
              foreground: root.fg
              fontFamily: root.fontFamily
              checked: root.config.instantStart === true
              onClicked: if (root.svc) root.svc.setConfig("instantStart", !checked)
            }

            Toggle {
              width: parent.width
              label: "Sounds"
              description: "A chime the moment the microphone is actually recording (start talking after it), when it stops, and when it's done."
              foreground: root.fg
              fontFamily: root.fontFamily
              checked: root.config.sounds !== false
              onClicked: if (root.svc) root.svc.setConfig("sounds", !checked)
            }

            Toggle {
              width: parent.width
              label: "Pause music while listening"
              description: "Anything playing through MPRIS pauses, then resumes when it's done."
              foreground: root.fg
              fontFamily: root.fontFamily
              checked: root.config.pauseMedia !== false
              onClicked: if (root.svc) root.svc.setConfig("pauseMedia", !checked)
            }

            Toggle {
              width: parent.width
              label: "Listen for an answer"
              description: "When it asks you something, the microphone opens again for a few seconds."
              foreground: root.fg
              fontFamily: root.fontFamily
              checked: root.config.followUp !== false
              onClicked: if (root.svc) root.svc.setConfig("followUp", !checked)
            }

            Toggle {
              width: parent.width
              label: "On-screen bubble"
              description: "Shows what it heard and what it did at the bottom of the screen."
              foreground: root.fg
              fontFamily: root.fontFamily
              checked: root.config.overlay !== false
              onClicked: if (root.svc) root.svc.setConfig("overlay", !checked)
            }

            Text {
              width: parent.width
              topPadding: Style.space(4)
              textFormat: Text.PlainText
              text: "Tap the Copilot key and speak, or hold it while you talk. Simple commands run instantly; anything else goes to Claude ("
                + (root.config.claudeModel || "haiku") + ") through your Claude Code login."
                + (root.st.claude === false ? " Claude Code isn't installed, so only the built-in commands work." : "")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Button {
              visible: root.history.length > 0
              text: "Clear history"
              foreground: root.fg
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              bordered: true
              onClicked: if (root.svc) root.svc.send("clear_history")
            }
          }

          Item { width: parent.width; height: Style.space(2) }
        }
      }
    }
  }
}
