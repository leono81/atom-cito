// La maquina de ocio: que pose toca cuando no pasa nada.
//
// Es una tabla declarativa y no una cascada de `if` porque el punto de
// extension prometido en ARQUITECTURA 4.5 es "agregar una fila". Una cascada
// obliga a entender el orden completo para meter un caso nuevo; una tabla se
// lee de arriba abajo y la primera fila que aplica gana.
.pragma library

// Las poses que conoce la maquina, con el unico dato que le importa al que
// mueve. `canMove` vive tambien en cada pose QML (poses/*.qml): aca esta
// duplicado a proposito para que el cerebro pueda razonar sobre la invariante
// sin instanciar nada.
//
// LA INVARIANTE: solo `walk` puede trasladarse. `stand` vale false.
// Espeja el registro de poses/Poses.js. Si alguien agrega una pose alla y se
// olvida aca, `canMove` la trata como quieta (false) y `validateTable` avisa:
// los dos errores son del lado seguro, pero el aviso llega en `node` y no en la
// barra del usuario.
// Espejo del registro de poses (poses/Poses.js) con lo unico que este archivo
// necesita saber: cual se traslada. No se puede leer el registro real desde
// aca —es un modulo QML y esto es JS puro, que es lo que lo hace testeable—,
// asi que hay un test que falla ruidosamente si los dos se desincronizan.
var POSES = {
  "walk":    { canMove: true },
  "stand":   { canMove: false },
  "sit":     { canMove: false },
  "lie":     { canMove: false },
  "sleep":   { canMove: false },
  "scratch": { canMove: false },
  "play":    { canMove: false },
  "jump":    { canMove: true },   // la cabriola se traslada: ver Jump.qml
  "pee":     { canMove: false }
}

var MOVING_POSE = "walk"

// El ciclo por defecto (PERSONAJE 6). Las interrupciones van arriba de todo:
// "cualquiera -> parado cuando tiene algo que decir o cuando volves" tiene que
// ganarle al cronometro, y como gana la primera fila que aplica, ponerlas
// abajo (como estan dibujadas en ARQUITECTURA 4.5) haria que el perro se
// acostara justo mientras habla.
var IDLE = [
  { from: "*",     to: "stand", when: "speaking" },

  // Volves al teclado y te recibe jugando. Va ANTES que el "back -> stand"
  // de abajo, que queda de red por si la pose no esta en el registro.
  { from: "*",     to: "play",  when: "back" },
  { from: "play",  to: "stand", afterMs: 2600 },

  // El click NO esta en esta tabla: un click tiene que responder al
  // instante y esta tabla se evalua una vez por segundo. Lo maneja el
  // servicio directamente (cabriola + pedir una frase).
  { from: "*",     to: "stand", when: "back" },
  { from: "walk",  to: "stand", when: "arrived" },
  { from: "stand", to: "sit",   afterMs: 6000 },
  { from: "sit",   to: "lie",   afterMs: 14000 },

  // Se rasca de vez en cuando. A 28x20 no tiene silueta propia —se lee por el
  // movimiento, no por la forma— asi que dura poco y no siempre.
  { from: "sit",   to: "scratch", afterMs: 9000, chance: 0.35 },
  { from: "scratch", to: "sit",  afterMs: 1600 },
  { from: "lie",   to: "sleep", when: "away" },

  // Se aburre. Sin esta fila el perro llega a un hueco, se acuesta a los 20
  // segundos y no se mueve nunca mas: vivo pero aburrido.
  { from: "lie",   to: "walk",  afterMs: 600000 }
]

// Los eventos llegan del agregador como objeto ({arrived: true}) o como lista
// (["arrived"]). Se aceptan los dos: el llamador QML arma lo que le queda mas
// comodo y nadie tiene que acordarse de cual era.
function normalizeEvents(events) {
  var out = {}
  if (!events) return out
  if (Object.prototype.toString.call(events) === "[object Array]") {
    for (var i = 0; i < events.length; i++) out[String(events[i])] = true
    return out
  }
  for (var k in events) {
    if (Object.prototype.hasOwnProperty.call(events, k)) out[k] = !!events[k]
  }
  return out
}

// `poses` es opcional: el servicio puede pasar el registro vivo (el que sale de
// instanciar poses/*.qml, donde `canMove` es dato de la pose y no de esta
// tabla) para que nunca haya dos verdades.
function canMove(state, poses) {
  var table = poses || POSES
  var p = table[state]
  return !!(p && p.canMove)
}

// Que secuencia de poses hace falta para poder trasladarse desde donde esta.
// Es la traduccion literal de "nunca salta de sentado a otro lugar": si esta
// sentado, echado o dormido, primero se para y recien despues camina. El
// llamador reproduce esta lista en orden; cada paso es un cambio de pose real,
// con su cross-fade.
function stepsToWalk(current) {
  if (current === MOVING_POSE) return []
  if (current === "stand") return [MOVING_POSE]
  return ["stand", MOVING_POSE]
}

function rowApplies(row, current, elapsedMs, ev, random) {
  if (!row) return false
  if (row.from !== "*" && row.from !== current) return false
  if (row.when && !ev[row.when]) return false
  if (typeof row.afterMs === "number" && !(elapsedMs >= row.afterMs)) return false
  // La tirada va ultima para que las filas que igual no aplicaban no consuman
  // numeros del random: con el random inyectado, el orden de consumo es parte
  // del comportamiento y los tests lo fijan.
  if (typeof row.chance === "number" && !(random() < row.chance)) return false
  return true
}

// La funcion pura del modulo.
//
//   nextState(current, elapsedMs, events, table, rnd) -> "sit" | null
//
// `elapsedMs` es cuanto hace que esta en `current` (lo cronometra el llamador,
// nunca Date.now() aca adentro). Devuelve null cuando no hay cambio.
//
// Detalle importante: si la fila que gana apunta a la pose actual, devuelve
// null y NO sigue evaluando. Es lo que hace que hablar parado no lo deje
// sentarse a mitad de la frase: la interrupcion se "consume" aunque no cambie
// nada.
function nextState(current, elapsedMs, events, table, rnd) {
  var rows = table || IDLE
  var ev = normalizeEvents(events)
  var ms = Number(elapsedMs)
  if (isNaN(ms)) ms = 0
  var random = (typeof rnd === "function") ? rnd : Math.random

  for (var i = 0; i < rows.length; i++) {
    if (!rowApplies(rows[i], current, ms, ev, random)) continue
    var to = rows[i].to
    if (to === current) return null
    return to
  }
  return null
}

// Chequeo de cordura para una tabla extendida a mano. No se corre en caliente:
// esta para que el test de una fila nueva falle en `node` y no en la barra del
// usuario.
function validateTable(table, poses) {
  var known = poses || POSES
  var rows = table || IDLE
  var problems = []
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i]
    var tag = "fila " + i + " (" + row.from + "->" + row.to + ")"
    if (!row.from) problems.push(tag + ": falta `from`")
    else if (row.from !== "*" && !known[row.from]) problems.push(tag + ": pose `from` desconocida")
    if (!row.to || !known[row.to]) problems.push(tag + ": pose `to` desconocida")
    if (row.chance !== undefined && (typeof row.chance !== "number" || row.chance < 0 || row.chance > 1))
      problems.push(tag + ": `chance` fuera de [0,1]")
    if (row.afterMs !== undefined && (typeof row.afterMs !== "number" || row.afterMs < 0))
      problems.push(tag + ": `afterMs` invalido")
    // La invariante, como chequeo: una fila que declara que implica traslado
    // tiene que apuntar a la unica pose que puede trasladarse.
    if (row.moves && row.to !== MOVING_POSE)
      problems.push(tag + ": implica traslado pero no pasa por `" + MOVING_POSE + "`")
  }
  return problems
}
