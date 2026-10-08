var h = require("./harness")
var P = h.load("brain/Pomodoro.js")

var MIN = 60000
var T0 = 1700000000000

h.suite("Pomodoro / rangos")
h.eq(P.clamp(52, P.FOCUS), 50, "redondea al paso de 5")
h.eq(P.clamp(10, P.FOCUS), 25, "no baja del minimo")
h.eq(P.clamp(200, P.FOCUS), 90, "no pasa del maximo")
h.eq(P.clamp("x", P.REST), 5, "basura: el minimo")

h.suite("Pomodoro / el ciclo")
var s = P.create()
h.eq(s.mode, "off", "arranca apagado")
h.eq(s.last, { focus: 50, rest: 10 }, "con los valores de siempre")
h.ok(!P.isActive(s), "y no esta activo")

s = P.start(s, 25, 5, T0)
h.eq(s.mode, "focus", "start pasa a foco")
h.eq(s.endsAt, T0 + 25 * MIN, "termina a los 25")
h.eq(s.last, { focus: 25, rest: 5 }, "y recuerda lo elegido")
h.eq(P.remainingMs(s, T0 + 10 * MIN), 15 * MIN, "faltan 15 a los 10")

var r = P.tick(s, T0 + 24 * MIN)
h.eq(r.event, null, "antes de tiempo no pasa nada")

r = P.tick(s, T0 + 25 * MIN + 400)
h.eq(r.event, "focusEnd", "al terminar el foco avisa")
h.eq(r.state.mode, "break", "y pasa al descanso")
h.eq(r.state.endsAt, T0 + 30 * MIN, "que dura 5")
h.eq(r.lateMs, 400, "con cuanto tarde se noto")

r = P.tick(r.state, T0 + 30 * MIN)
h.eq(r.event, "breakEnd", "al terminar el descanso avisa")
h.eq(r.state.mode, "off", "y se apaga")

var sd = P.start(P.create(), "", "", T0)
h.eq([sd.focus, sd.rest], [50, 10], "sin valores usa los ultimos")

h.suite("Pomodoro / con el shell apagado")
var off = P.tick(P.start(P.create(), 25, 5, T0), T0 + 3 * 60 * MIN)
h.eq(off.event, "breakEnd", "si terminaron las dos etapas salta al final")
h.eq(off.state.mode, "off", "sin reproducir el foco")
h.ok(off.lateMs > 60 * MIN, "y el atraso dice que fue hace rato")

h.suite("Pomodoro / cortar y persistir")
var st = P.stop(P.start(P.create(), 40, 10, T0))
h.eq(st.mode, "off", "stop apaga")
h.eq(st.last, { focus: 40, rest: 10 }, "pero recuerda lo ultimo")
var round = P.parse(P.stringify(P.start(P.create(), 40, 15, T0)))
h.eq([round.mode, round.focus, round.rest, round.endsAt], ["focus", 40, 15, T0 + 40 * MIN], "sobrevive a un reinicio")
h.eq(P.parse("{roto").mode, "off", "un archivo roto no rompe nada")
h.eq(P.parse(JSON.stringify({ mode: "bailando" })).mode, "off", "un modo desconocido es off")

h.suite("Pomodoro / el selector")
var p = P.pickerCreate({ focus: 50, rest: 10 }, "y")
h.eq([p.focus, p.rest, p.field], [50, 10, "focus"], "arranca de lo ultimo, en el foco")
h.eq(P.pickerCreate(null, "x").field, "rest", "el primer evento horizontal elige descanso")

var w = P.pickerWheel(p, 0, 20, 1000, 60)
h.eq(w.steps, 0, "20 px no alcanzan para un paso")
w = P.pickerWheel(w.picker, 0, 20, 1016, 60)
w = P.pickerWheel(w.picker, 0, 25, 1032, 60)
h.eq(w.steps, 1, "65 px acumulados: un paso")
h.eq(w.picker.focus, 55, "foco 55")

w = P.pickerWheel(w.picker, 0, -130, 1048, 60)
h.eq(w.steps, -2, "para abajo resta")
h.eq(w.picker.focus, 45, "foco 45")

w = P.pickerWheel(w.picker, 30, -2, 1064, 60)
h.eq(w.picker.field, "focus", "dentro del mismo gesto el eje no cambia")
w = P.pickerWheel(w.picker, 70, 3, 1400, 60)
h.eq(w.picker.field, "rest", "un gesto nuevo horizontal pasa al descanso")
h.eq(w.picker.rest, 15, "y suma")

var top = P.pickerWheel(P.pickerCreate({ focus: 90, rest: 10 }, "y"), 0, 200, 5000, 60)
h.eq(top.picker.focus, 90, "contra el tope no pasa")
h.ok(top.bumped, "y avisa que choco")

h.suite("Pomodoro / frases")
h.eq(P.render("{focus} de foco", { focus: 50 }), "50 de foco", "rellena los huecos")
var a = P.line("cancelStop", {}, -1, function () { return 0 })
var b = P.line("cancelStop", {}, a.index, function () { return 0 })
h.ok(a.index !== b.index, "no repite la anterior")
h.ok(P.LINES.cancelStop.indexOf("empezó y terminó como la dieta de los lunes") >= 0, "la de la dieta esta")
var tooLong = []
for (var kind in P.LINES) P.LINES[kind].forEach(function (t) {
  if (P.render(t, { focus: 90, rest: 20 }).length > 80) tooLong.push(t)
})
h.eq(tooLong, [], "ninguna frase pasa de 80 caracteres: el globo es chico")
h.eq(P.minutesLeftLabel(23 * MIN + 1), "24 min", "redondea para arriba")
h.eq(P.minutesLeftLabel(30000), "menos de un minuto", "y abajo de uno lo dice")

h.report()
