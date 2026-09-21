import QtQuick

/* Una gota: un círculo macizo, sin contorno — la pieza más chica del
   juego. Nace para el chorrito de `pee`, pero no sabe nada de esa pose:
   es "un punto de tinta en coordenadas de la spec", así que sirve igual
   para migas, agua o lo que venga.

   `spec` = {cx, cy, r} en unidades del viewBox de 34 × 24. `dx` / `dy`
   son el desplazamiento animado, también en unidades: la pose los calcula
   desde su reloj y acá entran como dos bindings numéricos, sin fabricar
   un objeto nuevo por cuadro.

   La opacidad la maneja quien la usa (es una propiedad de Item). */
Rectangle {
    id: drop

    property real u: 1
    property var spec: ({ cx: 0, cy: 0, r: 0.5 })
    property real dx: 0
    property real dy: 0
    property color ink: "#ffffff"

    x: (spec.cx + dx - spec.r) * u
    y: (spec.cy + dy - spec.r) * u
    width: spec.r * 2 * u
    height: spec.r * 2 * u
    radius: width / 2

    color: ink
    antialiasing: true
}
