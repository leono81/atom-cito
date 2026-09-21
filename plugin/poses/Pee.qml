import QtQuick
import "parts"
import "Geometry.js" as Geo

/* ── HACIENDO PIS ─────────────────────────────────────────────────────────
   Mirando a la derecha, la pata que se levanta es la trasera cercana:
   sube hacia atrás y afuera, doblada en la rodilla, y el peso queda en
   las otras tres. La cola levantada.

   La silueta es todo: a 28 × 20 lo único que se tiene que leer es el
   miembro que sale del contorno de la grupa. Por eso la pata va en dos
   cápsulas (muslo + pierna) en vez de una sola línea girada — una sola se
   queda adentro del cuerpo y no rompe el contorno, que es justo lo que
   hace legible la pose.

   El chorrito son tres gotas que caen y se desvanecen, muestreadas del
   reloj como el `zzz` de `sleep` pero hacia abajo y adelante. A tamaño
   real miden medio píxel: son detalle de tamaño grande, a propósito.

   canMove: false, obviamente.
   ─────────────────────────────────────────────────────────────────────── */
AtomPose {
    id: pose

    poseId: "pee"
    canMove: false
    breathPeriod: Geo.ANIM.breath.stand

    /* Pose casi quieta: lo único que se mueve son las gotas. 20 fps
       alcanzan para que la caída no se vea a los saltos. */
    clockFps: speaking ? motionFps : Math.max(idleFps, 20)

    readonly property var g: Geo.STAND
    bodyPivot: Qt.point(g.bodyPivot.x, g.bodyPivot.y)

    /* ── La pata levantada ────────────────────────────────────────────── */
    /* Muslo: del mismo hombro que la trasera cercana, hacia atrás y arriba.
       Ángulo positivo = el pie va hacia atrás (hacia −x). */
    readonly property var thigh: ({ x: 10.4, y1: 15.2, y2: 19.6 })
    readonly property real thighAngle: 118

    /* Pierna: arranca donde termina el muslo —la rodilla— y baja hacia
       atrás, saliéndose del contorno de la grupa. Los números son el
       extremo del muslo ya girado, calculados una vez acá. */
    readonly property real kneeX:
        thigh.x - (thigh.y2 - thigh.y1) * Math.sin(thighAngle * Math.PI / 180)
    readonly property real kneeY:
        thigh.y1 + (thigh.y2 - thigh.y1) * Math.cos(thighAngle * Math.PI / 180)

    readonly property var shank: ({ x: pose.kneeX, y1: pose.kneeY,
                                    y2: pose.kneeY + 3.6 })
    readonly property real shankAngle: 22

    /* Cola levantada, con un balanceo mínimo. */
    readonly property real tailAngle:
        speaking ? 20 + swing(Geo.ANIM.speakPeriod, -Geo.ANIM.wagHappySwing, Geo.ANIM.wagHappySwing)
                 : swing(2200, 26, 34)

    readonly property real earAngle:
        speaking ? swing(Geo.ANIM.speakPeriod, Geo.ANIM.flopFrom, Geo.ANIM.flopTo) : 0

    /* ── El chorro ────────────────────────────────────────────────────────
       Un arco punteado que sale de la ingle y cae HACIA ATRÁS, no gotas
       cayendo a plomo: es el dibujo que pidió el usuario. Son puntos que
       avanzan por una Bézier cuadrática y vuelven a empezar, así que el
       gesto se lee por la forma del arco y no por el detalle — que a 28×20
       son cuatro o cinco pixeles sueltos.

       La pata levantada es la trasera y el perro mira a la derecha, así que
       el objetivo le queda detrás: el arco va hacia la izquierda. */
    readonly property int dropCount: 8
    readonly property int arcPeriod: 900

    // El arco sale del viewBox a propósito: el objetivo está unos píxeles a
    // la izquierda del perro, así que el chorro tiene que llegar hasta allá.
    // QML no recorta a los hijos, y el gesto solo se lee si tiene largo: un
    // arco contenido adentro del dibujo son seis píxeles y no se entiende.
    readonly property var arcP0: Qt.point(8.0, 15.6)    // la ingle
    readonly property var arcC:  Qt.point(1.0, 16.6)    // el lomo del arco
    readonly property var arcP1: Qt.point(-6.5, 21.8)   // el piso, sobre el objetivo

    readonly property real arcT: ramp(arcPeriod)

    // Spec fija y desplazamiento animado: el Drop pide no fabricar un objeto
    // nuevo por cuadro, y con dx/dy alcanza.
    readonly property var dropSpec: ({ cx: 8.2, cy: 15.8, r: 0.6 })

    function bez(a, b, c, t) {
        var m = 1 - t;
        return m * m * a + 2 * m * t * b + t * t * c;
    }
    function arcX(t) { return bez(arcP0.x, arcC.x, arcP1.x, t); }
    function arcY(t) { return bez(arcP0.y, arcC.y, arcP1.y, t); }

    // Aparece al salir y se apaga al tocar el piso.
    function arcOpacity(t) {
        if (t < 0.10) return (t / 0.10) * 0.9;
        if (t > 0.88) return 0.9 * (1 - (t - 0.88) / 0.12);
        return 0.9;
    }

    /* Orden de dibujo: el fondo primero. */
    Leg { u: pose.u; ink: pose.inkColor; far: true; spec: pose.g.legs.backFar }
    Leg { u: pose.u; ink: pose.inkColor; far: true; spec: pose.g.legs.frontFar }

    Tail { u: pose.u; ink: pose.inkColor; spec: pose.g.tail; angle: pose.tailAngle }

    Body { u: pose.u; ink: pose.inkColor; fill: pose.fillColor; spec: pose.g.body }

    /* La pata levantada, adelante del cuerpo: cruza la grupa y sale. */
    Leg { u: pose.u; ink: pose.inkColor; spec: pose.thigh; angle: pose.thighAngle }
    Leg { u: pose.u; ink: pose.inkColor; spec: pose.shank; angle: pose.shankAngle }

    Leg { u: pose.u; ink: pose.inkColor; spec: pose.g.legs.frontNear }

    Head {
        u: pose.u; ink: pose.inkColor; fill: pose.fillColor
        spec: pose.g; blinking: pose.blinking
    }

    Ear {
        u: pose.u; ink: pose.inkColor; fill: pose.fillColor
        spec: pose.g.ear; angle: pose.earAngle
    }

    Repeater {
        model: pose.dropCount
        delegate: Drop {
            required property int index
            readonly property real t: (pose.arcT + index / pose.dropCount) % 1

            u: pose.u
            ink: pose.inkColor
            spec: pose.dropSpec
            dx: pose.arcX(t) - pose.dropSpec.cx
            dy: pose.arcY(t) - pose.dropSpec.cy
            opacity: pose.active && !pose.reduceMotion ? pose.arcOpacity(t) : 0
        }
    }
}
