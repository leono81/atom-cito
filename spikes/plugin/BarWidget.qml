import QtQuick
import Quickshell
import qs.Ui

// Fase 0 probe widget. Throwaway.
// U1: climb the visual parent chain and try to measure sibling bar widgets.
// U6: log exactly when `settings` arrives and when the service becomes reachable.
BarWidget {
  id: root
  moduleName: "leono.atomspike"

  readonly property string pluginId: "leono.atomspike"
  readonly property var service: (bar && bar.shell) ? bar.shell.serviceFor(pluginId) : null

  // Minimal footprint in the user's bar.
  implicitWidth: 10
  implicitHeight: root.barSize

  property int tick: 0
  property bool registered: false

  Rectangle {
    anchors.centerIn: parent
    width: 6; height: 6; radius: 3
    color: "#ff2fa8"
    opacity: 0.55
  }

  // ---------------------------------------------------------------- helpers
  function typeName(o) {
    if (o === null || o === undefined) return "<null>"
    try {
      var s = String(o)
      var cut = s.indexOf("(")
      return cut > 0 ? s.substring(0, cut) : s
    } catch (e) { return "<unprintable>" }
  }

  function rectOf(item, origin) {
    var p = { x: 0, y: 0 }
    try { p = item.mapToItem(origin, 0, 0) } catch (e) { return null }
    return {
      x: Math.round(p.x), y: Math.round(p.y),
      w: Math.round(item.width), h: Math.round(item.height)
    }
  }

  // --------------------------------------------------------------- U1 climb
  function climb(label) {
    console.log("[atomspike] ==== U1 climb (" + label + ") ====")
    var o = root
    var i = 0
    var top = null
    while (o && i < 40) {
      var line = "[atomspike] lvl " + i + " type=" + typeName(o)
      try {
        line += " geom=" + Math.round(o.x) + "," + Math.round(o.y)
             + " " + Math.round(o.width) + "x" + Math.round(o.height)
      } catch (e) {}
      var caps = []
      try { if (o.children !== undefined && o.children) caps.push("children=" + o.children.length) } catch (e) {}
      try { if (o.moduleName !== undefined) caps.push("moduleName=" + o.moduleName) } catch (e) {}
      try { if (o.region !== undefined) caps.push("region=" + o.region) } catch (e) {}
      try { if (o.moduleSlots !== undefined) caps.push("HAS moduleSlots") } catch (e) {}
      try { if (typeof o.debugBarGeometry === "function") caps.push("HAS debugBarGeometry()") } catch (e) {}
      try { if (typeof o.moduleWidgets === "function") caps.push("HAS moduleWidgets()") } catch (e) {}
      try { if (o.barConfig !== undefined) caps.push("HAS barConfig") } catch (e) {}
      if (caps.length) line += " :: " + caps.join(" ")
      console.log(line)
      top = o
      o = o.parent
      i++
    }
    console.log("[atomspike] climb ended after " + i + " levels; top=" + typeName(top))
    return top
  }

  // Walk down from the top-most reachable item and collect everything that
  // looks like a bar module slot (it carries a non-empty `moduleName`).
  function collectSlots(node, origin, out, depth) {
    if (!node || depth > 14) return
    var name = undefined
    try { name = node.moduleName } catch (e) {}
    if (name !== undefined && name !== null && String(name).length > 0) {
      var r = rectOf(node, origin)
      if (r) {
        var reg = ""
        try { reg = String(node.region || "") } catch (e) {}
        out.push({ id: String(name), section: reg, x: r.x, y: r.y, w: r.w, h: r.h,
                   visible: node.visible === true, type: typeName(node) })
      }
      return   // a slot's own children are the widget internals; stop here
    }
    var kids = null
    try { kids = node.children } catch (e) { return }
    if (!kids) return
    for (var i = 0; i < kids.length; i++) collectSlots(kids[i], origin, out, depth + 1)
  }

  function measure(label) {
    var top = climb(label)
    if (!top) { console.log("[atomspike] U1 no top item"); return "[]" }
    var out = []
    collectSlots(top, top, out, 0)
    out.sort(function(a, b) { return a.x - b.x })
    console.log("[atomspike] U1 slots found: " + out.length + " (origin=" + typeName(top) + " " + Math.round(top.width) + "x" + Math.round(top.height) + ")")
    for (var i = 0; i < out.length; i++) {
      var s = out[i]
      console.log("[atomspike]   " + (s.visible ? " " : "!") + " " + s.id
        + "  sect=" + (s.section || "-")
        + "  x=" + s.x + " y=" + s.y + " w=" + s.w + " h=" + s.h)
    }
    // Same thing via mapToItem(null, ...) — scene/window coordinates.
    var scene = []
    collectSlots(top, null, scene, 0)
    scene.sort(function(a, b) { return a.x - b.x })
    console.log("[atomspike] U1 scene coords (mapToItem(null)): "
      + scene.map(function(s) { return s.id + "@" + s.x + "+" + s.w }).join("  "))

    var payload = JSON.stringify({ screen: root.screenName, width: Math.round(top.width), slots: out })
    if (root.service && typeof root.service.reportGeometry === "function")
      root.service.reportGeometry(payload)
    return payload
  }

  readonly property string screenName: {
    var w = root.QsWindow ? root.QsWindow.window : null
    return w && w.screen ? String(w.screen.name || "") : ""
  }

  // -------------------------------------------------------------- U6 config
  function logSettings(when) {
    var keys = []
    try { for (var k in settings) keys.push(k) } catch (e) {}
    console.log("[atomspike] U6 settings @" + when
      + " tick=" + root.tick
      + " typeof=" + (typeof settings)
      + " keys=[" + keys.join(",") + "]"
      + " probeValue=" + root.setting("probeValue", "<absent>")
      + " probeName=" + root.setting("probeName", "<absent>")
      + " bar=" + (bar ? typeName(bar) : "<null>")
      + " bar.shell=" + (bar && bar.shell ? typeName(bar.shell) : "<null>")
      + " service=" + (root.service ? typeName(root.service) : "<null>"))
  }

  onSettingsChanged: { root.tick++; logSettings("onSettingsChanged") }
  onBarChanged: logSettings("onBarChanged")
  onServiceChanged: {
    logSettings("onServiceChanged")
    if (root.service && !root.registered) {
      root.registered = true
      if (typeof root.service.registerWidget === "function") {
        root.service.registerWidget(root)
        console.log("[atomspike] U6 widget registered into service, screen=" + root.screenName)
      }
    }
    if (root.service && typeof root.service.reportSettings === "function")
      root.service.reportSettings(JSON.stringify(root.settings || {}))
  }

  Component.onCompleted: {
    console.log("[atomspike] U6 widget Component.onCompleted")
    logSettings("Component.onCompleted")
    Qt.callLater(function() { logSettings("Qt.callLater") })
  }

  Timer { interval: 0; running: true; repeat: false; onTriggered: root.logSettings("Timer(0ms)") }
  Timer { interval: 300; running: true; repeat: false; onTriggered: { root.logSettings("Timer(300ms)"); root.measure("300ms") } }
  Timer { interval: 1500; running: true; repeat: false; onTriggered: { root.logSettings("Timer(1500ms)"); root.measure("1500ms") } }
}
