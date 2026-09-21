var h = require("./harness")
var G = h.load("brain/Gaps.js")

var DOG = 28   // 28 x 20 px, PERSONAJE 2

// Los 17 slots reales de la barra del usuario, copiados tal cual del dump de
// la Fase 0 (SPIKES U1, pantalla LVDS-1, 1366 px). Tres de ellos estan montados
// con ancho cero, y estan aca justamente por eso.
var BARRA_REAL = { width: 1366, slots: [
  { id: "omarchy.menu",             section: "left",   x:    8, y:  0, w:  27, h: 26 },
  { id: "omarchy.workspaces",       section: "left",   x:   35, y:  0, w: 106, h: 26 },
  { id: "omarchy.indicators",       section: "center", x:  610, y:  0, w:  21, h: 26 },
  { id: "omarchy.clock",            section: "center", x:  631, y:  0, w: 104, h: 26 },
  { id: "omarchy.keyboard-layout",  section: "center", x:  735, y: 13, w:   0, h:  0 },
  { id: "omarchy.weather",          section: "center", x:  735, y: 13, w:  21, h: 26 },
  { id: "omarchy.system-update",    section: "center", x:  735, y: 13, w:   0, h:  0 },
  { id: "omarchy.tailscale",        section: "right",  x: 1132, y:  0, w:  27, h: 26 },
  { id: "omarchy.tray",             section: "right",  x: 1132, y:  0, w:   0, h:  0 },
  { id: "nosignal.motion-wallpaper",section: "right",  x: 1159, y:  0, w:  27, h: 26 },
  { id: "omarchy.agents",           section: "right",  x: 1186, y:  0, w:  27, h: 26 },
  { id: "omarchy.bluetooth",        section: "right",  x: 1213, y:  0, w:  27, h: 26 },
  { id: "omarchy.network",          section: "right",  x: 1240, y:  0, w:  27, h: 26 },
  { id: "omarchy.audio",            section: "right",  x: 1267, y:  0, w:  27, h: 26 },
  { id: "omarchy.monitor",          section: "right",  x: 1294, y:  0, w:  27, h: 26 },
  { id: "omarchy.power",            section: "right",  x: 1321, y:  0, w:  27, h: 26 },
  { id: "leono.atomspike",          section: "right",  x: 1348, y:  0, w:  10, h: 26 }
]}

h.suite("Geometry / barra vacia")
h.eq(G.restStops(1366, [], DOG),
     [{ x: 669, gapA: 0, gapB: 1366 }],
     "sin widgets, un solo hueco y el perro al medio")
h.eq(G.restStops(1366, null, DOG).length, 1, "obstaculos null no rompe")

h.suite("Geometry / barra llena")
h.eq(G.restStops(200, [{ id: "todo", x: 0, w: 200 }], DOG), [], "un widget que ocupa todo: sin huecos")
h.eq(G.restStops(200, [{ id: "a", x: -10, w: 120 }, { id: "b", x: 110, w: 200 }], DOG), [],
     "obstaculos que se salen de la barra se recortan, no generan huecos")

h.suite("Geometry / un solo hueco")
h.eq(G.restStops(300, [{ id: "a", x: 0, w: 100 }, { id: "b", x: 200, w: 100 }], DOG),
     [{ x: 136, gapA: 100, gapB: 200 }],
     "hueco central de 100 px: el perro centrado en 136")

h.suite("Geometry / huecos mas chicos que el perro")
h.eq(G.restStops(300, [{ id: "a", x: 0, w: 130 }, { id: "b", x: 150, w: 150 }], DOG), [],
     "hueco de 20 px con un perro de 28: no vale")
h.eq(G.restStops(300, [{ id: "a", x: 0, w: 130 }, { id: "b", x: 158, w: 142 }], DOG),
     [{ x: 130, gapA: 130, gapB: 158 }],
     "hueco de exactamente 28 px: vale, el minimo es inclusivo")

h.suite("Geometry / fusion de pegados")
h.eq(G.restStops(300, [{ id: "a", x: 100, w: 20 }, { id: "b", x: 120, w: 20 }], DOG).length, 2,
     "dos widgets pegados no inventan un hueco de ancho cero en el medio")
h.eq(G.restStops(300, [{ id: "a", x: 100, w: 20 }, { id: "b", x: 124, w: 20 }], DOG),
     [{ x: 36, gapA: 0, gapB: 100 }, { x: 208, gapA: 144, gapB: 300 }],
     "separados por 4 px (< padding 6): se fusionan igual")
h.eq(G.restStops(400, [{ id: "a", x: 100, w: 20 }, { id: "b", x: 160, w: 20 }], DOG).length, 3,
     "separados por 40 px: son dos obstaculos y hay tres huecos")
h.eq(G.restStops(300, [{ id: "a", x: 100, w: 60 }, { id: "b", x: 120, w: 20 }], DOG).length, 2,
     "uno contenido adentro del otro se absorbe")
h.eq(G.restStops(400, [{ id: "a", x: 160, w: 20 }, { id: "b", x: 100, w: 20 }], DOG).length, 3,
     "la entrada desordenada da el mismo resultado")
h.eq(G.restStops(400, [{ id: "a", x: 100, w: 20 }, { id: "b", x: 160, w: 20 }], DOG, { padding: 100 }).length, 2,
     "con padding 100 esos 40 px de separacion tambien se fusionan (padding configurable)")

h.suite("Geometry / ancho cero")
h.eq(G.restStops(300, [{ id: "tray", x: 150, w: 0 }], DOG),
     [{ x: 136, gapA: 0, gapB: 300 }],
     "un widget de ancho cero no parte la barra (tray, keyboard-layout, system-update)")

h.suite("Geometry / bordes")
h.eq(G.restStops(100, [{ id: "a", x: 30, w: 40 }], DOG),
     [{ x: 1, gapA: 0, gapB: 30 }, { x: 71, gapA: 70, gapB: 100 }],
     "cuenta el hueco del borde izquierdo y el del derecho, acotado adentro de la barra")
h.eq(G.restStops(0, [], DOG), [], "barra de ancho cero (bar.barSize == 0 mientras recarga)")
h.eq(G.restStops(1366, [], 0), [], "perro de ancho cero")

h.suite("Geometry / la barra real (SPIKES U1)")
var reales = G.restStops(BARRA_REAL.width, BARRA_REAL.slots, DOG)
h.eq(reales.length, 2, "los 17 slots dan exactamente dos huecos")
h.eq([reales[0].gapA, reales[0].gapB], [141, 610], "hueco izquierdo 141 -> 610")
h.eq([reales[1].gapA, reales[1].gapB], [756, 1132], "hueco derecho 756 -> 1132")
h.eq(reales[0].x, 362, "centrado en el hueco izquierdo")
h.eq(reales[1].x, 930, "centrado en el hueco derecho")

h.suite("Geometry / pickStop")
var stops = [{ x: 100, gapA: 0, gapB: 200 }, { x: 500, gapA: 400, gapB: 600 }]
h.eq(G.pickStop(stops, 100, 50, h.seq(0)).x, 500, "no elige el hueco donde ya esta")
h.eq(G.pickStop(stops, 500, 50, h.seq(0)).x, 100, "desde el otro, al reves")
h.eq(G.pickStop([{ x: 100, gapA: 0, gapB: 200 }], 100, 50, h.seq(0)).x, 100,
     "si el unico hueco es el actual, lo devuelve igual")
h.eq(G.pickStop(stops, 120, 500, h.seq(0)).x, 100,
     "si ninguno esta a minMove, devuelve el mas cercano (no camina de gusto)")
h.eq(G.pickStop([], 100, 50, h.seq(0)), null, "sin huecos, null")
h.eq(G.pickStop([{ x: 10 }, { x: 900 }, { x: 1300 }], 500, 50, h.seq(0.99)).x, 1300,
     "con varios candidatos elige al azar y el random es inyectable")

h.suite("Geometry / isStillValid")
h.ok(G.isStillValid(362, DOG, BARRA_REAL.slots), "sentado en el hueco real: valido")
h.ok(!G.isStillValid(620, DOG, BARRA_REAL.slots), "encima de indicators: invalido")
h.ok(G.isStillValid(940, DOG, BARRA_REAL.slots), "hueco derecho: valido")
// El reloj pasa de 104 a 150 px ("miercoles" mide mas que "lunes") y se come el
// hueco de la derecha sin que el perro se haya movido un pixel.
var creciendo = BARRA_REAL.slots.slice()
creciendo[3] = { id: "omarchy.clock", section: "center", x: 631, y: 0, w: 320, h: 26 }
h.ok(!G.isStillValid(940, DOG, creciendo), "el reloj crecio y se lo comio: invalido")
h.ok(G.isStillValid(1000, DOG, creciendo), "un poco mas a la derecha sigue salvado")
h.ok(!G.isStillValid(1000, DOG, creciendo, { clearance: 60 }), "con clearance pedido, ya no")
h.ok(G.isStillValid(362, DOG, []), "sin obstaculos, cualquier lado es valido")

h.report()
