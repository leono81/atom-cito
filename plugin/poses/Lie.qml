import QtQuick
import "parts"
import "Geometry.js" as Geo

/* ── ECHADO ───────────────────────────────────────────────────────────────
   Frito, se rindió: el cuerpo entero en el piso, la cabeza todavía
   levantada, las manos estiradas adelante.
   ─────────────────────────────────────────────────────────────────────── */
AtomPose {
    id: pose

    poseId: "lie"
    canMove: false
    breathPeriod: Geo.ANIM.breath.lie

    readonly property var g: Geo.LIE
    bodyPivot: Qt.point(g.bodyPivot.x, g.bodyPivot.y)

    readonly property real tailAngle:
        speaking ? swing(Geo.ANIM.speakPeriod, -Geo.ANIM.wagCalmSwing, Geo.ANIM.wagCalmSwing) : 0
    readonly property real earAngle:
        speaking ? swing(Geo.ANIM.speakPeriod, Geo.ANIM.flopFrom, Geo.ANIM.flopTo) : 0

    Tail { u: pose.u; ink: pose.inkColor; spec: pose.g.tail; angle: pose.tailAngle }

    Body { u: pose.u; ink: pose.inkColor; fill: pose.fillColor; spec: pose.g.body }

    /* Las manos estiradas adelante. */
    Ellipse { u: pose.u; ink: pose.inkColor; fill: pose.fillColor; spec: pose.g.paw }

    Head {
        u: pose.u; ink: pose.inkColor; fill: pose.fillColor
        spec: pose.g; blinking: pose.blinking
    }

    Ear {
        u: pose.u; ink: pose.inkColor; fill: pose.fillColor
        spec: pose.g.ear; angle: pose.earAngle
    }
}
