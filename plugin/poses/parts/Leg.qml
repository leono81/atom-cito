import QtQuick
import "../Geometry.js" as Geo

/* Una pata: línea gruesa con punta redonda, que gira alrededor del hombro.

   `spec` = {x, y1, y2} en unidades. `far` la manda al fondo (45 % de
   opacidad: profundidad sin una línea nueva). `angle` en grados, horario,
   con pivote en (x, y1) — el hombro, igual que en la spec. */
Rectangle {
    id: leg

    property real u: 1
    property var spec: ({ x: 0, y1: 0, y2: 0 })
    property bool far: false
    property real angle: 0
    property color ink: "#ffffff"
    property real strokeWidth: Geo.STROKE.leg

    readonly property var g: Geo.legRect(spec, strokeWidth)

    x: g.x * u
    y: g.y * u
    width: g.w * u
    height: g.h * u
    radius: g.r * u

    color: ink
    opacity: far ? Geo.FAR_OPACITY : 1
    antialiasing: true

    transform: Rotation {
        origin.x: leg.width / 2
        origin.y: leg.strokeWidth * leg.u / 2
        angle: leg.angle
    }
}
