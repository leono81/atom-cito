import QtQuick
import "parts"
import "Geometry.js" as Geo

/* ── RASCÁNDOSE ───────────────────────────────────────────────────────────
   La pata trasera cercana sube y baja rápido contra el costado. Todo el
   resto es `stand`: misma geometría, mismo piso, mismas piezas.

   canMove: false — rascándose no se traslada (PERSONAJE.md §4).

   Los números propios de la pose viven acá y no en Geometry.js a propósito:
   esta tanda de poses se escribió en paralelo con el cableado del
   comportamiento y Geometry.js es territorio compartido. Si la pose queda,
   `scratchLeg` merece mudarse a Geo con el resto.
   ─────────────────────────────────────────────────────────────────────── */
AtomPose {
    id: pose

    poseId: "scratch"
    canMove: false
    breathPeriod: 0              // el temblor del rascado reemplaza la respiración

    /* Rascarse es un gesto rápido: 190 ms de período muestreados a 8 fps
       serían dos frames por ciclo y se vería como ruido. Igual que `walk`,
       es una pose transitoria — el ciclo de ocio no se queda acá. */
    clockFps: motionFps

    readonly property var g: Geo.STAND
    bodyPivot: Qt.point(g.bodyPivot.x, g.bodyPivot.y)

    /* La pata que rasca: más corta que la de apoyo —la rodilla está
       doblada— y colgando del mismo hombro que la trasera cercana. */
    readonly property var scratchLeg: ({ x: 10.4, y1: 15, y2: 19.8 })

    readonly property int scratchPeriod: 180

    /* Ángulo negativo = la pata va hacia adelante (hacia la cabeza): el
       codo sube contra la panza y la pata golpea el costado. El barrido es
       de 24° a propósito: a 28 × 20 la pata mide dos píxeles y lo único
       que se ve es que algo se sacude debajo de la panza. */
    readonly property real scratchAngle: swing(scratchPeriod, -62, -38)

    /* El cuerpo acompaña con un temblor mínimo, en fase con la pata. */
    bodyDy: 0.22 * wave(scratchPeriod)

    /* La oreja sacude al mismo ritmo: es lo que vende el gesto de lejos. */
    readonly property real earAngle: swing(scratchPeriod, -7, 13)

    readonly property real tailAngle:
        speaking ? swing(Geo.ANIM.speakPeriod, -Geo.ANIM.wagHappySwing, Geo.ANIM.wagHappySwing)
                 : swing(Geo.ANIM.wagCalmPeriod, -Geo.ANIM.wagCalmSwing, Geo.ANIM.wagCalmSwing)

    /* El orden es el orden de dibujo: primero las patas del fondo, para que
       el cuerpo —relleno con el color de la barra— las tape. */
    Leg { u: pose.u; ink: pose.inkColor; far: true; spec: pose.g.legs.backFar }
    Leg { u: pose.u; ink: pose.inkColor; far: true; spec: pose.g.legs.frontFar }

    Tail { u: pose.u; ink: pose.inkColor; spec: pose.g.tail; angle: pose.tailAngle }

    Body { u: pose.u; ink: pose.inkColor; fill: pose.fillColor; spec: pose.g.body }

    /* La que rasca va adelante del cuerpo: cruza el costado. */
    Leg { u: pose.u; ink: pose.inkColor; spec: pose.scratchLeg; angle: pose.scratchAngle }
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
