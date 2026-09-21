import QtQuick
import "parts"
import "Geometry.js" as Geo

/* ── SENTADO ──────────────────────────────────────────────────────────────
   Tranqui, esperando: la grupa en el piso, el pecho arriba, las patas
   delanteras firmes. La cola queda apoyada atrás.
   ─────────────────────────────────────────────────────────────────────── */
AtomPose {
    id: pose

    poseId: "sit"
    canMove: false
    breathPeriod: Geo.ANIM.breath.sit

    readonly property var g: Geo.SIT
    bodyPivot: Qt.point(g.bodyPivot.x, g.bodyPivot.y)

    /* Sentado la cola descansa; solo se mueve si está hablando. */
    readonly property real tailAngle:
        speaking ? swing(Geo.ANIM.speakPeriod, -Geo.ANIM.wagHappySwing, Geo.ANIM.wagHappySwing) : 0
    readonly property real earAngle:
        speaking ? swing(Geo.ANIM.speakPeriod, Geo.ANIM.flopFrom, Geo.ANIM.flopTo) : 0

    Tail { u: pose.u; ink: pose.inkColor; spec: pose.g.tail; angle: pose.tailAngle }

    Leg { u: pose.u; ink: pose.inkColor; far: true; spec: pose.g.legs.frontFar }

    Body { u: pose.u; ink: pose.inkColor; fill: pose.fillColor; spec: pose.g.haunch }
    Body { u: pose.u; ink: pose.inkColor; fill: pose.fillColor; spec: pose.g.chest }

    Leg { u: pose.u; ink: pose.inkColor; spec: pose.g.legs.frontNear }

    /* La grupa apoyada en el piso. */
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
