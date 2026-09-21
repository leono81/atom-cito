// Los dos relojes: racha (misma app) y sesion (desde la ultima pausa real).
//
// Todo con el tiempo inyectado por parametro. Nunca Date.now() aca adentro: si
// el reloj lo lee el modulo, probar "que pasa a los 91 segundos" obliga a
// esperar 91 segundos, y entonces no se prueba.
//
// El estado es un objeto plano que entra y sale de las funciones. No hay nada
// mutable a nivel modulo: cada funcion devuelve un estado nuevo, porque el
// servicio se destruye y se recrea ante cualquier escritura de shell.json y
// tener el estado en un solo lugar serializable es lo que hace que eso no
// duela (ARQUITECTURA 6).
.pragma library

var DEFAULTS = {
  graceMs: 90000,          // alt-tabear menos de esto no corta la racha
  pauseMs: 180000,         // 3 min sin input = pausa real
  justReturnedMs: 60000,   // cuanto dura el "recien volvio" para la regla welcome
  version: 1
}

function config(opts) {
  var cfg = {}
  for (var k in DEFAULTS) if (Object.prototype.hasOwnProperty.call(DEFAULTS, k)) cfg[k] = DEFAULTS[k]
  if (opts) for (var j in opts) {
    if (Object.prototype.hasOwnProperty.call(opts, j) && typeof opts[j] === "number" && !isNaN(opts[j])) cfg[j] = opts[j]
  }
  return cfg
}

function create(nowMs, app, opts) {
  var t = num(nowMs, 0)
  return {
    app: String(app || ""),        // la app duena de la racha
    streakStartMs: t,
    // Una "excursion" es el rato que estuviste fuera de la app de la racha.
    // El cronometro de los 90 s corre sobre la excursion entera, no sobre cada
    // ventana: saltar de A a B a C a D de a 80 segundos no puede conservar
    // para siempre una racha en A que hace rato abandonaste.
    excursionStartMs: 0,
    pendingApp: "",                // que hay enfocado durante la excursion
    pendingSinceMs: 0,             // desde cuando (de ahi arranca la racha nueva)
    sessionStartMs: t,
    idle: false,
    idleSinceMs: 0,
    lastAwayMs: 0,                 // cuanto duro la ultima pausa real
    returnedAtMs: 0
  }
}

function num(v, dflt) {
  var n = Number(v)
  return (typeof n === "number" && !isNaN(n)) ? n : dflt
}

function copy(state) {
  var s = create(0, "")
  if (!state) return s
  for (var k in s) if (Object.prototype.hasOwnProperty.call(s, k)) {
    s[k] = (state[k] === undefined || state[k] === null) ? s[k] : state[k]
  }
  return s
}

// Resuelve una excursion vencida. Se llama desde todas las entradas publicas
// porque el corte de racha no lo dispara ningun evento: pasa solo, por el mero
// paso del tiempo, y si solo se evaluara al enfocar una ventana la racha
// quedaria viva para siempre mientras no toques nada.
function settle(state, nowMs, opts) {
  var cfg = config(opts)
  var s = copy(state)
  var t = num(nowMs, 0)
  if (s.excursionStartMs > 0 && t - s.excursionStartMs >= cfg.graceMs) {
    s.app = s.pendingApp
    s.streakStartMs = s.pendingSinceMs
    s.excursionStartMs = 0
    s.pendingApp = ""
    s.pendingSinceMs = 0
  }
  return s
}

function onFocus(state, app, nowMs, opts) {
  var t = num(nowMs, 0)
  var s = settle(state, t, opts)
  var id = String(app || "")

  if (s.app === "") {                 // primer foco: la racha arranca aca
    s.app = id
    s.streakStartMs = t
    return s
  }
  if (id === s.app) {                 // volviste: la excursion no existio
    s.excursionStartMs = 0
    s.pendingApp = ""
    s.pendingSinceMs = 0
    return s
  }
  if (s.excursionStartMs === 0) s.excursionStartMs = t
  s.pendingApp = id
  s.pendingSinceMs = t                // si la excursion vence, la racha cuenta desde aca
  return s
}

// IdleMonitor da un booleano por umbral, no segundos. Asi que el umbral del
// monitor puede ser cualquiera (30 s, 60 s) y los 3 minutos de "pausa real" los
// cronometramos nosotros entre el true y el false.
function onIdleChanged(state, isIdle, nowMs, opts) {
  var cfg = config(opts)
  var t = num(nowMs, 0)
  var s = settle(state, t, opts)

  if (isIdle) {
    if (!s.idle) { s.idle = true; s.idleSinceMs = t }   // un true repetido no reinicia el cronometro
    return s
  }

  if (!s.idle) return s
  var duration = t - s.idleSinceMs
  s.idle = false
  s.idleSinceMs = 0
  if (duration < cfg.pauseMs) return s                  // micro-pausa: no cuenta

  // Pausa real. Se reinician los dos relojes: despues de media hora afuera,
  // decirle "llevas 45 minutos en el editor" seria mentira, y el manifiesto
  // dice que nunca miente sobre lo que sabe.
  s.lastAwayMs = duration
  s.returnedAtMs = t
  s.sessionStartMs = t
  if (s.pendingApp !== "") s.app = s.pendingApp
  s.excursionStartMs = 0
  s.pendingApp = ""
  s.pendingSinceMs = 0
  s.streakStartMs = t
  return s
}

function isAway(state, nowMs, opts) {
  var cfg = config(opts)
  var s = state || {}
  if (!s.idle) return false
  return num(nowMs, 0) - num(s.idleSinceMs, 0) >= cfg.pauseMs
}

// Mientras esta ausente los relojes se congelan en el momento en que empezo la
// ausencia. Si no, volver despues de dos horas dispararia `marathon` por un
// tiempo que el usuario paso lejos del teclado: justo lo contrario de lo que
// mide la regla.
function referenceMs(state, nowMs, opts) {
  var t = num(nowMs, 0)
  return isAway(state, t, opts) ? num(state.idleSinceMs, t) : t
}

function minutesBetween(fromMs, toMs) {
  var d = num(toMs, 0) - num(fromMs, 0)
  if (d < 0) d = 0
  return Math.floor(d / 60000)
}

function streakMinutes(state, nowMs, opts) {
  var ref = referenceMs(state, nowMs, opts)
  var s = settle(state, ref, opts)
  return minutesBetween(s.streakStartMs, ref)
}

function sessionMinutes(state, nowMs, opts) {
  var ref = referenceMs(state, nowMs, opts)
  return minutesBetween(num(state && state.sessionStartMs, ref), ref)
}

function streakApp(state, nowMs, opts) {
  return settle(state, referenceMs(state, nowMs, opts), opts).app
}

// Los campos del contexto que aportan los relojes (ARQUITECTURA 3). El sensor
// de foco aporta `app`/`appId`/`title` por su cuenta: aca va `streakApp`, que
// puede no ser la app enfocada ahora mismo (durante una excursion corta la
// racha sigue siendo del editor aunque estes mirando el browser).
function snapshot(state, nowMs, opts) {
  var cfg = config(opts)
  var t = num(nowMs, 0)
  var away = isAway(state, t, opts)
  var s = state || {}
  return {
    streakApp: streakApp(s, t, opts),
    streakMinutes: streakMinutes(s, t, opts),
    sessionMinutes: sessionMinutes(s, t, opts),
    away: away,
    awayMinutes: Math.floor(num(s.lastAwayMs, 0) / 60000),
    justReturned: !away && num(s.returnedAtMs, 0) > 0 && (t - num(s.returnedAtMs, 0)) <= cfg.justReturnedMs
  }
}

// ------------------------------------------------------------ persistencia
//
// A ~/.local/state/atom/state.json. No es opcional: el shell recarga TODOS los
// servicios de terceros al guardar cualquier archivo del directorio de
// plugins, asi que sin esto tocar una coma reinicia los contadores.

function toJSON(state, nowMs) {
  var s = copy(state)
  s.version = DEFAULTS.version
  s.savedAtMs = num(nowMs, 0)
  return s
}

// El hueco entre `savedAtMs` y ahora es la parte interesante. Una recarga en
// caliente son milisegundos y hay que seguir donde estabamos; una suspension o
// un `omarchy update` son horas, y volver con la racha de ayer intacta seria
// exactamente la clase de mentira que el manifiesto prohibe. Un hueco mayor al
// umbral de pausa se trata como la pausa real que fue.
function fromJSON(obj, nowMs, opts) {
  var cfg = config(opts)
  var t = num(nowMs, 0)
  if (!obj || typeof obj !== "object") return create(t, "")

  var s = copy(obj)
  var saved = num(obj.savedAtMs, 0)
  var gap = t - saved

  if (saved <= 0 || gap < 0) return create(t, s.app)     // reloj corrido o archivo raro
  if (gap >= cfg.pauseMs) {
    var fresh = create(t, s.app)
    fresh.lastAwayMs = gap
    fresh.returnedAtMs = t
    return fresh
  }
  return s
}

function parse(text, nowMs, opts) {
  var obj = null
  try { obj = JSON.parse(String(text || "")) } catch (e) { obj = null }
  return fromJSON(obj, nowMs, opts)
}

function stringify(state, nowMs) {
  return JSON.stringify(toJSON(state, nowMs))
}
