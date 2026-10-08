// El pomodoro: solo si lo pedis, nunca por iniciativa propia.
//
// El MANIFIESTO dice "no es un pomodoro: no impone una estructura". Esto no la
// impone: arranca unicamente cuando lo elegis con el gesto sobre el perro (o
// por IPC), y Atom jamas lo sugiere. Si no lo usas, no existe.
//
// Dos piezas, las dos puras y con el tiempo inyectado (como Clocks.js):
//
//   - el ciclo:   off -> focus -> break -> off
//   - el selector: el estado efimero mientras elegis los minutos con el scroll
//
// Las frases son fijas y viven aca. La cancelacion pasa en el momento y no da
// tiempo a pedirle nada a Claude; las de fin de foco y de descanso se podrian
// anticipar, pero por ahora tambien son fijas.
.pragma library

var FOCUS = { min: 25, max: 90, step: 5 }
var REST = { min: 5, max: 20, step: 5 }
var DEFAULT_LAST = { focus: 50, rest: 10 }

// Un gesto del touchpad es una rafaga de eventos chicos. Una pausa mas larga
// que esto entre dos eventos empieza un gesto nuevo, y el gesto nuevo decide
// el eje: asi un deslizamiento en diagonal no salta de campo a mitad de camino.
var GESTURE_GAP_MS = 180

function num(v, dflt) {
  var n = Number(v)
  return isFinite(n) ? n : dflt
}

function clamp(v, range) {
  var n = Math.round(num(v, range.min) / range.step) * range.step
  return Math.max(range.min, Math.min(range.max, n))
}

// ── El ciclo ──────────────────────────────────────────────────────────────

function create(last) {
  return {
    mode: "off",          // off | focus | break
    focus: 0,             // minutos de este pomodoro
    rest: 0,
    endsAt: 0,            // cuando termina la etapa actual (epoch ms)
    last: {               // lo ultimo que elegiste: el selector arranca de aca
      focus: clamp(last && isFinite(Number(last.focus)) ? last.focus : DEFAULT_LAST.focus, FOCUS),
      rest: clamp(last && isFinite(Number(last.rest)) ? last.rest : DEFAULT_LAST.rest, REST)
    }
  }
}

function copy(s) {
  var out = create(s && s.last)
  if (!s) return out
  out.mode = (s.mode === "focus" || s.mode === "break") ? s.mode : "off"
  out.focus = num(s.focus, 0)
  out.rest = num(s.rest, 0)
  out.endsAt = num(s.endsAt, 0)
  return out
}

function isActive(s) {
  return !!s && (s.mode === "focus" || s.mode === "break")
}

function start(s, focus, rest, now) {
  var out = copy(s)
  out.focus = clamp(focus === undefined || focus === "" ? out.last.focus : focus, FOCUS)
  out.rest = clamp(rest === undefined || rest === "" ? out.last.rest : rest, REST)
  out.last = { focus: out.focus, rest: out.rest }
  out.mode = "focus"
  out.endsAt = num(now, 0) + out.focus * 60000
  return out
}

function stop(s) {
  var out = copy(s)
  out.mode = "off"
  out.endsAt = 0
  return out
}

function remainingMs(s, now) {
  if (!isActive(s)) return 0
  return Math.max(0, num(s.endsAt, 0) - num(now, 0))
}

// Avanza el ciclo. Devuelve el estado nuevo y, si cambio de etapa, el evento
// ("focusEnd" | "breakEnd") con cuanto tarde se noto (`lateMs`). Un evento muy
// tardio es de un pomodoro que termino con el shell apagado: el llamador
// decide no anunciarlo.
//
// Si mientras el shell estuvo apagado terminaron las dos etapas, salta directo
// a "off" con el evento del final, no reproduce el foco entero en un segundo.
function tick(s, now) {
  var t = num(now, 0)
  var out = copy(s)
  if (!isActive(out) || t < out.endsAt) return { state: out, event: null, lateMs: 0 }

  if (out.mode === "focus") {
    var breakEnds = out.endsAt + out.rest * 60000
    if (t < breakEnds) {
      var late = t - out.endsAt
      out.mode = "break"
      out.endsAt = breakEnds
      return { state: out, event: "focusEnd", lateMs: late }
    }
    var lateAll = t - breakEnds
    out.mode = "off"
    out.endsAt = 0
    return { state: out, event: "breakEnd", lateMs: lateAll }
  }

  var lateB = t - out.endsAt
  out.mode = "off"
  out.endsAt = 0
  return { state: out, event: "breakEnd", lateMs: lateB }
}

function stringify(s) {
  var c = copy(s)
  return JSON.stringify({ version: 1, mode: c.mode, focus: c.focus, rest: c.rest,
                          endsAt: c.endsAt, last: c.last })
}

function parse(raw) {
  var o = null
  try { o = JSON.parse(String(raw)) } catch (e) { o = null }
  if (!o || typeof o !== "object") return create()
  return copy(o)
}

// ── El selector ───────────────────────────────────────────────────────────

// `axis` es el eje del primer evento: "y" elige foco, "x" descanso.
function pickerCreate(last, axis) {
  var l = create(last).last
  return {
    focus: l.focus,
    rest: l.rest,
    field: axis === "x" ? "rest" : "focus",
    acc: 0,
    axis: axis === "x" ? "x" : "y",
    lastWheelMs: 0
  }
}

// Un evento de scroll. `dx` y `dy` vienen en la convencion de los dedos:
// positivo es hacia arriba o hacia la derecha, que es "mas minutos". El
// llamador se encarga de traducir lo que mande Qt.
//
// Devuelve el selector nuevo, cuantos pasos se dieron (con signo) y si se
// choco contra un limite, para que el globo pueda hacer el gesto de "no da
// mas".
function pickerWheel(p, dx, dy, now, thresholdPx) {
  var out = {}
  for (var k in p) out[k] = p[k]
  var t = num(now, 0)
  var thr = Math.max(1, num(thresholdPx, 60))
  var x = num(dx, 0), y = num(dy, 0)

  if (t - num(out.lastWheelMs, 0) > GESTURE_GAP_MS) {
    out.axis = Math.abs(x) > Math.abs(y) ? "x" : "y"
    out.field = out.axis === "x" ? "rest" : "focus"
    out.acc = 0
  }
  out.lastWheelMs = t
  out.acc = num(out.acc, 0) + (out.axis === "x" ? x : y)

  var steps = 0, bumped = false
  var range = out.field === "focus" ? FOCUS : REST
  while (out.acc >= thr || out.acc <= -thr) {
    var dir = out.acc > 0 ? 1 : -1
    out.acc -= dir * thr
    var cur = out[out.field]
    var nxt = clamp(cur + dir * range.step, range)
    if (nxt === cur) {
      bumped = true
      out.acc = 0           // contra el tope, el resto del gesto no se acumula
      break
    }
    out[out.field] = nxt
    steps += dir
  }
  return { picker: out, steps: steps, bumped: bumped }
}

// ── Las frases ────────────────────────────────────────────────────────────
// Ironia seca y afecto, como pide el prompt de atom-say. El chiste es sobre
// el perro o la situacion, nunca sobre vos: Atom no juzga (MANIFIESTO 2).

var LINES = {
  start: [
    "¡dale! {focus} de foco"
  ],
  focusEnd: [
    "¡corte! {focus} min de foco. {rest} de descanso: andá a estirar",
    "listo, {focus} de foco. {rest} minutos para vos: levantate",
    "terminó el foco. {rest} min de recreo, el teclado no se va a ningún lado",
    "¡corte! ahora {rest} minutos de nada, que también es trabajo"
  ],
  breakEnd: [
    "dale, de vuelta. ¿otro? deslizá sobre mí",
    "se terminó el recreo. yo sigo acá, por si querés otro",
    "{rest} minutos volaron. ¿otra vuelta?"
  ],
  cancelPick: [
    "tanto scroll para nada. igual me gustó",
    "me ilusioné. ya se me pasa",
    "ok, quedamos en nada. lo anoto",
    "flor de reunión para no decidir nada"
  ],
  cancelStop: [
    "listo, el pomodoro nunca existió. yo no vi nada",
    "cortado. el foco ni se enteró",
    "bueno, la estructura estaba sobrevalorada",
    "lo archivo junto a mis planes de atrapar la cola",
    "empezó y terminó como la dieta de los lunes"
  ],
  askStop: [
    "¿cortamos? dos dedos de nuevo para cortar"
  ]
}

function render(template, vars) {
  return String(template).replace(/\{(\w+)\}/g, function (m, key) {
    return (vars && vars[key] !== undefined) ? String(vars[key]) : m
  })
}

// Una frase del grupo, sin repetir la anterior (`lastIndex`). Devuelve el
// texto y el indice, para que el llamador lo recuerde.
function line(kind, vars, lastIndex, rnd) {
  var list = LINES[kind] || []
  if (list.length === 0) return { text: "", index: -1 }
  var r = (typeof rnd === "function") ? rnd : Math.random
  var i = Math.floor(r() * list.length)
  if (list.length > 1 && i === lastIndex) i = (i + 1) % list.length
  return { text: render(list[i], vars), index: i }
}

function minutesLeftLabel(ms) {
  var m = Math.ceil(num(ms, 0) / 60000)
  return m <= 1 ? "menos de un minuto" : m + " min"
}
