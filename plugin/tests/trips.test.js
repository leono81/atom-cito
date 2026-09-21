var h = require("./harness")
var T = h.load("brain/Trips.js")

var stops = [{ x: 100 }, { x: 400 }, { x: 800 }]
var BAR = 1366, DOG = 28

h.suite("Trips / de hueco a hueco")
h.eq(T.toStop({ x: 240 }), [{ x: 240 }], "un tramo, un destino")
h.eq(T.toStop(null), [], "sin destino no hay viaje")

h.suite("Trips / de punta a punta")
var e = T.endToEnd(BAR, DOG, 100, stops)
h.eq(e.length, 2, "ida y vuelta")
h.ok(e[0].x > BAR / 2, "estando a la izquierda cruza a la derecha")
h.ok(T.endToEnd(BAR, DOG, 1300, stops)[0].x < BAR / 2, "y al reves si esta a la derecha")
h.eq(T.endToEnd(40, DOG, 0, stops), [], "barra mas angosta que dos perros: no hay viaje")

h.suite("Trips / la vuelta al mundo")
var w = T.wrapAround(BAR, DOG, false, stops)
h.ok(w[0].x > BAR, "primero se va fuera de cuadro por la derecha")
h.ok(w[0].wrapTo < 0, "y reaparece por la izquierda")
var wl = T.wrapAround(BAR, DOG, true, stops)
h.ok(wl[0].x < 0 && wl[0].wrapTo > BAR, "al reves si va hacia la izquierda")
h.ok(w[1].x > 0 && w[1].x < BAR, "y termina dentro de la barra")

h.suite("Trips / ronda con paradas")
var p = T.patrol(stops, 0)
h.eq(p.length, 3, "un tramo por hueco")
h.eq(p[0].x, 100, "estando a la izquierda arranca por el de mas a la izquierda")
h.ok(p[0].pauseMs > 0, "y para en cada uno")
h.eq(p[p.length - 1].pauseMs, 0, "menos en el ultimo, donde se queda")
h.eq(T.patrol([], 0), [], "sin huecos no hay ronda")
h.eq(T.patrol(stops, 1300)[0].x, 800, "viniendo de la derecha arranca por la derecha")

h.suite("Trips / la corrida")
var d = T.dash(BAR, DOG, 100, stops)
h.eq(d.length, 2, "va y vuelve")
h.ok(d[0].speed > 150, "y va rapido: de eso se trata")
h.ok(d[0].pauseMs > 0, "frena antes de volver")

h.suite("Trips / la cabriola")
var c = T.cabriola(600, BAR, DOG, h.seq(0.2), "jump")
h.eq(c.length, 2, "salto grande y rebote")
h.eq(c[0].pose, "jump", "los dos tramos viajan en la pose que salta")
h.eq(c[1].pose, "jump", "los dos")
h.ok(Math.abs(c[0].x - 600) > Math.abs(c[1].x - c[0].x), "el rebote es mas corto que el salto")
// Contra los bordes no se sale de la barra ni salta contra la pared.
var izq = T.cabriola(4, BAR, DOG, h.seq(0.9), "jump")
h.ok(izq[0].x > 4, "pegado al borde izquierdo salta hacia la derecha")
var der = T.cabriola(BAR - DOG - 4, BAR, DOG, h.seq(0.1), "jump")
h.ok(der[0].x < BAR - DOG - 4, "pegado al derecho, hacia la izquierda")
h.ok(der[0].x >= 2 && der[1].x <= BAR - DOG - 2, "nunca se sale de la barra")

h.suite("Trips / hacerle pis a algo")
var pee = T.peeTrip({ x: 500, id: "omarchy.clock" }, 4200, stops, "pee")
h.eq(pee.length, 2, "va, hace, y se va")
h.eq(pee[0].holdPose, "pee", "al llegar levanta la pata")
h.eq(pee[0].holdMs, 4200, "por el rato pedido")
h.ok(!pee[1].holdPose, "el tramo de salida es un tramo comun")
h.eq(T.peeTrip(null, 4200, stops, "pee"), [], "sin lugar no hay viaje")

h.suite("Trips / el sorteo")
var ctx = { stops: stops, barWidth: BAR, dogWidth: DOG, currentX: 200, stop: { x: 400 } }
var vistos = {}
for (var i = 0; i < 200; i++) vistos[T.randomWalk(ctx).kind] = true
h.eq(Object.keys(vistos).sort(), ["dash", "endToEnd", "patrol", "stop", "wrap"],
     "en 200 sorteos salen los cinco paseos")
for (var j = 0; j < 200; j++) {
  var plan = T.randomWalk(ctx)
  if (!plan.legs.length) h.ok(false, "el sorteo devolvio un viaje vacio: " + plan.kind)
}
h.ok(true, "ningun sorteo devuelve un viaje vacio con una barra normal")

h.report()
