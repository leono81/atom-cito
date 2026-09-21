import QtQuick
import "parts"
import "Geometry.js" as Geo

/* ── PARADO ───────────────────────────────────────────────────────────────
   Fresco, atento, quieto. Respira y mueve la cola despacio.

   canMove: false, y es a propósito (PERSONAJE.md §3): un perro parado
   tampoco se traslada. Para moverse primero pasa a `walk`.
   ─────────────────────────────────────────────────────────────────────── */
AtomPose {
    id: pose

    poseId: "stand"
    canMove: false
    breathPeriod: Geo.ANIM.breath.stand

    readonly property var g: Geo.STAND
    bodyPivot: Qt.point(g.bodyPivot.x, g.bodyPivot.y)

    /* Cola tranquila; alegre mientras habla. */
    readonly property real tailAngle:
        speaking ? swing(Geo.ANIM.speakPeriod, -Geo.ANIM.wagHappySwing, Geo.ANIM.wagHappySwing)
                 : swing(Geo.ANIM.wagCalmPeriod, -Geo.ANIM.wagCalmSwing, Geo.ANIM.wagCalmSwing)

    readonly property real earAngle:
        speaking ? swing(Geo.ANIM.speakPeriod, Geo.ANIM.flopFrom, Geo.ANIM.flopTo) : 0

    /* El orden es el orden de dibujo: primero las patas del fondo, para que
       el cuerpo —relleno con el color de la barra— las tape. */
    Leg { u: pose.u; ink: pose.inkColor; far: true; spec: pose.g.legs.backFar }
    Leg { u: pose.u; ink: pose.inkColor; far: true; spec: pose.g.legs.frontFar }

    Tail { u: pose.u; ink: pose.inkColor; spec: pose.g.tail; angle: pose.tailAngle }

    Body { u: pose.u; ink: pose.inkColor; fill: pose.fillColor; spec: pose.g.body }

    Leg { u: pose.u; ink: pose.inkColor; spec: pose.g.legs.backNear }
    Leg { u: pose.u; ink: pose.inkColor; spec: pose.g.legs.frontNear }

    Head {
        u: pose.u; ink: pose.inkColor; fill: pose.fillColor
        spec: pose.g; blinking: pose.blinking
    }

    Ear {
        u: pose.u; ink: pose.inkColor; fill: pose.fillColor
        spec: pose.g.ear; angle: pose.earAngle
    }
}
