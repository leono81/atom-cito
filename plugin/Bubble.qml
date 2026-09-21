import QtQuick

// El globo.
//
// Deliberadamente fuera de la región de input: es informativo, no
// interactivo. Un click encima pasa de largo a lo que haya abajo, que es la
// forma más barata de cumplir "nunca interrumpe". Se va solo.
//
// Vive dentro de la MISMA ventana que el perro. Dos superficies separadas
// harían que el globo se arrastre un frame detrás al caminar, y que al
// aparecer se mapee arriba de todo en la capa Overlay.
Item {
  id: root

  property string text: ""
  property color inkColor: "#f6dcac"
  property color fillColor: "#020c17"
  property color borderColor: "#faa968"
  property string fontFamily: "monospace"
  property int maxWidth: 320

  property bool shown: false

  implicitWidth: card.width
  implicitHeight: card.height

  opacity: shown ? 1 : 0
  visible: opacity > 0
  Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

  // Un pelín más abajo cuando está oculto: el movimiento hace que el ojo lo
  // encuentre sin que haga falta un sonido ni un color fuerte.
  transform: Translate { y: root.shown ? 0 : -4 }

  Rectangle {
    id: card
    // OJO: el ancho de la tarjeta sale del ancho REAL del texto (ya
    // envuelto), no del implicitWidth, que es el de una sola línea sin
    // cortar. Usar el segundo hace una tarjeta enorme con el texto envuelto
    // adentro.
    width: label.width + 22
    height: label.implicitHeight + 16
    radius: 5
    color: root.fillColor
    border.width: 1
    border.color: root.borderColor

    Text {
      id: label
      anchors.centerIn: parent
      width: Math.min(root.maxWidth, implicitWidth)
      horizontalAlignment: Text.AlignLeft
      text: root.text
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
      color: root.inkColor
      font.family: root.fontFamily
      font.pixelSize: 11
      lineHeight: 1.35
    }
  }
}
