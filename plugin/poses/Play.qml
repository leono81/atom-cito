import QtQuick
import "parts"
import "Geometry.js" as Geo

/* ── JUGANDO ──────────────────────────────────────────────────────────────
   La reverencia clásica: pecho y codos en el piso, grupa arriba, cola
   parada moviéndose rápido. Es la pose más expresiva de la tanda y la
   apuesta es toda a la silueta — a 28 × 20 lo único que se lee es
   "adelante abajo, atrás arriba, cola alta".

   El lomo es **un solo cuerpo inclinado**, no dos cajas como el sentado:
   probado con dos, la grupa y el pecho se leen como dos burbujas pegadas
   y se pierde la diagonal, que es justo el gesto. Inclinar 20° una caja
   más corta y más alta que la de `stand`, con el pivote adelante y abajo,
   da la diagonal del lomo, deja la grupa a 8 —la altura normal— y apoya
   el pecho en el piso.

   Las manos van como elipse apoyada (igual que en `lie` y `sleep`): con
   el pecho en el piso, los antebrazos están acostados y una cápsula
   girada más sería ruido.

   canMove: false: la reverencia es una parada, no un traslado.

   Geometría propia (mismo viewBox de 34 × 24, mismo piso en y = 21). Vive
   acá y no en Geometry.js porque esta tanda se escribió en paralelo con el
   cableado del comportamiento; si la pose queda, PLAY merece mudarse a Geo
   junto a STAND / SIT / LIE / SLEEP.
   ─────────────────────────────────────────────────────────────────────── */
AtomPose {
    id: pose

    poseId: "play"
    canMove: false
    breathPeriod: 0              // el rebote de la invitación reemplaza la respiración

    /* Cola alegre a 200 ms: necesita cuadros. Es una pose transitoria, como
       `walk`; el ciclo de ocio no se queda acá. */
    clockFps: motionFps

    readonly property var g: ({
        /* El cuerpo antes de inclinarlo, y la inclinación. Con estos
           números las esquinas caen en: grupa arriba (9.7, 8.0), grupa
           abajo (7.2, 14.8) —de ahí cuelgan las patas traseras— y pecho
           en el piso (21.8, 20.1). */
        body: { x: 6.4, y: 11.9, w: 15.5, h: 7.2, r: 3.6 },
        tilt: { angle: 20, px: 19, py: 19.3 },
        bodyPivot: { x: 13, y: 19 },

        /* Las manos estiradas adelante, apoyadas en el piso. */
        paw: { cx: 22.6, cy: 20, rx: 3.2, ry: 1 },

        head:   { cx: 25.6, cy: 13.8, r: 3.7 },
        muzzle: { x: 27.4, y: 13.5, w: 5,   h: 3.6, r: 1.6 },
        nose:   { cx: 31.8, cy: 14.6, r: 0.78 },
        eye:    { cx: 26.1, cy: 12.9, r: 0.85 },
        lid:    { sx: 25.4, sy: 12.9, dcx: 0.7, dcy: 0.8, dx: 1.4, dy: 0 },
        ear:    { cx: 23.8, cy: 13.6, rx: 1.55, ry: 3.1, rot: -14,
                  px: 23.7, py: 10.7 },

        /* La cola parada: casi vertical, apenas curvada. */
        tail: { sx: 8, sy: 9.8, dcx: -1.6, dcy: -2.8, dx: -0.6, dy: -6.4,
                px: 8, py: 9.8 },

        /* Traseras estiradas: son las que levantan la grupa. */
        legs: {
            backFar:  { x: 9,  y1: 14,   y2: 20.6 },
            backNear: { x: 11, y1: 14.6, y2: 20.8 }
        }
    })

    bodyPivot: Qt.point(g.bodyPivot.x, g.bodyPivot.y)

    /* El rebote de "dale, jugá": mínimo, rápido, sobre todo el conjunto. */
    readonly property int bouncePeriod: 440
    bodyDy: -0.4 * wave(bouncePeriod)

    /* Cola parada y rápida: ±18° a 200 ms. */
    readonly property real tailAngle: swing(200, -18, 18)

    /* Las orejas acompañan el rebote. */
    readonly property real earAngle: swing(bouncePeriod, Geo.ANIM.flopFrom, Geo.ANIM.flopTo)

    /* Orden de dibujo: el fondo primero. */
    Leg { u: pose.u; ink: pose.inkColor; far: true; spec: pose.g.legs.backFar }

    Tail { u: pose.u; ink: pose.inkColor; spec: pose.g.tail; angle: pose.tailAngle }

    /* El lomo en diagonal: el cuerpo de siempre, inclinado. */
    Item {
        anchors.fill: parent
        transform: Rotation {
            origin.x: pose.g.tilt.px * pose.u
            origin.y: pose.g.tilt.py * pose.u
            angle: pose.g.tilt.angle
        }
        Body { u: pose.u; ink: pose.inkColor; fill: pose.fillColor; spec: pose.g.body }
    }

    Leg { u: pose.u; ink: pose.inkColor; spec: pose.g.legs.backNear }

    Head {
        u: pose.u; ink: pose.inkColor; fill: pose.fillColor
        spec: pose.g; blinking: pose.blinking
    }

    /* Las manos, adelante y abajo del hocico: los codos están en el piso. */
    Ellipse { u: pose.u; ink: pose.inkColor; fill: pose.fillColor; spec: pose.g.paw }

    Ear {
        u: pose.u; ink: pose.inkColor; fill: pose.fillColor
        spec: pose.g.ear; angle: pose.earAngle
    }
}
