import QtQuick
import "parts"
import "Geometry.js" as Geo

/* ── DURMIENDO ────────────────────────────────────────────────────────────
   No estás. La cabeza apoyada sobre las manos, los ojos cerrados, y dos
   "z" que suben y se desvanecen.

   No parpadea (canBlink: false): ya tiene el ojo cerrado.
   ─────────────────────────────────────────────────────────────────────── */
AtomPose {
    id: pose

    poseId: "sleep"
    canMove: false
    breathPeriod: Geo.ANIM.breath.sleep
    canBlink: false

    readonly property var g: Geo.SLEEP
    bodyPivot: Qt.point(g.bodyPivot.x, g.bodyPivot.y)

    /* El zzz: una rampa de 3 s que sube, se desvanece y vuelve a empezar. */
    readonly property real zzzT: ramp(Geo.ANIM.zzzPeriod)
    readonly property real zzzOpacity:
        zzzT < 0.3 ? (zzzT / 0.3) * 0.85 : 0.85 * (1 - (zzzT - 0.3) / 0.7)

    Tail { u: pose.u; ink: pose.inkColor; spec: pose.g.tail }

    Body { u: pose.u; ink: pose.inkColor; fill: pose.fillColor; spec: pose.g.body }

    Head {
        u: pose.u; ink: pose.inkColor; fill: pose.fillColor
        spec: pose.g; blinking: false
    }

    /* Las manos, adelante del hocico: la cabeza está apoyada encima. */
    Ellipse { u: pose.u; ink: pose.inkColor; fill: pose.fillColor; spec: pose.g.paw }

    Ear { u: pose.u; ink: pose.inkColor; fill: pose.fillColor; spec: pose.g.ear }

    Repeater {
        model: pose.g.zzz
        delegate: Text {
            required property var modelData
            text: "z"
            color: pose.inkColor
            opacity: pose.active && !pose.reduceMotion ? pose.zzzOpacity : 0
            font.pixelSize: Math.max(1, modelData.size * pose.u)
            font.family: "monospace"
            x: modelData.x * pose.u + pose.zzzT * Geo.ANIM.zzzDx * pose.u
            y: (modelData.y - modelData.size) * pose.u
               + pose.zzzT * Geo.ANIM.zzzDy * pose.u
        }
    }
}
