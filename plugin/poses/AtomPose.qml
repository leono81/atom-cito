import QtQuick
import "Geometry.js" as Geo

/* ════════════════════════════════════════════════════════════════════════
   AtomPose — el tipo base de toda pose.

   Una pose declara sus datos (poseId, canMove, breathPeriod) y arma su
   dibujo con las piezas de parts/. Todo lo demás —reloj, respiración,
   parpadeo, el grupo que respira— lo pone esta base.

   Presupuesto de rendimiento (ARQUITECTURA.md §8): una superficie animada a
   60 fps cuesta ~16 % de un core. Por eso acá NO hay ni una NumberAnimation
   infinita. Hay un solo Timer por pose —el reloj— que corre a `clockFps` y
   únicamente mientras la pose está visible. Todas las animaciones son
   funciones puras de `clockMs`: cambian juntas, en el mismo frame, y cuando
   el reloj para no se pide ni un frame más.
   ════════════════════════════════════════════════════════════════════════ */

Item {
    id: pose

    /* ── El contrato: lo que cada pose declara ────────────────────────── */
    property string poseId: ""
    /* La invariante de movimiento, como dato. Solo `walk` vale true. */
    property bool canMove: false
    /* 0 = no respira (caminando el rebote reemplaza a la respiración). */
    property int breathPeriod: 0

    /* ── El entorno: lo setea el renderer ─────────────────────────────── */
    property bool active: false          // ¿se está viendo?
    property bool reduceMotion: false    // todo quieto (silenciado / accesibilidad)
    property bool speaking: false        // cola alegre + orejas, mientras habla
    property color inkColor: "#e6e6e6"   // la tinta; entra por propiedad, no por import
    property color fillColor: "#000000"  // el color del fondo, para tapar las patas de atrás
    property int idleFps: 8              // ritmo del reloj cuando está quieto
    property int motionFps: 60           // ritmo del reloj cuando se mueve

    /* ── Derivados ────────────────────────────────────────────────────── */
    /* Píxeles por unidad. El dibujo se define en las 34 × 24 de la spec y
       cada pieza multiplica: así el trazo queda nítido a cualquier tamaño
       (escalar el Item entero emborrona el antialias). */
    readonly property real u: Geo.unitFor(width, height)

    /* Cuántos frames por segundo necesita esta pose. */
    property int clockFps: speaking ? motionFps : idleFps

    /* El reloj: milisegundos desde que la pose se volvió visible. */
    property real clockMs: 0

    readonly property bool ticking: active && !reduceMotion && clockFps > 0

    /* ── Respiración (PERSONAJE.md §3) ────────────────────────────────── */
    /* Desplazamiento y escala del grupo que contiene TODO el perro. Walk
       las pisa con el rebote. */
    property real bodyDy: breathPeriod > 0
                          ? Geo.ANIM.breathDy * wave(breathPeriod) : 0
    property real bodyScaleY: breathPeriod > 0
                              ? 1 + (Geo.ANIM.breathScaleY - 1) * wave(breathPeriod) : 1
    property point bodyPivot: Qt.point(Geo.STAND.bodyPivot.x, Geo.STAND.bodyPivot.y)

    /* ── Parpadeo ─────────────────────────────────────────────────────── */
    property bool canBlink: true
    readonly property bool blinking: blinkHold.running

    /* ── Helpers para las poses ───────────────────────────────────────── */
    /* 0 en los bordes del período, 1 en el medio: el equivalente de un
       @keyframes `0%,100% A · 50% B` con ease-in-out. */
    function wave(period) { return Geo.wave(clockMs, period); }
    /* De `a` a `b` y vuelta, en `period` ms. */
    function swing(period, a, b) { return Geo.swing(clockMs, period, a, b); }
    /* Rampa 0→1 que se reinicia cada período (para el zzz que sube y se va). */
    function ramp(period) { return period ? (clockMs % period) / period : 0; }

    /* Las piezas van acá adentro: este es el grupo que respira / rebota. */
    default property alias content: bodyGroup.data

    Item {
        id: bodyGroup
        anchors.fill: parent
        transform: [
            Scale {
                origin.x: pose.bodyPivot.x * pose.u
                origin.y: pose.bodyPivot.y * pose.u
                yScale: pose.bodyScaleY
            },
            Translate { y: pose.bodyDy * pose.u }
        ]
    }

    /* ── El único timer que dibuja frames ─────────────────────────────── */
    QtObject { id: priv; property real t0: 0 }

    Timer {
        id: clock
        interval: Math.max(8, Math.round(1000 / Math.max(1, pose.clockFps)))
        repeat: true
        running: pose.ticking
        onRunningChanged: {
            if (running) priv.t0 = Date.now();
            else pose.clockMs = 0;          // al parar, vuelve a la postura neutra
        }
        onTriggered: pose.clockMs = Date.now() - priv.t0
    }

    /* ── Parpadeo: dos cambios de propiedad cada varios segundos ──────── */
    /* 130 ms cada 3–7.5 s al azar. Son dos frames, no una animación. */
    function _blinkGap() {
        return Geo.ANIM.blinkGapMin
             + Math.random() * (Geo.ANIM.blinkGapMax - Geo.ANIM.blinkGapMin);
    }

    Timer {
        id: blinkGap
        interval: Geo.ANIM.blinkGapMin
        repeat: true
        running: pose.active && pose.canBlink && !pose.reduceMotion
        onTriggered: {
            blinkHold.restart();
            interval = pose._blinkGap();   // el próximo, en otro rato
        }
    }

    Timer {
        id: blinkHold
        interval: Geo.ANIM.blinkMs
        repeat: false
    }
}
