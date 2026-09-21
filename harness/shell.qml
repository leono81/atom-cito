import QtQuick
import Quickshell
import "plugin" as Plugin
import "plugin/poses/Poses.js" as Poses

/* ════════════════════════════════════════════════════════════════════════
   Banco de pruebas de Atom. Desechable.

   Instancia aparte de quickshell: su propia ventana flotante. No toca la
   barra del usuario ni su configuración.

       qs -p ~/Projects/atom/harness

   El modo sale de /tmp/atom-mode.txt (si no existe, "all"):

     all              las cinco poses grandes + la fila a tamaño real +
                      un perro que va cambiando de pose, y las capturas.
     one:<pose>:<fps> un solo perro, para medir CPU con top/ps.

   `plugin` es un symlink a ../plugin: quickshell no importa módulos de
   afuera de la carpeta de configuración.
   ════════════════════════════════════════════════════════════════════════ */

ShellRoot {
    id: root

    property color bg: "#12161b"
    property color ink: "#e8e2d6"
    property string shotDir: "/home/leono/Projects/atom/harness/shots/"

    property string mode: "all"
    property var modeArgs: mode.split(":")
    readonly property bool measuring: modeArgs[0] === "one"

    Component.onCompleted: {
        var xhr = new XMLHttpRequest();
        try {
            xhr.open("GET", "file:///tmp/atom-mode.txt", false);
            xhr.send();
            if (xhr.responseText && xhr.responseText.trim().length)
                root.mode = xhr.responseText.trim();
        } catch (e) { /* sin archivo: modo all */ }
        console.log("[atom] modo:", root.mode);

        /* La invariante, dicha en voz alta: solo `walk` puede trasladarse. */
        for (var i = 0; i < Poses.POSES.length; i++) {
            var id = Poses.POSES[i].id;
            probe.pose = id;
            console.log("[atom] pose", id,
                        "· canMove =", probe.canMove,
                        "· archivo", Poses.POSES[i].file);
        }
        probe.pose = Poses.first();
    }

    /* Un Atom chiquito, solo para interrogar al registro. */
    Plugin.Atom { id: probe; width: 28; height: 20 }

    FloatingWindow {
        id: win
        title: "Atom · banco de pruebas"
        implicitWidth: root.measuring ? 300 : 1320
        implicitHeight: root.measuring ? 220 : 700
        color: root.bg

        /* ── Modo medición: un solo perro ─────────────────────────────── */
        Plugin.Atom {
            visible: root.measuring
            anchors.centerIn: parent
            /* El cuarto campo es el ancho en px: 28 = tamaño real. */
            width: root.modeArgs.length > 3 ? parseInt(root.modeArgs[3]) : 238
            height: Math.round(width * 20 / 28)
            pose: root.modeArgs.length > 1 ? root.modeArgs[1] : Poses.first()
            /* El tercer campo es el frame rate: el de la caminata y el de
               quieto a la vez. 0 = todo congelado, el piso de la medición. */
            motionFrameRate: root.modeArgs.length > 2 ? parseInt(root.modeArgs[2]) : 60
            idleFps: root.modeArgs.length > 2 ? parseInt(root.modeArgs[2]) : 8
            inkColor: root.ink
            fillColor: root.bg
        }

        /* ── Modo normal ──────────────────────────────────────────────── */
        Column {
            visible: !root.measuring
            anchors.centerIn: parent
            spacing: 26

            /* Las cinco poses, grandes */
            Rectangle {
                id: bigCard
                color: root.bg
                width: bigRow.width + 48
                height: bigRow.height + 40
                Row {
                    id: bigRow
                    anchors.centerIn: parent
                    spacing: 14
                    Repeater {
                        model: Poses.POSES
                        delegate: Column {
                            required property var modelData
                            spacing: 8
                            Plugin.Atom {
                                width: 238; height: 168
                                pose: modelData.id
                                inkColor: root.ink
                                fillColor: root.bg
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.id
                                color: "#6d7c8a"
                                font.pixelSize: 13
                                font.family: "monospace"
                            }
                        }
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 40

                /* La misma fila a tamaño real: 28 × 20 */
                Rectangle {
                    id: realCard
                    color: root.bg
                    width: realRow.width + 24
                    height: 44
                    Row {
                        id: realRow
                        anchors.centerIn: parent
                        spacing: 16
                        Repeater {
                            model: Poses.POSES
                            delegate: Plugin.Atom {
                                required property var modelData
                                width: 28; height: 20
                                pose: modelData.id
                                inkColor: root.ink
                                fillColor: root.bg
                            }
                        }
                    }
                }

                /* Espejado (caminando a la izquierda) y hablando. */
                Rectangle {
                    id: extrasCard
                    color: root.bg
                    width: extrasRow.width + 20
                    height: 144
                    Row {
                        id: extrasRow
                        anchors.centerIn: parent
                        spacing: 6
                        Plugin.Atom {
                            id: mirroredDog
                            width: 170; height: 120
                            pose: Poses.POSES[1].id      // la que puede trasladarse
                            mirrored: true
                            inkColor: root.ink
                            fillColor: root.bg
                        }
                        Plugin.Atom {
                            id: talkingDog
                            width: 170; height: 120
                            pose: Poses.first()
                            speaking: true
                            inkColor: "#d9a441"          // acento del tema
                            fillColor: root.bg
                        }
                    }
                }

                /* Un perro solo, cambiando de pose: para ver el cross-fade */
                Rectangle {
                    id: cycleCard
                    color: root.bg
                    width: 200; height: 144
                    Plugin.Atom {
                        id: cycler
                        anchors.fill: parent
                        inkColor: root.ink
                        fillColor: root.bg
                        property int idx: 0
                        pose: Poses.POSES[idx].id
                        Timer {
                            interval: 1200; running: true; repeat: true
                            onTriggered: cycler.idx = (cycler.idx + 1) % Poses.POSES.length
                        }
                    }
                }
            }
        }

        /* ── Capturas ─────────────────────────────────────────────────── */
        Timer {
            interval: 1400
            running: !root.measuring
            repeat: false
            onTriggered: {
                bigCard.grabToImage(function (r) {
                    r.saveToFile(root.shotDir + "poses-grande.png");
                    console.log("[atom] shot: poses-grande.png");
                });
                realCard.grabToImage(function (r) {
                    r.saveToFile(root.shotDir + "poses-real.png");
                    console.log("[atom] shot: poses-real.png");
                });
            }
        }

        /* Un segundo frame de la caminata, para ver que las patas se mueven. */
        Timer {
            interval: 1650
            running: !root.measuring
            repeat: false
            onTriggered: bigCard.grabToImage(function (r) {
                r.saveToFile(root.shotDir + "poses-grande-b.png");
                console.log("[atom] shot: poses-grande-b.png");
            })
        }

        /* Espejado + hablando. */
        Timer {
            interval: 1500
            running: !root.measuring
            repeat: false
            onTriggered: extrasCard.grabToImage(function (r) {
                r.saveToFile(root.shotDir + "extras.png");
                console.log("[atom] shot: extras.png");
            })
        }

        /* El parpadeo no se puede capturar a mano: se lo escucha. */
        Connections {
            target: mirroredDog.current
            function onBlinkingChanged() {
                if (mirroredDog.current && mirroredDog.current.blinking)
                    console.log("[atom] parpadeo en", Math.round(Date.now() / 100) / 10);
            }
        }

        /* Tres frames seguidos del que cambia de pose: el cross-fade. */
        Timer {
            id: fadeShots
            property int n: 0
            interval: 55
            running: !root.measuring
            repeat: true
            onTriggered: {
                if (cycler.idx !== 1) return;          // justo cuando entra la segunda pose
                var k = n++;
                if (k > 2) { fadeShots.running = false; return; }
                cycleCard.grabToImage(function (r) {
                    r.saveToFile(root.shotDir + "fade-" + k + ".png");
                    console.log("[atom] shot: fade-" + k + ".png");
                });
            }
        }
    }
}
