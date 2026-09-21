var h = require("./harness")
var C = h.load("brain/Clocks.js")

var M = 60000
var T0 = 1758400000000   // un epoch cualquiera, fijo: nada depende de "ahora"

h.suite("Clocks / racha basica")
var s = C.create(T0, "herdr")
h.eq(C.streakMinutes(s, T0), 0, "recien empezada")
h.eq(C.streakMinutes(s, T0 + 45 * M), 45, "45 minutos en herdr")
h.eq(C.streakApp(s, T0 + 45 * M), "herdr", "y la racha es de herdr")
h.eq(C.streakMinutes(C.onFocus(s, "herdr", T0 + 10 * M), T0 + 45 * M), 45,
     "re-enfocar la misma app no reinicia nada")

h.suite("Clocks / alt-tab corto no corta la racha (< 90 s)")
var corto = C.onFocus(s, "chromium", T0 + 30 * M)          // te vas al browser
corto = C.onFocus(corto, "herdr", T0 + 30 * M + 40000)     // volves a los 40 s
h.eq(C.streakMinutes(corto, T0 + 45 * M), 45, "la racha sigue contando desde el principio")
h.eq(C.streakApp(corto, T0 + 45 * M), "herdr", "y sigue siendo de herdr")

var justo = C.onFocus(s, "chromium", T0 + 30 * M)
h.eq(C.streakMinutes(justo, T0 + 30 * M + 89000), 31, "a los 89 s afuera, la racha de herdr vive y sigue sumando")
h.eq(C.streakApp(justo, T0 + 30 * M + 89000), "herdr", "todavia es de herdr")

h.suite("Clocks / irse mas de 90 s si la corta")
h.eq(C.streakApp(justo, T0 + 30 * M + 90000), "chromium", "a los 90 s justos, la racha pasa a chromium")
h.eq(C.streakMinutes(justo, T0 + 30 * M + 90000), 1,
     "y cuenta desde que se enfoco chromium, no desde que vencio la gracia")
h.eq(C.streakMinutes(justo, T0 + 40 * M), 10, "diez minutos despues, diez minutos de chromium")
// El corte pasa solo, por paso del tiempo: no hace falta ningun evento nuevo.
h.eq(C.streakApp(C.onIdleChanged(justo, false, T0 + 40 * M), T0 + 40 * M), "chromium",
     "el corte ya estaba resuelto cuando llego el proximo evento")

h.suite("Clocks / la gracia corre sobre la excursion entera, no por ventana")
// Saltar de app en app cada 80 s no puede conservar para siempre una racha en
// una app que abandonaste hace rato.
var saltando = C.onFocus(s, "chromium", T0 + 30 * M)
saltando = C.onFocus(saltando, "slack", T0 + 30 * M + 80000)
h.eq(C.streakApp(saltando, T0 + 30 * M + 80000), "herdr", "a los 80 s todavia es de herdr")
h.eq(C.streakApp(saltando, T0 + 30 * M + 100000), "slack",
     "a los 100 s se corta, y la racha nueva es de la app que estas mirando")
h.eq(C.streakMinutes(saltando, T0 + 30 * M + 100000 + 5 * M), 5,
     "contando desde que se enfoco slack")

h.suite("Clocks / sesion")
h.eq(C.sessionMinutes(s, T0 + 112 * M), 112, "112 minutos de sesion")
var cambiando = C.onFocus(s, "chromium", T0 + 30 * M)
cambiando = C.onFocus(cambiando, "zed", T0 + 60 * M)
h.eq(C.sessionMinutes(cambiando, T0 + 112 * M), 112, "cambiar de app no toca la sesion")

h.suite("Clocks / pausa real (IdleMonitor da booleano, cronometramos nosotros)")
var micro = C.onIdleChanged(s, true, T0 + 50 * M)
micro = C.onIdleChanged(micro, false, T0 + 52 * M)          // 2 min: no alcanza
h.eq(C.sessionMinutes(micro, T0 + 60 * M), 60, "2 minutos sin input no son una pausa real")
h.eq(C.streakMinutes(micro, T0 + 60 * M), 60, "ni cortan la racha")

var pausa = C.onIdleChanged(s, true, T0 + 50 * M)
h.eq(C.sessionMinutes(pausa, T0 + 51 * M), 51, "idle pero todavia no ausente: los relojes corren")
h.eq(C.isAway(pausa, T0 + 51 * M), false, "al minuto de idle no esta ausente")
h.eq(C.isAway(pausa, T0 + 53 * M), true, "a los 3 minutos si")
h.eq(C.sessionMinutes(pausa, T0 + 200 * M), 50,
     "ausente, los relojes se congelan donde estaban (volver de dos horas no dispara marathon)")

var volvio = C.onIdleChanged(pausa, false, T0 + 80 * M)     // 30 min afuera
h.eq(C.sessionMinutes(volvio, T0 + 80 * M), 0, "la sesion arranca de cero al volver")
h.eq(C.streakMinutes(volvio, T0 + 80 * M), 0, "y la racha tambien: 45 min en el editor con media hora afuera seria mentira")
var snap = C.snapshot(volvio, T0 + 80 * M)
h.eq(snap.awayMinutes, 30, "awayMinutes = lo que duro la pausa")
h.eq(snap.justReturned, true, "justReturned prendido al volver")
h.eq(C.snapshot(volvio, T0 + 82 * M).justReturned, false, "y apagado dos minutos despues")
h.eq(C.snapshot(s, T0).justReturned, false, "sin pausa previa nunca estuvo 'de vuelta'")

var repetido = C.onIdleChanged(C.onIdleChanged(s, true, T0 + 50 * M), true, T0 + 52 * M)
h.eq(C.isAway(repetido, T0 + 53 * M), true,
     "un `true` repetido no reinicia el cronometro de la ausencia")

h.suite("Clocks / al volver, la racha es de la app que estas mirando")
var fueraYCambio = C.onFocus(s, "chromium", T0 + 50 * M - 10000)
fueraYCambio = C.onIdleChanged(fueraYCambio, true, T0 + 50 * M)
fueraYCambio = C.onIdleChanged(fueraYCambio, false, T0 + 80 * M)
h.eq(C.streakApp(fueraYCambio, T0 + 80 * M), "chromium", "vuelve con la racha en chromium, en cero")

h.suite("Clocks / snapshot (los campos del contexto)")
var ctx = C.snapshot(C.create(T0, "herdr"), T0 + 47 * M)
h.eq(ctx.streakApp, "herdr", "streakApp")
h.eq(ctx.streakMinutes, 47, "streakMinutes")
h.eq(ctx.sessionMinutes, 47, "sessionMinutes")
h.eq(ctx.away, false, "away")
h.eq(ctx.awayMinutes, 0, "awayMinutes")
h.eq(ctx.justReturned, false, "justReturned")

h.suite("Clocks / persistencia")
var guardado = C.stringify(C.create(T0, "herdr"), T0 + 45 * M)
h.ok(guardado.indexOf("\"savedAtMs\"") !== -1, "serializa con la marca de tiempo del guardado")
var recargado = C.fromJSON(JSON.parse(guardado), T0 + 45 * M + 300)
h.eq(C.streakMinutes(recargado, T0 + 46 * M), 46,
     "recarga en caliente a los 300 ms: los relojes siguen donde estaban")
h.eq(C.sessionMinutes(recargado, T0 + 46 * M), 46, "la sesion tambien")

var despuesDeSuspender = C.fromJSON(JSON.parse(guardado), T0 + 45 * M + 8 * 3600000)
h.eq(C.streakMinutes(despuesDeSuspender, T0 + 45 * M + 8 * 3600000), 0,
     "ocho horas de hueco: se trata como la pausa real que fue")
h.eq(C.snapshot(despuesDeSuspender, T0 + 45 * M + 8 * 3600000).awayMinutes, 480,
     "y el hueco se reporta como ausencia")
h.eq(C.streakApp(despuesDeSuspender, T0 + 45 * M + 8 * 3600000), "herdr", "la app sobrevive")

h.eq(C.streakMinutes(C.parse("{ esto no es json", T0), T0 + 5 * M), 5,
     "un state.json corrupto arranca de cero, no explota")
h.eq(C.streakMinutes(C.parse("", T0), T0 + 5 * M), 5, "un archivo vacio tampoco")
h.eq(C.streakMinutes(C.fromJSON({ streakStartMs: "manana" }, T0), T0 + 5 * M), 5, "basura adentro tampoco")
h.eq(C.streakMinutes(C.fromJSON(JSON.parse(guardado), T0 - 3600000), T0 - 3600000 + 5 * M), 5,
     "un guardado del futuro (reloj corrido) se descarta")

h.suite("Clocks / sin estado global entre llamadas")
var base = C.create(T0, "herdr")
C.onFocus(base, "chromium", T0 + 1 * M)
C.onIdleChanged(base, true, T0 + 2 * M)
h.eq(C.streakApp(base, T0 + 10 * M), "herdr", "el estado original no se modifico")
h.eq(C.isAway(base, T0 + 10 * M), false, "ni el idle")

h.suite("Clocks / umbrales configurables")
var cfg = { graceMs: 5000, pauseMs: 10000 }
var rapido = C.onFocus(C.create(T0, "a"), "b", T0 + M)
h.eq(C.streakApp(rapido, T0 + M + 6000, cfg), "b", "gracia de 5 s")
var corto2 = C.onIdleChanged(C.create(T0, "a"), true, T0 + M, cfg)
h.eq(C.isAway(corto2, T0 + M + 11000, cfg), true, "pausa de 10 s")

h.report()
