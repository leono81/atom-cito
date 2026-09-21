import QtQuick
import QtQuick.Shapes
import "../Geometry.js" as Geo

/* La cola: una curva cuadrática con punta redonda, que gira desde la
   grupa. Es el medidor de ánimo — lo que más se lee de lejos, así que va
   entera aunque cueste un Shape.

   `spec` viene de Geometry.js con la notación relativa de la spec
   (sx, sy, dcx, dcy, dx, dy) más el pivote (px, py). */
Item {
    id: tail

    property real u: 1
    property var spec
    property real angle: 0
    property color ink: "#ffffff"
    property real strokeWidth: Geo.STROKE.tail

    readonly property var q: Geo.quad(spec)

    anchors.fill: parent

    Shape {
        anchors.fill: parent
        antialiasing: true
        ShapePath {
            strokeColor: tail.ink
            strokeWidth: tail.strokeWidth * tail.u
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: tail.q.sx * tail.u
            startY: tail.q.sy * tail.u
            PathQuad {
                controlX: tail.q.cx * tail.u
                controlY: tail.q.cy * tail.u
                x: tail.q.ex * tail.u
                y: tail.q.ey * tail.u
            }
        }
    }

    transform: Rotation {
        origin.x: tail.spec.px * tail.u
        origin.y: tail.spec.py * tail.u
        angle: tail.angle
    }
}
