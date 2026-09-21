import QtQuick
import "../Geometry.js" as Geo

/* La oreja caída: una elipse inclinada que cuelga de un pivote alto
   (PERSONAJE.md §2: la oreja está en 23.2, 7.7 pero gira desde 23.2, 4.8,
   arriba de la cabeza — por eso flopea como una oreja y no como una hélice).

   `spec` = {cx, cy, rx, ry, rot, px, py}. `angle` es el flopeo. */
Item {
    id: ear

    property real u: 1
    property var spec
    property real angle: 0
    property color ink: "#ffffff"
    property color fill: "#000000"

    anchors.fill: parent

    Ellipse {
        u: ear.u
        spec: ear.spec
        rot: ear.spec.rot
        ink: ear.ink
        fill: ear.fill
    }

    transform: Rotation {
        origin.x: ear.spec.px * ear.u
        origin.y: ear.spec.py * ear.u
        angle: ear.angle
    }
}
