import QtQuick

// La hora. Existe como sensor y no como `new Date()` suelto en las reglas
// para que el contexto tenga una sola forma de saber qué hora es, y para que
// un test pueda inyectar otra.
AtomSensor {
  id: root
  sensorId: "clock"

  property int hour: 0
  property string clock: ""

  function refresh() {
    var d = new Date()
    root.hour = d.getHours()
    root.clock = Qt.formatDateTime(d, "HH:mm")
  }

  // Medio minuto alcanza: nadie mira la barra esperando el segundo exacto.
  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  function contribute() {
    return { hour: root.hour, clock: root.clock }
  }
}
