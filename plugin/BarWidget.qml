import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Atom — la huella en la barra.
//
// Parece decorativo y no lo es: este widget es estructural por dos razones
// que no se ven.
//
//   1. Es el único que ve la barra. El servicio se crea con `parent: null`
//      a propósito; este widget vive dentro de la escena QML y puede trepar
//      hasta el root de la ventana para medir a sus hermanos.
//   2. Es quien trae el color del tema, que sale de `qs.Commons` — un import
//      que el servicio no hace.
//
// Sacarlo de la barra deshabilita el plugin entero (third-party enabled ⇔
// present) y el perro desaparece.
BarWidget {
  id: root
  moduleName: "leono.atom"

  readonly property string pluginId: "leono.atom"

  // El host entrega el servicio hermano por la fachada.
  readonly property var service: (bar && bar.shell) ? bar.shell.serviceFor(pluginId) : null

  implicitWidth: vertical ? barSize : Style.space(10)
  implicitHeight: vertical ? Style.space(10) : barSize

  // Una marca mínima: que se vea que el plugin está, sin competir con el
  // perro, que es lo que el usuario realmente mira.
  Rectangle {
    anchors.centerIn: parent
    width: Style.space(4)
    height: width
    radius: width / 2
    color: root.bar ? root.bar.foreground : Color.foreground
    opacity: root.service ? 0.55 : 0.2
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: if (root.bar) root.bar.showTooltip(root, "Atom")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  // ---- canal hacia el servicio ------------------------------------------
  // Todo lo que lea `settings`, `bar` o `service` va diferido con
  // Qt.callLater: durante Component.onCompleted todavía están vacíos.
  // El widget NO empuja la configuración: el servicio la lee de
  // `shell.barConfig`, que siempre está completa. Acá solo va lo que el
  // servicio no puede conseguir por su cuenta: quién es su widget (para
  // medir la barra) y el color del tema (que necesita qs.Commons).
  function push() {
    if (!root.service) return
    root.service.registerWidget(root)
    root.service.inkColor = root.bar ? root.bar.foreground : Color.foreground
    root.service.fillColor = Color.bar.background
    root.service.accentColor = Color.accent
    root.service.mutedColor = Color.muted
    root.service.fontFamily = root.bar ? root.bar.fontFamily : Style.font.family
  }

  Component.onCompleted: Qt.callLater(root.push)
  onServiceChanged: Qt.callLater(root.push)
  onSettingsChanged: Qt.callLater(root.push)

  // ---- medición de la barra ---------------------------------------------
  // Trepa hasta el root de la ventana de la barra. No usa ninguna API
  // privada: solo parent, children, mapToItem y la convención de que un slot
  // tiene `moduleName` — que es contrato público de BarWidget. El camino por
  // bar.moduleWidgets() sí está acotado al propio módulo y no sirve.
  function topItem() {
    var o = root, top = null, i = 0
    while (o && i < 40) { top = o; o = o.parent; i++ }
    return top
  }

  function collectSlots(node, origin, out, depth) {
    if (!node || depth > 14) return
    var name = undefined
    try { name = node.moduleName } catch (e) {}
    if (name !== undefined && name !== null && String(name).length > 0) {
      var p
      try { p = node.mapToItem(origin, 0, 0) } catch (e2) { return }
      out.push({
        id: String(name),
        section: String(node.region || ""),
        x: Math.round(p.x),
        y: Math.round(p.y),
        w: Math.round(node.width),
        h: Math.round(node.height)
      })
      return  // los hijos de un slot son el interior del widget
    }
    var kids = null
    try { kids = node.children } catch (e3) { return }
    if (!kids) return
    for (var i = 0; i < kids.length; i++) collectSlots(kids[i], origin, out, depth + 1)
  }

  // Se re-mide en cada llamada a propósito: los anchos cambian solos (el
  // reloj crece y se achica con el día de la semana), y cachear esto es
  // exactamente cómo el perro termina sentado encima de un widget.
  function measure() {
    var top = topItem()
    if (!top) return null
    var out = []
    collectSlots(top, top, out, 0)
    // Filtrar por ancho, no por `visible`: hay widgets montados con w=0.
    var kept = []
    for (var i = 0; i < out.length; i++) if (out[i].w > 0) kept.push(out[i])
    kept.sort(function (a, b) { return a.x - b.x })
    return { barWidth: Math.round(top.width), barHeight: Math.round(top.height), obstacles: kept }
  }
}
