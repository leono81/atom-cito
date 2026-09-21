import QtQuick
import Quickshell
import Quickshell.Io
import "../brain/Rules.js" as Rules

// Qué ventana estás mirando — y, sobre todo, qué está corriendo adentro.
//
// El título de una terminal no sirve: acá dice "Berserker: Projects" mientras
// adentro corre herdr con seis paneles y agentes trabajando. Por eso hay una
// sonda que mira el árbol de procesos de la ventana enfocada y reporta el TUI
// más cercano a la terminal. Si abrís claude adentro de herdr, seguís
// estando en herdr.
//
// La identidad de la racha es esa etiqueta, no el appId: saber que estás en
// "foot" no dice nada y saber que estás en "herdr" lo dice todo.
AtomSensor {
  id: root
  sensorId: "focus"

  property string probePath: ""

  readonly property var toplevel: ToplevelManager.activeToplevel
  readonly property string appId: toplevel ? String(toplevel.appId || "") : ""
  readonly property string title: toplevel ? String(toplevel.title || "") : ""

  // Lo que la sonda encontró adentro de la ventana.
  property string runningProc: ""
  property int agents: 0

  // "En qué estoy". Gana lo que corre adentro; si no hay nada conocido, se
  // cae a deducirlo del appId y el título.
  readonly property string label: {
    if (root.runningProc !== "") {
      var nice = Rules.TUIS[root.runningProc]
      return nice ? nice : root.runningProc
    }
    if (root.appId === "") return ""
    try { return Rules.appLabel(root.appId, root.title) } catch (e) { return root.appId }
  }

  // La sonda corre al cambiar de ventana y cada tanto, no en cada tick: el
  // TUI puede cambiar sin que cambie la ventana (abrís nvim en la terminal
  // donde estabas), pero eso pasa en escala de minutos, no de segundos.
  onAppIdChanged: probeDelay.restart()
  onTitleChanged: probeDelay.restart()

  Timer {
    id: probeDelay
    interval: 250          // hyprctl puede ir un paso atrás de ToplevelManager
    repeat: false
    onTriggered: root.probe()
  }

  Timer {
    interval: 20000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.probe()
  }

  function probe() {
    if (root.probePath === "" || proc.running) return
    proc.command = ["timeout", "3", root.probePath]
    proc.running = true
  }

  Process {
    id: proc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var r = JSON.parse(String(text || "{}"))
          root.runningProc = String(r.proc || "")
          root.agents = Number(r.agents || 0)
        } catch (e) {
          root.runningProc = ""
          root.agents = 0
        }
      }
    }
  }

  function contribute() {
    return {
      appId: root.appId,
      title: root.title,
      app: root.label,
      proc: root.runningProc,
      agents: root.agents
    }
  }
}
