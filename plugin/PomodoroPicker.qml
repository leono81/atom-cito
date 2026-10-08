import QtQuick

// El selector del pomodoro: el globo, pero con dos campos.
//
// Mismo cuerpo que Bubble.qml (tarjeta, borde de acento, 11 px) para que se
// lea como el mismo perro hablando. El campo que estás cambiando va en el
// color de acento con sus flechas (▲▼ para el foco, ◀▶ para el descanso); el
// otro queda apagado. La barrita de abajo se vacía en `expireMs`: si no hacés
// nada, se cancela solo, y cada scroll la vuelve a llenar.
//
// A diferencia del globo, este SÍ entra en la región de input mientras se
// muestra (lo agranda el servicio): con touchpad, que el puntero se corra unos
// píxeles no puede cancelar la elección.
Item {
  id: root

  property int focusMinutes: 50
  property int restMinutes: 10
  property string field: "focus"          // "focus" | "rest"
  property int expireMs: 6000
  property bool shown: false

  property color inkColor: "#f6dcac"
  property color fillColor: "#020c17"
  property color accentColor: "#faa968"
  property string fontFamily: "monospace"

  implicitWidth: card.width
  implicitHeight: card.height

  opacity: shown ? 1 : 0
  visible: opacity > 0
  Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
  transform: Translate { y: root.shown ? 0 : -4 }

  readonly property color dimColor: Qt.rgba(root.inkColor.r, root.inkColor.g, root.inkColor.b, 0.5)

  // Cada scroll la llena de nuevo; el servicio lleva el timer de verdad.
  function restartExpiry() {
    drain.stop()
    expBar.width = expTrack.width
    drain.duration = root.expireMs
    drain.start()
  }

  // El valor no se movió porque está contra el tope: un sacudón chico.
  function bump() { shake.restart() }

  onFocusMinutesChanged: popFocus.restart()
  onRestMinutesChanged: popRest.restart()

  Rectangle {
    id: card
    width: col.width + 22
    height: col.height + 16
    radius: 5
    color: root.fillColor
    border.width: 1
    border.color: root.accentColor

    transform: Translate { id: shakeX }

    Column {
      id: col
      anchors.centerIn: parent
      spacing: 6

      Row {
        spacing: 14

        // ── foco ──
        Row {
          spacing: 5
          readonly property bool on: root.field === "focus"
          readonly property color c: on ? root.accentColor : root.dimColor

          Text { text: "foco"; color: parent.c; font.family: root.fontFamily; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            opacity: parent.on ? 1 : 0
            Text { text: "▲"; color: root.accentColor; font.pixelSize: 7 }
            Text { text: "▼"; color: root.accentColor; font.pixelSize: 7 }
          }
          Text {
            id: focusNum
            text: root.focusMinutes
            color: parent.c
            font.family: root.fontFamily; font.pixelSize: 15; font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            transformOrigin: Item.Center
            SequentialAnimation on scale {
              id: popFocus; running: false
              NumberAnimation { to: 1.28; duration: 0 }
              NumberAnimation { to: 1; duration: 200; easing.type: Easing.OutCubic }
            }
          }
          Text { text: "min"; color: parent.c; font.family: root.fontFamily; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
        }

        // ── descanso ──
        Row {
          spacing: 5
          readonly property bool on: root.field === "rest"
          readonly property color c: on ? root.accentColor : root.dimColor

          Text { text: "descanso"; color: parent.c; font.family: root.fontFamily; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
          Text { text: "◀"; color: root.accentColor; font.pixelSize: 8; opacity: parent.on ? 1 : 0; anchors.verticalCenter: parent.verticalCenter }
          Text {
            text: root.restMinutes
            color: parent.c
            font.family: root.fontFamily; font.pixelSize: 15; font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            transformOrigin: Item.Center
            SequentialAnimation on scale {
              id: popRest; running: false
              NumberAnimation { to: 1.28; duration: 0 }
              NumberAnimation { to: 1; duration: 200; easing.type: Easing.OutCubic }
            }
          }
          Text { text: "min"; color: parent.c; font.family: root.fontFamily; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
          Text { text: "▶"; color: root.accentColor; font.pixelSize: 8; opacity: parent.on ? 1 : 0; anchors.verticalCenter: parent.verticalCenter }
        }
      }

      Text {
        text: "tap para arrancar · dos dedos cancela"
        color: root.dimColor
        font.family: root.fontFamily
        font.pixelSize: 10
      }

      Rectangle {
        id: expTrack
        width: parent.width
        height: 2
        radius: 1
        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)

        Rectangle {
          id: expBar
          height: parent.height
          radius: 1
          color: root.accentColor
          NumberAnimation on width { id: drain; to: 0; running: false; easing.type: Easing.Linear }
        }
      }
    }
  }

  SequentialAnimation {
    id: shake
    NumberAnimation { target: shakeX; property: "x"; to: -3; duration: 70 }
    NumberAnimation { target: shakeX; property: "x"; to: 3; duration: 140 }
    NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 70 }
  }
}
