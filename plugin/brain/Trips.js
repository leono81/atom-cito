.pragma library

/* ══════════════════════════════════════════════════════════════════════════
   Trips.js — planificador de viajes.

   Hasta acá Atom solo sabía ir de un hueco a otro: un tramo, un destino. Los
   paseos largos, la vuelta por el borde de la pantalla y la cabriola piden
   varios tramos encadenados, con pausas y con cambios de pose en el medio.

   Un VIAJE es una lista de TRAMOS. Cada tramo:

     { x,          adónde va (en píxeles de la barra)
       speed,      px/s para ese tramo; por defecto el del Mover
       pose,       en qué pose viaja; por defecto la que camina
       wrapTo,     al llegar, teletransportarse a esta x (salir por un borde
                   y entrar por el otro). Es instantáneo y no se ve: el perro
                   ya está fuera de cuadro.
       holdPose,   al llegar, quedarse en esta pose…
       holdMs,     …este rato
       pauseMs }   al llegar, esperar antes del tramo siguiente

   Todo acá es JS puro y funciones sin estado: el tiempo y el azar entran por
   parámetro para poder probarlo con `node`.
   ══════════════════════════════════════════════════════════════════════════ */

var DEFAULT_SPEED = 55
var DASH_SPEED = 210
var HOP_SPEED = 190

function pickRandom(list, rnd) {
  var r = (typeof rnd === "function") ? rnd : Math.random
  if (!list || list.length === 0) return null
  return list[Math.floor(r() * list.length)]
}

function num(v, dflt) {
  var n = Number(v)
  return isFinite(n) ? n : dflt
}

/* ── 1 · de hueco a hueco ────────────────────────────────────────────────
   El paseo corto de siempre: un tramo, y se queda. */
function toStop(stop) {
  if (!stop) return []
  return [{ x: num(stop.x, 0) }]
}

/* ── 2 · de punta a punta ────────────────────────────────────────────────
   Cruza la barra entera, se queda un momento, y vuelve a un hueco. */
function endToEnd(barWidth, dogWidth, currentX, stops) {
  var w = num(barWidth, 0), d = num(dogWidth, 28), x = num(currentX, 0)
  if (w <= d * 2) return []

  // Va al borde que tenga más lejos: cruzar dos píxeles no es cruzar.
  var far = (x > w / 2) ? 2 : w - d - 2
  var back = stops && stops.length ? num(stops[stops.length - 1].x, far) : far

  return [
    { x: far, pauseMs: 1400 },
    { x: back }
  ]
}

/* ── 3 · la vuelta al mundo ──────────────────────────────────────────────
   Sale por un borde y entra por el otro. No hay truco: la ventana de Atom
   ocupa el ancho completo de la pantalla, así que "salir de cuadro" es
   caminar un poco más allá del borde. El salto al otro lado ocurre cuando
   ya no se lo ve. */
function wrapAround(barWidth, dogWidth, goingLeft, stops) {
  var w = num(barWidth, 0), d = num(dogWidth, 28)
  if (w <= d * 2) return []

  var exitX = goingLeft ? -d - 6 : w + 6
  var enterX = goingLeft ? w + 6 : -d - 6
  var home = stops && stops.length
    ? num(stops[Math.floor(stops.length / 2)].x, Math.round(w / 2))
    : Math.round(w / 2)

  return [
    { x: exitX, wrapTo: enterX },
    { x: home }
  ]
}

/* ── 4 · ronda con paradas ───────────────────────────────────────────────
   Visita los huecos en orden, parando en cada uno. El único paseo que sigue
   respetando la regla en todo momento: nunca se detiene encima de nada. */
function patrol(stops, currentX) {
  if (!stops || stops.length === 0) return []
  var x = num(currentX, 0)

  // Empieza por el hueco más lejano para que la ronda se note.
  var ordered = stops.slice().sort(function (a, b) { return a.x - b.x })
  if (x > (ordered[0].x + ordered[ordered.length - 1].x) / 2) ordered.reverse()

  var legs = []
  for (var i = 0; i < ordered.length; i++) {
    legs.push({ x: num(ordered[i].x, 0), pauseMs: i === ordered.length - 1 ? 0 : 2200 })
  }
  return legs
}

/* ── 5 · la corrida ──────────────────────────────────────────────────────
   Casi siempre quieto, y cuando se mueve se nota: cruza rápido y vuelve. */
function dash(barWidth, dogWidth, currentX, stops) {
  var w = num(barWidth, 0), d = num(dogWidth, 28), x = num(currentX, 0)
  if (w <= d * 2) return []
  var far = (x > w / 2) ? 2 : w - d - 2
  var home = stops && stops.length ? num(stops[0].x, x) : x

  return [
    { x: far, speed: DASH_SPEED, pauseMs: 900 },
    { x: home, speed: DASH_SPEED }
  ]
}

/* ── 6 · la cabriola ─────────────────────────────────────────────────────
   Un salto grande y, al caer, un rebote corto. Los dos tramos viajan en la
   pose `jump`, que es la segunda —y única otra— pose que declara que se
   traslada. */
function cabriola(currentX, barWidth, dogWidth, rnd, jumpPose) {
  var w = num(barWidth, 0), d = num(dogWidth, 28), x = num(currentX, 0)
  var r = (typeof rnd === "function") ? rnd : Math.random
  var pose = jumpPose || "jump"

  // Salta hacia donde haya lugar; si hay lugar para los dos lados, al azar.
  var room = { left: x - 4, right: w - d - x - 4 }
  var dir = (room.right < 90) ? -1 : (room.left < 90 ? 1 : (r() < 0.5 ? -1 : 1))

  var big = 84 * dir
  var bounce = 20 * dir
  var first = Math.max(2, Math.min(x + big, w - d - 2))
  var second = Math.max(2, Math.min(first + bounce, w - d - 2))

  return [
    { x: first, speed: HOP_SPEED, pose: pose, pauseMs: 90 },
    { x: second, speed: HOP_SPEED, pose: pose }
  ]
}

/* ── 7 · hacerle pis a algo ──────────────────────────────────────────────
   Va al lugar elegido, levanta la pata un rato, y después se va a un hueco
   como si nada. */
function peeTrip(spot, holdMs, stops, peePose) {
  if (!spot) return []
  var after = stops && stops.length ? num(stops[0].x, num(spot.x, 0)) : num(spot.x, 0)
  return [
    { x: num(spot.x, 0), holdPose: peePose || "pee", holdMs: num(holdMs, 4200) },
    { x: after }
  ]
}

/* ── El sorteo ───────────────────────────────────────────────────────────
   El usuario pidió los cuatro paseos al azar. `toStop` entra también, para
   que a veces simplemente se mude de hueco sin hacer un número. */
var WALKS = ["stop", "endToEnd", "wrap", "patrol", "dash"]

function randomWalk(ctx, rnd) {
  var r = (typeof rnd === "function") ? rnd : Math.random
  var kind = pickRandom(WALKS, r)
  return { kind: kind, legs: planWalk(kind, ctx, r) }
}

function planWalk(kind, ctx, rnd) {
  var c = ctx || {}
  var stops = c.stops || []
  var r = (typeof rnd === "function") ? rnd : Math.random

  if (kind === "endToEnd") return endToEnd(c.barWidth, c.dogWidth, c.currentX, stops)
  if (kind === "wrap") return wrapAround(c.barWidth, c.dogWidth, r() < 0.5, stops)
  if (kind === "patrol") return patrol(stops, c.currentX)
  if (kind === "dash") return dash(c.barWidth, c.dogWidth, c.currentX, stops)
  return toStop(c.stop || stops[0])
}
