import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Fase 0 probe service. Throwaway.
// U3: small overlay PanelWindow with a mask, static and animated variants.
// U2: something mapped in the Overlay layer to compare z-order against popups.
// U6: the other end of the config channel.
Item {
  id: root

  // Injected by the shell host (PluginShellApi facade for third-party plugins).
  property var shell: null
  property var manifest: null

  property var widget: null
  property string lastGeometry: ""
  property string lastSettings: ""
  property bool animated: false
  property bool wide: false
  property int winLeft: 240
  property int dotLeft: 0
  // U3 mask variants: "item" (Region { item: dot }, re-emitted every frame the
  // dot moves), "static" (fixed Region, never re-emitted) and "phase" (Region
  // whose x is animated while nothing on screen moves: isolates the protocol
  // cost from the repaint cost).
  property string maskKind: "item"
  property bool phaseRunning: false
  property int hoverEvents: 0
  property int clickEvents: 0

  function registerWidget(w) {
    root.widget = w
    console.log("[atomspike] SVC registerWidget called, widget=" + w)
  }

  function reportGeometry(json) {
    root.lastGeometry = String(json || "")
    console.log("[atomspike] SVC reportGeometry <- " + root.lastGeometry)
  }

  function reportSettings(json) {
    root.lastSettings = String(json || "")
    console.log("[atomspike] SVC reportSettings <- " + root.lastSettings)
  }

  // ------------------------------------------------------- U6, reverse path
  function dumpBarConfig(tag) {
    var bc = shell ? shell.barConfig : undefined
    console.log("[atomspike] SVC " + tag + " shell=" + (shell ? String(shell) : "<null>")
      + " typeof shellConfig=" + (shell ? (typeof shell.shellConfig) : "n/a")
      + " typeof barConfig=" + (typeof bc)
      + " bar=" + (shell && shell.bar ? String(shell.bar) : "<null>"))
    if (!bc) { console.log("[atomspike] SVC " + tag + " barConfig unavailable"); return "" }
    try {
      console.log("[atomspike] SVC " + tag + " barConfig.position=" + bc.position
        + " barSize=" + (shell && shell.bar ? shell.bar.barSize : "?")
        + " barHidden=" + (shell && shell.bar ? shell.bar.barHidden : "?"))
      var sections = ["left", "center", "right"]
      var found = null
      for (var s = 0; s < sections.length; s++) {
        var arr = bc.layout ? bc.layout[sections[s]] : null
        if (!arr) continue
        var ids = []
        for (var i = 0; i < arr.length; i++) {
          ids.push(arr[i].id)
          if (String(arr[i].id) === "leono.atomspike") found = { section: sections[s], index: i, entry: arr[i] }
        }
        console.log("[atomspike] SVC " + tag + " layout." + sections[s] + " = " + ids.join(", "))
      }
      console.log("[atomspike] SVC " + tag + " own entry via barConfig = " + JSON.stringify(found))
      return JSON.stringify(found)
    } catch (e) {
      console.log("[atomspike] SVC " + tag + " barConfig walk threw: " + e)
      return ""
    }
  }

  function serviceSelfLookup() {
    var self = shell && typeof shell.serviceFor === "function" ? shell.serviceFor("leono.atomspike") : null
    console.log("[atomspike] SVC serviceFor(self) = " + (self ? String(self) : "<null>")
      + " (=== root? " + (self === root) + ")")
  }

  property int seq: 0
  onShellChanged: console.log("[atomspike] SVC onShellChanged seq=" + (++root.seq)
    + " shell=" + (shell ? String(shell) : "<null>")
    + " barConfig=" + (shell && shell.barConfig ? "present" : "absent"))

  Component.onCompleted: {
    console.log("[atomspike] SVC Component.onCompleted CODEVERSION=3 seq=" + (++root.seq) + " parent=" + root.parent)
    dumpBarConfig("t0-onCompleted")
    serviceSelfLookup()
    Qt.callLater(function() { root.dumpBarConfig("t-callLater"); root.serviceSelfLookup() })
  }

  Timer { interval: 0; running: true; repeat: false; onTriggered: root.dumpBarConfig("t-0ms") }
  Timer { interval: 16; running: true; repeat: false; onTriggered: root.dumpBarConfig("t-16ms") }

  Timer { interval: 400; running: true; repeat: false; onTriggered: { root.dumpBarConfig("t400"); root.serviceSelfLookup() } }
  Timer { interval: 2000; running: true; repeat: false; onTriggered: root.dumpBarConfig("t2000") }

  // -------------------------------------------------------------------- IPC
  IpcHandler {
    target: "atomspike"

    function ping(): string { return "ok" }

    function geometry(): string {
      if (root.widget && typeof root.widget.measure === "function")
        return String(root.widget.measure("ipc"))
      return "no-widget"
    }

    function cfg(): string {
      return JSON.stringify({
        widgetSettings: root.lastSettings,
        barConfigEntry: root.dumpBarConfig("ipc"),
        widgetSeen: !!root.widget
      })
    }

    function anim(on: string): string {
      root.animated = String(on) === "true" || String(on) === "on"
      console.log("[atomspike] U3 animated = " + root.animated)
      return String(root.animated)
    }

    function wideWin(on: string): string {
      root.wide = String(on) === "true" || String(on) === "on"
      return String(root.wide)
    }

    function hits(): string {
      return JSON.stringify({ hover: root.hoverEvents, clicks: root.clickEvents, dotX: Math.round(dotProxy.x) })
    }

    function resetHits(): string {
      root.hoverEvents = 0; root.clickEvents = 0
      return "ok"
    }

    function place(x: string): string {
      root.winLeft = parseInt(String(x), 10) || 0
      return String(root.winLeft)
    }

    function maskMode(mode: string): string {
      var m = String(mode)
      root.maskKind = (m === "static" || m === "phase") ? m : "item"
      root.phaseRunning = (root.maskKind === "phase")
      console.log("[atomspike] U3 maskKind = " + root.maskKind)
      return root.maskKind
    }

    function dotAt(x: string): string {
      root.dotLeft = parseInt(String(x), 10) || 0
      return String(root.dotLeft)
    }
  }

  // ------------------------------------------------------------ U3 / U2 win
  // Deliberately small (200x40), not full width, and masked from the first
  // frame so it cannot swallow the bar's clicks.
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: probeWindow
      required property var modelData
      screen: modelData

      WlrLayershell.namespace: "atomspike"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"

      anchors { top: true; left: true }
      margins { left: root.winLeft; top: 0 }
      implicitWidth: root.wide ? 400 : 200
      implicitHeight: 40

      // The mask is the dog-shaped hole: only `dot` takes input, everything
      // else in this surface is click-through.
      property real maskPhase: 0
      NumberAnimation on maskPhase {
        running: root.phaseRunning
        from: 0; to: 160; duration: 2400; loops: Animation.Infinite
      }

      property Region dynRegion: Region { item: dot }
      property Region fixedRegion: Region { x: 0; y: 4; width: 40; height: 22 }
      property Region phaseRegion: Region { x: probeWindow.maskPhase; y: 4; width: 40; height: 22 }
      mask: root.maskKind === "static" ? fixedRegion
          : root.maskKind === "phase" ? phaseRegion
          : dynRegion

      Rectangle {
        id: dot
        y: 4
        width: 40
        height: 22
        radius: 4
        color: "#ff2fa8"
        opacity: 0.85

        x: root.dotLeft
        NumberAnimation on x {
          id: slide
          running: root.animated
          from: 0
          to: probeWindow.width - dot.width
          duration: 2400
          loops: Animation.Infinite
        }
        onXChanged: dotProxy.x = x

        HoverHandler {
          onHoveredChanged: {
            root.hoverEvents++
            console.log("[atomspike] U3 dot hovered=" + hovered + " (count=" + root.hoverEvents + ") screen=" + probeWindow.screen.name)
          }
        }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          onPressed: function(m) {
            root.clickEvents++
            console.log("[atomspike] U3 dot CLICK button=" + m.button + " count=" + root.clickEvents)
          }
        }
      }

      // Covers the whole surface. If the mask is honoured by the compositor
      // this must never fire outside `dot`.
      MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        onPressed: function(m) {
          console.log("[atomspike] U3 !! OUTSIDE-MASK press at " + Math.round(m.x) + "," + Math.round(m.y) + " -> mask is NOT working")
        }
        onEntered: console.log("[atomspike] U3 !! OUTSIDE-MASK enter -> mask is NOT working")
      }

      Component.onCompleted: console.log("[atomspike] U3 PanelWindow mapped on " + screen.name
        + " " + implicitWidth + "x" + implicitHeight + " layer=Overlay ns=atomspike")
    }
  }

  QtObject { id: dotProxy; property real x: 0 }
}
