import QtQuick
import Quickshell.Wayland

// Si estás o no en el teclado.
//
// `IdleMonitor` NO da segundos: da un booleano que se prende al cruzar el
// umbral. La duración de la ausencia la cronometra Clocks.js a partir de las
// transiciones, no se lee de ningún lado.
//
// `respectInhibitors: false` a propósito: queremos medir input real. Un video
// reproduciéndose inhibe el idle del sistema, pero mirar un video sin tocar
// el teclado es exactamente la pausa que nos interesa detectar.
AtomSensor {
  id: root
  sensorId: "idle"

  property int breakSeconds: 180
  signal idleFlipped(bool isIdle)

  readonly property bool isIdle: monitor.isIdle

  IdleMonitor {
    id: monitor
    enabled: true
    timeout: Math.max(5, root.breakSeconds)
    respectInhibitors: false
    onIsIdleChanged: root.idleFlipped(monitor.isIdle)
  }

  function contribute() {
    return { idle: monitor.isIdle }
  }
}
