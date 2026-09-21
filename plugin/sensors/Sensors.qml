import QtQuick

// El agregador: junta lo que aporta cada sensor en un solo objeto plano.
//
// Agregar un sensor es crear el archivo y sumarlo a `all`. Nada más del
// sistema cambia: las reglas leen campos del contexto y no saben de dónde
// salieron.
Item {
  id: root
  visible: false

  property int breakSeconds: 180
  property string probePath: ""

  // Ojo con los nombres: `focus` es propiedad FINAL de Item y un alias con
  // ese nombre hace que el tipo entero no cargue.
  readonly property alias windowFocus: focusSensor
  readonly property alias idleState: idleSensor
  readonly property alias timeOfDay: clockSensor

  FocusSensor { id: focusSensor; probePath: root.probePath }
  IdleSensor  { id: idleSensor; breakSeconds: root.breakSeconds }
  ClockSensor { id: clockSensor }

  readonly property var all: [focusSensor, idleSensor, clockSensor]

  // Un sensor que falla aporta {} y el resto sigue andando.
  function context() {
    var out = {}
    for (var i = 0; i < root.all.length; i++) {
      var s = root.all[i]
      var part = null
      try { part = s.contribute() } catch (e) {
        console.log("[atom] sensor " + s.sensorId + " falló: " + e)
        part = null
      }
      if (!part) continue
      for (var k in part) out[k] = part[k]
    }
    return out
  }
}
