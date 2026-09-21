import QtQuick
import "../Geometry.js" as Geo

/* Cuerpo / cabeza / hocico: el rectángulo redondeado contorneado.
   Relleno con el color del fondo, para que las patas del fondo queden
   detrás y la silueta se lea limpia (PERSONAJE.md §1).

   `spec` viene de Geometry.js en unidades de la spec: {x, y, w, h, r}. */
Rectangle {
    id: part

    property real u: 1
    property var spec: ({ x: 0, y: 0, w: 0, h: 0, r: 0 })
    property real strokeWidth: Geo.STROKE.body
    property color ink: "#ffffff"
    property color fill: "#000000"

    readonly property var g: Geo.strokedRect(spec, strokeWidth)

    x: g.x * u
    y: g.y * u
    width: g.w * u
    height: g.h * u
    radius: g.r * u

    color: fill
    border.color: ink
    border.width: strokeWidth * u
    antialiasing: true
}
