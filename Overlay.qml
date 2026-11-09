import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Flow for Omarchy's recording pill. Sits where Omarchy's OSD sits, uses the
// theme's popup colors, and never takes keyboard focus or clicks, so the
// focused window stays the paste target. flow-omarchy drives it over IPC:
//   omarchy-shell flow recording | processing | info <text> | error <text> | hide
Item {
  id: root

  // idle | recording | processing | message
  property string mode: "idle"
  property string message: ""
  property bool failed: false
  property real startedAt: 0
  property int elapsed: 0
  property var levels: []

  readonly property int barCount: 28
  readonly property int pad: Style.space(14)
  readonly property int gap: Style.space(12)
  readonly property int contentHeight: Style.space(30)
  readonly property int maxMessageWidth: Style.space(560)

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  function resetLevels() {
    var next = []
    for (var i = 0; i < root.barCount; i++) next.push(0)
    root.levels = next
  }

  // Mics differ a lot in background level (this laptop's sits near a third of
  // full scale), so bars are drawn against a moving noise floor and ceiling:
  // silence stays flat and speech fills the bars on any mic.
  property real noiseFloor: -1
  property real ceiling: 0

  function levelFor(peak) {
    var p = peak > 0 ? peak : 0
    if (root.noiseFloor < 0) {
      root.noiseFloor = p
      root.ceiling = p + 0.2
    }
    if (p < root.noiseFloor) root.noiseFloor = p
    else root.noiseFloor += (p - root.noiseFloor) * 0.01
    if (p > root.ceiling) root.ceiling = p
    else root.ceiling -= (root.ceiling - root.noiseFloor) * 0.005
    root.ceiling = Math.max(root.ceiling, root.noiseFloor + 0.2)
    var level = (p - root.noiseFloor - 0.04) / (root.ceiling - root.noiseFloor)
    return Math.max(0, Math.min(1, level))
  }

  function clock(seconds) {
    var m = Math.floor(seconds / 60)
    var s = seconds % 60
    return m + ":" + (s < 10 ? "0" : "") + s
  }

  function clean(text) {
    var value = String(text || "").replace(/\s+/g, " ").trim()
    return value.length > 200 ? value.slice(0, 199) + "…" : value
  }

  function showMessage(text, isError, ms) {
    root.message = root.clean(text)
    root.failed = isError
    root.mode = "message"
    hideTimer.interval = ms
    hideTimer.restart()
  }

  PwObjectTracker { objects: Pipewire.defaultAudioSource ? [Pipewire.defaultAudioSource] : [] }

  PwNodePeakMonitor {
    id: mic
    node: Pipewire.defaultAudioSource
    enabled: root.mode === "recording"
  }

  Timer {
    interval: 50
    repeat: true
    running: root.mode === "recording"
    onTriggered: {
      var next = root.levels.slice(1)
      next.push(root.levelFor(mic.peak))
      root.levels = next
      root.elapsed = Math.floor((Date.now() - root.startedAt) / 1000)
    }
  }

  Timer {
    id: hideTimer
    onTriggered: root.mode = "idle"
  }

  ShellIpc {
    target: "flow"
    function recording(): string {
      hideTimer.stop()
      root.resetLevels()
      root.noiseFloor = -1
      root.startedAt = Date.now()
      root.elapsed = 0
      root.failed = false
      root.mode = "recording"
      return "ok"
    }
    function processing(): string {
      hideTimer.stop()
      root.mode = "processing"
      return "ok"
    }
    function info(text: string): string { root.showMessage(text, false, 1800); return "ok" }
    function error(text: string): string { root.showMessage(text, true, 6000); return "ok" }
    function hide(): string { hideTimer.stop(); root.mode = "idle"; return "ok" }
    function state(): string { return root.mode }
    function ping(): string { return "ok" }
  }

  TextMetrics {
    id: clockMetrics
    font.family: Style.font.family
    font.bold: true
    font.pixelSize: Style.font.body
    text: "00:00"
  }

  OverlayWindow {
    shown: root.mode !== "idle"
    shownKeyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "flow-omarchy"
    // Visual only: an empty input region lets clicks through to the window below.
    mask: Region {}

    BorderSurface {
      id: card
      width: card.borderLeft + root.pad + content.width + root.pad + card.borderRight
      height: card.borderTop + root.pad + root.contentHeight + root.pad + card.borderBottom
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(67)
      color: Util.alpha(Commons.Color.background, 0.97)
      borderSpec: Border.surfaceSpec("popups", "border",
        root.failed ? Commons.Color.urgent : Commons.Color.popups.border, Math.max(1, Style.space(2)))
      radius: Style.cornerRadius

      Item {
        id: content
        x: card.borderLeft + root.pad
        y: card.borderTop + root.pad
        height: root.contentHeight
        width: root.mode === "recording" ? recordingRow.width
          : root.mode === "processing" ? processingRow.width
          : messageRow.width

        // Recording: pulsing dot, live waveform, timer.
        Row {
          id: recordingRow
          visible: root.mode === "recording"
          height: parent.height
          spacing: root.gap

          Rectangle {
            width: Style.space(10)
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: Commons.Color.urgent
            SequentialAnimation on opacity {
              running: root.mode === "recording"
              loops: Animation.Infinite
              NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
              NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
            }
          }

          Row {
            height: parent.height
            spacing: Style.space(2)
            Repeater {
              model: root.barCount
              Rectangle {
                required property int index
                width: Style.space(3)
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                height: Math.max(Style.space(3), root.contentHeight * (root.levels[index] || 0))
                color: Commons.Color.popups.text
                opacity: 0.45 + 0.55 * (root.levels[index] || 0)
                Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.OutCubic } }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            width: Math.ceil(clockMetrics.advanceWidth)
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
            text: root.clock(root.elapsed)
            font: clockMetrics.font
            color: Commons.Color.popups.text
          }
        }

        // Processing: three dots and a label.
        Row {
          id: processingRow
          visible: root.mode === "processing"
          height: parent.height
          spacing: root.gap

          Row {
            spacing: Style.space(5)
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
              model: 3
              Rectangle {
                required property int index
                width: Style.space(7)
                height: width
                radius: width / 2
                color: Commons.Color.accent
                opacity: 0.3
                SequentialAnimation on opacity {
                  running: root.mode === "processing"
                  loops: Animation.Infinite
                  PauseAnimation { duration: index * 160 }
                  NumberAnimation { to: 1; duration: 320; easing.type: Easing.InOutSine }
                  NumberAnimation { to: 0.3; duration: 320; easing.type: Easing.InOutSine }
                  PauseAnimation { duration: (2 - index) * 160 }
                }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            text: strings.t("transcribing")
            font.family: Style.font.family
            font.bold: true
            font.pixelSize: Style.font.body
            color: Commons.Color.popups.text
          }
        }

        // Messages: short notices and errors from flow-omarchy.
        Row {
          id: messageRow
          visible: root.mode === "message"
          height: parent.height
          spacing: root.gap

          Rectangle {
            width: Style.space(10)
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: root.failed ? Commons.Color.urgent : Commons.Color.muted
          }

          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.maxMessageWidth)
            text: root.message
            elide: Text.ElideRight
            maximumLineCount: 1
            font.family: Style.font.family
            font.bold: true
            font.pixelSize: Style.font.body
            color: Commons.Color.popups.text
          }
        }
      }
    }
  }
}
