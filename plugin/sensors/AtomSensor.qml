import QtQuick

// El tipo base de todo sensor.
//
// Un sensor es lo único del proyecto que habla con el mundo: Wayland,
// Hyprland, el reloj del sistema. El resto —reglas, poses, voz— vive de lo
// que los sensores ponen en el contexto.
//
// Contrato:
//   · `contribute()` devuelve un objeto plano que se mergea en el contexto.
//   · NUNCA puede tirar una excepción. Si algo falla, devuelve {}.
//     Un sensor roto no puede dejar mudo a Atom.
//   · Los nombres de campo van con prefijo (`gitRepo`, no `repo`): el
//     contexto es plano y compartido, y dos sensores no pueden pelearse una
//     clave.
Item {
  id: root

  property string sensorId: ""

  // Los sensores no dibujan nada.
  visible: false
  width: 0
  height: 0

  function contribute() { return ({}) }
}
