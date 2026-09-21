import QtQuick
/* El directorio, no una pose: así el escáner de quickshell resuelve los
   tipos que viven adentro cuando el Loader los carga por URL. */
import "poses"
import "poses/Poses.js" as Poses

/* ════════════════════════════════════════════════════════════════════════
   Atom.qml — el renderer.

   Carga el registro, instancia lo que haya, y hace cross-fade entre lo que
   está y lo que viene. **No conoce ninguna pose por su nombre**: agregar
   una es crear el archivo y sumar una línea a poses/Poses.js, sin tocar
   este archivo (ARQUITECTURA.md §4.2).

   El color entra por propiedad, no por import: acá no se importa el tema.
   Quien nos usa le pasa `inkColor` y `fillColor`.

   Rendimiento (ARQUITECTURA.md §8): solo la pose que se está viendo tiene
   `active: true`, y una pose inactiva no corre ni un timer. El cross-fade
   es el único momento en que dos poses dibujan a la vez, y dura 160 ms.
   ════════════════════════════════════════════════════════════════════════ */

Item {
    id: atom

    /* ── El registro ──────────────────────────────────────────────────── */
    readonly property var registry: Poses.POSES

    /* Qué pose mostrar, por id. El valor inicial sale del registro. */
    property string pose: Poses.first()

    /* ── El entorno que le pasamos a la pose activa ───────────────────── */
    property color inkColor: "#e6e6e6"
    property color fillColor: "#000000"
    property bool reduceMotion: false
    property bool speaking: false

    /* Mirando a la izquierda = el conjunto espejado. Nunca un dibujo aparte. */
    property bool mirrored: false

    /* Presupuesto: cuadros por segundo del reloj de cada pose. */
    property int idleFps: 8
    property int motionFrameRate: 60

    property int fadeMs: 160

    /* ── Lo que el resto del plugin consulta ──────────────────────────── */
    /* La invariante de movimiento: el Mover pregunta acá, y acá se
       responde con el dato que declaró la pose activa. */
    readonly property bool canMove: current !== null && current.canMove
    readonly property Item current: _current
    property Item _current: null

    implicitWidth: 28
    implicitHeight: 20

    transform: Scale {
        origin.x: atom.width / 2
        xScale: atom.mirrored ? -1 : 1
    }

    Repeater {
        model: atom.registry

        delegate: Loader {
            id: slot
            required property var modelData

            anchors.fill: parent
            asynchronous: false
            source: Qt.resolvedUrl("poses/" + modelData.file)

            readonly property bool chosen: modelData.id === atom.pose

            opacity: chosen ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation { duration: atom.fadeMs; easing.type: Easing.InOutQuad }
            }

            onChosenChanged: if (chosen && item) atom._current = item
            onLoaded: if (chosen) atom._current = item

            /* Bindings y no asignaciones: el color y el estado cambian en
               caliente (tema, `speaking`, monitor sin foco). */
            Binding {
                target: slot.item; property: "active"
                value: slot.visible; restoreMode: Binding.RestoreNone
            }
            Binding {
                target: slot.item; property: "inkColor"
                value: atom.inkColor; restoreMode: Binding.RestoreNone
            }
            Binding {
                target: slot.item; property: "fillColor"
                value: atom.fillColor; restoreMode: Binding.RestoreNone
            }
            Binding {
                target: slot.item; property: "reduceMotion"
                value: atom.reduceMotion; restoreMode: Binding.RestoreNone
            }
            Binding {
                target: slot.item; property: "speaking"
                value: atom.speaking; restoreMode: Binding.RestoreNone
            }
            Binding {
                target: slot.item; property: "idleFps"
                value: atom.idleFps; restoreMode: Binding.RestoreNone
            }
            Binding {
                target: slot.item; property: "motionFps"
                value: atom.motionFrameRate; restoreMode: Binding.RestoreNone
            }
        }
    }
}
