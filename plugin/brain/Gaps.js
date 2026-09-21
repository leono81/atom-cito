// Los huecos de la barra. JS puro y sin un solo import de QML a proposito: esto
// es lo que decide donde se para el perro, y decidirlo mal se ve enseguida en
// pantalla, asi que tiene que poder probarse con `node` sin levantar el shell.
//
// Todas las funciones son puras: entran rectangulos, salen numeros. El que mide
// (BarGeometry.qml) re-mide en cada tick y nos pasa el resultado crudo; aca no
// se cachea nada, porque el ancho de un widget cambia solo (el reloj con
// formato `dddd HH:mm` mide distinto cada minuto).
.pragma library

// Dos obstaculos separados por menos que esto cuentan como uno solo. No es
// "clearance" contra el widget: es el umbral de fusion. Un hueco de 4 px entre
// dos iconos no es un hueco, es ruido de layout, y tratarlo como hueco real
// haria aparecer huecos fantasma cada vez que la barra reacomoda un pixel.
var DEFAULT_PADDING = 6

function optNumber(opts, key, dflt) {
  if (!opts) return dflt
  var v = opts[key]
  if (typeof v !== "number" || isNaN(v)) return dflt
  return v
}

// Rectangulos utiles: los de ancho positivo. Se filtra por `w > 0` y NO por
// `visible`, porque en la barra real hay tres widgets montados, visibles y con
// ancho cero (tray, keyboard-layout, system-update). Medido en SPIKES U1.
function usableObstacles(obstacles) {
  var out = []
  if (!obstacles) return out
  for (var i = 0; i < obstacles.length; i++) {
    var o = obstacles[i]
    if (!o) continue
    var x = Number(o.x)
    var w = Number(o.w)
    if (isNaN(x) || isNaN(w)) continue
    if (w <= 0) continue
    out.push({ a: x, b: x + w })
  }
  return out
}

// Fusiona pegados y superpuestos en bloques unicos. Los widgets de una seccion
// estan literalmente pegados (x + w del uno == x del otro), asi que sin esto
// cada frontera entre iconos figuraria como un hueco de ancho cero.
function mergeObstacles(obstacles, padding) {
  var pad = (typeof padding === "number" && !isNaN(padding)) ? padding : DEFAULT_PADDING
  var items = usableObstacles(obstacles)
  items.sort(function (p, q) { return p.a - q.a })

  var merged = []
  for (var i = 0; i < items.length; i++) {
    var it = items[i]
    var last = merged.length ? merged[merged.length - 1] : null
    if (last && it.a - last.b <= pad) {
      if (it.b > last.b) last.b = it.b
    } else {
      merged.push({ a: it.a, b: it.b })
    }
  }
  return merged
}

// Los huecos libres de la barra, incluidos los dos bordes. Devuelve pares
// {a, b} en coordenadas de la barra, sin filtrar por ancho todavia.
function gaps(barWidth, obstacles, padding) {
  var width = Number(barWidth)
  if (isNaN(width) || width <= 0) return []

  var blocks = mergeObstacles(obstacles, padding)
  var out = []
  var cursor = 0
  for (var i = 0; i < blocks.length; i++) {
    var b = blocks[i]
    // Un obstaculo que arranca antes del borde o se sale de la barra no rompe
    // nada: se recorta contra la barra y sigue.
    var a = b.a < 0 ? 0 : b.a
    var z = b.b > width ? width : b.b
    if (a > cursor) out.push({ a: cursor, b: a })
    if (z > cursor) cursor = z
  }
  if (cursor < width) out.push({ a: cursor, b: width })
  return out
}

// El contrato publico: donde puede pararse el perro.
//
//   restStops(barWidth, obstacles, dogWidth) -> [ {x, gapA, gapB}, ... ]
//
// `x` es la esquina izquierda del perro, centrado en el hueco y acotado para
// que no se salga de la barra. Se redondea a entero: media decima de pixel no
// se ve, pero hace que dos mediciones consecutivas parezcan destinos distintos
// y el perro se mueva sin motivo.
//
// Sin huecos validos devuelve [] y el llamador deja al perro donde esta. Nunca
// se superpone "por esta vez" (PERSONAJE 5).
function restStops(barWidth, obstacles, dogWidth, opts) {
  var width = Number(barWidth)
  var dog = Number(dogWidth)
  if (isNaN(width) || width <= 0) return []
  if (isNaN(dog) || dog <= 0) return []

  var pad = optNumber(opts, "padding", DEFAULT_PADDING)
  var free = gaps(width, obstacles, pad)
  var stops = []
  for (var i = 0; i < free.length; i++) {
    var g = free[i]
    if (g.b - g.a < dog) continue       // un hueco mas chico que el perro no es un hueco
    var x = Math.round((g.a + g.b) / 2 - dog / 2)
    if (x < 0) x = 0
    if (x + dog > width) x = width - dog
    stops.push({ x: x, gapA: g.a, gapB: g.b })
  }
  return stops
}

// Elige un destino distinto al actual. `minMove` evita el viaje de tres pixeles
// que se lee como un tic nervioso en vez de como una caminata.
//
// Con varios candidatos elige al azar (el random se inyecta para poder
// testearlo). Si el unico hueco es donde ya esta, lo devuelve igual: el
// llamador comparara `x` y decidira no caminar.
function pickStop(stops, currentX, minMove, rnd) {
  if (!stops || stops.length === 0) return null
  var gate = (typeof minMove === "number" && !isNaN(minMove)) ? minMove : 0
  var here = Number(currentX)
  if (isNaN(here)) here = 0
  var random = (typeof rnd === "function") ? rnd : Math.random

  var candidates = []
  for (var i = 0; i < stops.length; i++) {
    if (Math.abs(stops[i].x - here) >= gate) candidates.push(stops[i])
  }
  if (candidates.length === 0) return nearestStop(stops, here)

  var k = Math.floor(random() * candidates.length)
  if (k < 0) k = 0
  if (k >= candidates.length) k = candidates.length - 1
  return candidates[k]
}

function nearestStop(stops, x) {
  var best = null
  var bestD = 0
  for (var i = 0; i < stops.length; i++) {
    var d = Math.abs(stops[i].x - x)
    if (best === null || d < bestD) { best = stops[i]; bestD = d }
  }
  return best
}

// El hueco donde esta sentado se puede invalidar solo: el reloj del usuario usa
// formato `dddd HH:mm` y "miercoles" mide bastante mas que "lunes". Esto detecta
// que el perro quedo pisando un widget, para que el llamador lo haga levantarse
// y caminar (PERSONAJE 5.1: gana la invariante de movimiento, nunca se
// recoloca de prepo).
function isStillValid(currentX, dogWidth, obstacles, opts) {
  var x = Number(currentX)
  var dog = Number(dogWidth)
  if (isNaN(x) || isNaN(dog) || dog <= 0) return false

  // Aca no se fusiona con padding: la pregunta es si el perro pisa un widget de
  // verdad, no si el hueco donde esta seria elegible desde cero. Fusionar haria
  // que el perro se levantara por un vecino que no lo toca.
  var items = usableObstacles(obstacles)
  var a = x
  var b = x + dog
  var clear = optNumber(opts, "clearance", 0)
  for (var i = 0; i < items.length; i++) {
    if (items[i].b > a - clear && items[i].a < b + clear) return false
  }
  return true
}
