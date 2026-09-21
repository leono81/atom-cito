import QtQuick

// El que mueve a Atom por la barra, y el guardián de la invariante:
//
//     Atom solo cambia de posición mientras la pose activa lo permite.
//
// Está escrito para que esa regla NO dependa de que el que llama se acuerde.
// Dos defensas, las dos estructurales:
//
//   1. `walkTo()` consulta `pose.canMove` y **se niega** devolviendo false.
//      No encola el pedido ni lo corrige después: lo rechaza en el borde.
//   2. `onPoseChanged` congela la posición solo. Cambiar de pose a mitad de
//      camino no puede dejar a un perro sentado deslizándose, porque el
//      freeze no lo dispara el llamador: lo dispara el cambio mismo.
//
// Hoy `walk` es la única pose con `canMove: true` — `stand` incluido vale
// false. Un perro parado tampoco se traslada: para moverse, primero camina.
QtObject {
  id: root

  // La pose activa, inyectada por el renderer. Tiene que exponer `canMove`.
  property var pose: null

  // Posición horizontal del perro dentro de la ventana, en píxeles.
  property real pos: 0

  // Velocidad de marcha. Baja a propósito: es un perro, no un cursor.
  property real speed: 55

  // Hacia dónde mira. El dibujo se voltea con scaleX(-1); no hay un juego
  // de poses espejado.
  property bool facingLeft: false

  readonly property bool canMove: pose ? pose.canMove === true : false
  readonly property bool moving: walkAnim.running

  signal arrived(real at)
  signal refused(real target, string reason)

  // Devuelve true si el viaje arrancó. El `false` es información, no un
  // fracaso: el llamador tiene que pasar a `walk` y volver a pedirlo.
  function walkTo(target) {
    if (!isFinite(target)) {
      root.refused(target, "target no es un número")
      return false
    }
    if (!root.canMove) {
      root.refused(target, "la pose activa no se traslada: "
                            + (pose ? pose.poseId : "ninguna"))
      return false
    }
    if (Math.abs(target - root.pos) < 1) {
      root.arrived(root.pos)
      return true
    }

    root.facingLeft = target < root.pos

    walkAnim.stop()
    walkAnim.from = root.pos
    walkAnim.to = target
    walkAnim.duration = Math.max(180, Math.round(Math.abs(target - root.pos)
                                                 / Math.max(1, root.speed) * 1000))
    walkAnim.start()
    return true
  }

  // Detiene el viaje dejando la posición donde esté. QML no revierte la
  // propiedad al parar una animación, así que esto es exactamente "quedate
  // acá" y no "volvé al principio".
  function freeze() {
    if (walkAnim.running) walkAnim.stop()
  }

  // La defensa que no depende de nadie: cualquier cambio de pose congela.
  onPoseChanged: root.freeze()

  property Animation walkAnim: NumberAnimation {
    target: root
    property: "pos"
    easing.type: Easing.Linear
    onFinished: root.arrived(root.pos)
  }
}
