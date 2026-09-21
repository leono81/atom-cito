import QtQuick
import "parts"
import "Geometry.js" as Geo

/* ── CAMINANDO ────────────────────────────────────────────────────────────
   Yendo a algún lado. Patas en contrafase, rebote del cuerpo en fase con
   las patas, orejas flopeando y cola alegre.

   **La única pose con canMove: true.** No es "stand con las patas
   animadas": es una entrada propia del registro que reusa las mismas
   piezas de parts/ y la misma geometría de Geo.STAND (ARQUITECTURA.md
   §4.2). Si fueran la misma pose, el dato que implementa la invariante de
   movimiento valdría true estando quieto y la garantía sería falsa.

   Es también lo único caro que hace el perro, y lo más corto: el reloj
   corre a `motionFps` — bajable a 30 desde el renderer.
   ─────────────────────────────────────────────────────────────────────── */
AtomPose {
    id: pose

    poseId: "walk"
    canMove: true
    breathPeriod: 0              // caminando, el rebote reemplaza la respiración

    clockFps: motionFps

    readonly property var g: Geo.STAND
    bodyPivot: Qt.point(g.bodyPivot.x, g.bodyPivot.y)

    /* Rebote: −0.45 u, en fase con las patas. */
    bodyDy: Geo.ANIM.bobDy * wave(Geo.ANIM.walkPeriod)

    /* Patas en contrafase: fn+bf contra ff+bn, ±17°. */
    readonly property real legA: swing(Geo.ANIM.walkPeriod,  Geo.ANIM.legSwing, -Geo.ANIM.legSwing)
    readonly property real legB: swing(Geo.ANIM.walkPeriod, -Geo.ANIM.legSwing,  Geo.ANIM.legSwing)

    readonly property real tailAngle:
        swing(Geo.ANIM.wagHappyPeriod, -Geo.ANIM.wagHappySwing, Geo.ANIM.wagHappySwing)
    readonly property real earAngle:
        swing(Geo.ANIM.walkPeriod, Geo.ANIM.flopFrom, Geo.ANIM.flopTo)

    Leg { u: pose.u; ink: pose.inkColor; far: true; spec: pose.g.legs.backFar;  angle: pose.legA }
    Leg { u: pose.u; ink: pose.inkColor; far: true; spec: pose.g.legs.frontFar; angle: pose.legB }

    Tail { u: pose.u; ink: pose.inkColor; spec: pose.g.tail; angle: pose.tailAngle }

    Body { u: pose.u; ink: pose.inkColor; fill: pose.fillColor; spec: pose.g.body }

    Leg { u: pose.u; ink: pose.inkColor; spec: pose.g.legs.backNear;  angle: pose.legB }
    Leg { u: pose.u; ink: pose.inkColor; spec: pose.g.legs.frontNear; angle: pose.legA }

    Head {
        u: pose.u; ink: pose.inkColor; fill: pose.fillColor
        spec: pose.g; blinking: pose.blinking
    }

    Ear {
        u: pose.u; ink: pose.inkColor; fill: pose.fillColor
        spec: pose.g.ear; angle: pose.earAngle
    }
}
