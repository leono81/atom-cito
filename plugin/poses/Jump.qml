import QtQuick
import "parts"
import "Geometry.js" as Geo

/* ── SALTANDO ─────────────────────────────────────────────────────────────
   Saltando de contento: las cuatro patas despegadas, el cuerpo arriba, las
   orejas para atrás por el impulso.

   **Es un ciclo, no una pose flotando.** Cada 600 ms sube, baja y toca el
   piso: 430 ms en el aire y 170 ms apoyado, para que se lea el rebote y no
   un perro suspendido. La altura sale del reloj de la pose —como todo acá—
   y el pico son 3 unidades, que con la cabeza en y = 4.1 deja el dibujo
   adentro del viewBox (PERSONAJE.md §2: 34 × 24, piso en 21).

   canMove: TRUE, y es la unica pose ademas de `walk` que lo declara. Un
   salto que no te lleva a ningun lado no es jugar: la cabriola se tira de un
   lado al otro, y eso es trasladarse. La regla del proyecto dejo de ser
   "solo caminando" y paso a ser "solo las poses que lo declaran" — que es la
   que el Mover siempre implemento, porque le pregunta a la pose y no a una
   lista. Lo que importaba (un perro sentado no se desliza) sigue igual.

   Reusa la geometría de `stand`: el salto es todo timing.
   ─────────────────────────────────────────────────────────────────────── */
AtomPose {
    id: pose

    poseId: "jump"
    canMove: true
    breathPeriod: 0              // el salto reemplaza la respiración

    /* Como `walk`: movimiento rápido, cuadros de verdad, pose transitoria. */
    clockFps: motionFps

    readonly property var g: Geo.STAND
    bodyPivot: Qt.point(g.bodyPivot.x, g.bodyPivot.y)

    /* ── El ciclo del salto ───────────────────────────────────────────── */
    readonly property int hopPeriod: 600
    readonly property real airFraction: 0.72     // el resto es apoyo en el piso
    readonly property real hopT: (clockMs % hopPeriod) / hopPeriod

    /* 0 en el piso, 1 en el pico. Media onda de seno: despega y aterriza
       con velocidad, flota en el medio. */
    readonly property real hop:
        hopT < airFraction ? Math.sin(Math.PI * (hopT / airFraction)) : 0

    readonly property real hopHeight: 3.2        // unidades: el pico deja
                                                 // la cabeza en y = 0.9

    bodyDy: -hopHeight * hop

    /* Patas: las delanteras se estiran adelante y las traseras quedan
       atrás, proporcional a la altura. En el piso vuelven a cero. */
    readonly property real frontAngle: -26 * hop
    readonly property real backAngle:   22 * hop

    /* Orejas para arriba y atrás por el impulso. */
    readonly property real earAngle: 26 * hop

    /* Cola alta y alegre. */
    readonly property real tailAngle:
        12 * hop + swing(Geo.ANIM.wagHappyPeriod,
                         -Geo.ANIM.wagHappySwing, Geo.ANIM.wagHappySwing)

    Leg {
        u: pose.u; ink: pose.inkColor; far: true
        spec: pose.g.legs.backFar; angle: pose.backAngle * 0.85
    }
    Leg {
        u: pose.u; ink: pose.inkColor; far: true
        spec: pose.g.legs.frontFar; angle: pose.frontAngle * 0.85
    }

    Tail { u: pose.u; ink: pose.inkColor; spec: pose.g.tail; angle: pose.tailAngle }

    Body { u: pose.u; ink: pose.inkColor; fill: pose.fillColor; spec: pose.g.body }

    Leg { u: pose.u; ink: pose.inkColor; spec: pose.g.legs.backNear;  angle: pose.backAngle }
    Leg { u: pose.u; ink: pose.inkColor; spec: pose.g.legs.frontNear; angle: pose.frontAngle }

    Head {
        u: pose.u; ink: pose.inkColor; fill: pose.fillColor
        spec: pose.g; blinking: pose.blinking
    }

    Ear {
        u: pose.u; ink: pose.inkColor; fill: pose.fillColor
        spec: pose.g.ear; angle: pose.earAngle
    }
}
