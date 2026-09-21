var h = require("./harness")
var B = h.load("brain/Behavior.js")

var nada = {}

h.suite("Behavior / el ciclo por defecto (PERSONAJE 6)")
h.eq(B.nextState("walk", 0, { arrived: true }, null, h.seq(0)), "stand", "camina -> parado al llegar")
h.eq(B.nextState("walk", 99999, nada, null, h.seq(0)), null, "caminando sin llegar: sigue caminando")
h.eq(B.nextState("stand", 5999, nada, null, h.seq(0)), null, "parado a los 5,999 s: todavia no")
h.eq(B.nextState("stand", 6000, nada, null, h.seq(0)), "sit", "parado -> sentado a los 6 s")
h.eq(B.nextState("sit", 13999, nada, null, h.seq(0.99)), null,
     "sentado a los 13,999 s: todavia no se acuesta (y el dado dice que tampoco se rasca)")
h.eq(B.nextState("sit", 14000, nada, null, h.seq(0.99)), "lie", "sentado -> echado a los 14 s")
h.eq(B.nextState("sit", 9000, nada, null, h.seq(0.10)), "scratch", "sentado a los 9 s: a veces se rasca")
h.eq(B.nextState("sit", 9000, nada, null, h.seq(0.90)), null, "...y a veces no: el dado decide")
h.eq(B.nextState("lie", 599999, nada, null, h.seq(0)), null, "echado antes de los 10 min: se queda")
h.eq(B.nextState("lie", 600000, nada, null, h.seq(0)), "walk", "echado a los 10 min: se aburre y arranca un viaje")
h.eq(B.nextState("lie", 0, { away: true }, null, h.seq(0)), "sleep", "echado -> durmiendo si estas ausente")
h.eq(B.nextState("sleep", 999999, { away: true }, null, h.seq(0)), null, "durmiendo es estado terminal")

h.suite("Behavior / las interrupciones le ganan al cronometro")
// El click NO esta en la tabla a proposito: tiene que responder al instante y
// esto se evalua una vez por segundo. Lo maneja el servicio.
h.eq(B.nextState("sit", 0, { click: true }, null, h.seq(0.99)), null,
     "un click no es un evento de esta tabla")
h.eq(B.nextState("sleep", 0, { back: true }, null, h.seq(0)), "play", "volves al teclado: te recibe jugando")
h.eq(B.nextState("lie", 0, { speaking: true }, null, h.seq(0)), "stand", "tiene algo que decir: se para")
h.eq(B.nextState("sit", 999999, { speaking: true }, null, h.seq(0)), "stand",
     "hablar gana aunque el cronometro de sit->lie ya haya vencido")
h.eq(B.nextState("stand", 6000, { speaking: true }, null, h.seq(0)), null,
     "hablando parado NO se sienta a mitad de la frase: la fila que gana apunta a la pose actual")

h.suite("Behavior / eventos en cualquiera de los dos formatos")
h.eq(B.nextState("walk", 0, ["arrived"], null, h.seq(0)), "stand", "lista de eventos")
h.eq(B.nextState("walk", 0, { arrived: false }, null, h.seq(0)), null, "evento explicitamente en false")
h.eq(B.nextState("walk", 0, null, null, h.seq(0)), null, "sin eventos")

h.suite("Behavior / la invariante de movimiento")
h.eq(B.canMove("walk"), true, "walk puede trasladarse")
h.eq(B.canMove("stand"), false, "stand NO, aunque este de pie")
h.eq(B.canMove("sit"), false, "sit no")
h.eq(B.canMove("lie"), false, "lie no")
h.eq(B.canMove("sleep"), false, "sleep no")
h.eq(B.canMove("inventada"), false, "una pose desconocida no puede moverse")
h.eq(B.stepsToWalk("sit"), ["stand", "walk"], "sentado: se levanta y despues camina, nunca salta")
h.eq(B.stepsToWalk("lie"), ["stand", "walk"], "echado: idem")
h.eq(B.stepsToWalk("sleep"), ["stand", "walk"], "dormido: idem")
h.eq(B.stepsToWalk("stand"), ["walk"], "parado: le falta un solo paso")
h.eq(B.stepsToWalk("walk"), [], "caminando: ya esta")
// Una fila SI puede apuntar a la pose que se traslada: el servicio no la
// asigna como pose, la lee como "arranca un viaje" y elige el destino (un
// hueco, o el borde de un widget). Lo que no puede pasar es que la fila salga
// DE esa pose: seria pedir un viaje arriba de otro viaje, y ahi si el destino
// viejo quedaria colgado.
var arrancanViaje = []
for (var i = 0; i < B.IDLE.length; i++) if (B.canMove(B.IDLE[i].to)) arrancanViaje.push(B.IDLE[i])
var todasDesdeQuieto = true
for (var j = 0; j < arrancanViaje.length; j++) {
  if (B.canMove(arrancanViaje[j].from)) todasDesdeQuieto = false
}
h.ok(todasDesdeQuieto, "toda fila que arranca un viaje sale de una pose quieta")

h.suite("Behavior / chance con random inyectado")
var conSuerte = [{ from: "sit", to: "stand", afterMs: 1000, chance: 0.25 }]
h.eq(B.nextState("sit", 5000, nada, conSuerte, h.seq(0.24)), "stand", "0.24 < 0.25: aplica")
h.eq(B.nextState("sit", 5000, nada, conSuerte, h.seq(0.25)), null, "0.25 no es < 0.25: no aplica")
h.eq(B.nextState("sit", 500, nada, conSuerte, h.seq(0.0)), null, "sin cumplir afterMs no se tira el dado")
// El orden de consumo del random es parte del contrato: una fila que no aplica
// por `from` o por `afterMs` no gasta numeros.
var dosFilas = [
  { from: "lie", to: "stand", chance: 0.5 },
  { from: "sit", to: "stand", chance: 0.5 }
]
h.eq(B.nextState("sit", 0, nada, dosFilas, h.seq(0.9, 0.1)), null,
     "la fila de `lie` no gasta el 0.9: el dado de la fila de `sit` es el primero")
h.eq(B.nextState("sit", 0, nada, dosFilas, h.seq(0.1, 0.9)), "stand",
     "y con el 0.1 primero, aplica")

h.suite("Behavior / extender es agregar una fila")
var conSiesta = B.IDLE.concat([{ from: "lie", to: "walk", afterMs: 600000, moves: true }])
h.eq(B.nextState("lie", 600000, nada, conSiesta, h.seq(0)), "walk",
     "echado diez minutos: se levanta a caminar (fila nueva, nucleo sin tocar)")
h.eq(B.nextState("lie", 0, { away: true }, conSiesta, h.seq(0)), "sleep",
     "la fila nueva no le roba el turno a las de arriba")
h.eq(B.validateTable(conSiesta), [], "la tabla extendida valida")
h.eq(B.validateTable([{ from: "sit", to: "sit2" }]).length, 1, "pose destino desconocida: error")
h.eq(B.validateTable([{ from: "inventada", to: "sit" }]).length, 1, "pose origen desconocida: error")
h.eq(B.validateTable([{ from: "sit", to: "lie", chance: 2 }]).length, 1, "chance fuera de [0,1]: error")
h.eq(B.validateTable([{ from: "sit", to: "lie", afterMs: -1 }]).length, 1, "afterMs negativo: error")
h.eq(B.validateTable([{ from: "sit", to: "lie", moves: true }]).length, 1,
     "una fila que implica traslado sin pasar por walk: error (la invariante, como chequeo)")
h.eq(B.validateTable(null), [], "la tabla por defecto valida")

h.suite("Behavior / el espejo de poses no se puede desincronizar")
// Este archivo tiene un espejo del registro porque no puede leerlo: si
// alguien agrega una pose y se olvida del espejo, el ciclo de ocio la trata
// como desconocida y la pose nunca aparece. Que falle acá y no en la barra.
var real = h.load("poses/Poses.js")
var enRegistro = real.ids().sort()
var enEspejo = Object.keys(B.POSES).sort()
h.eq(enEspejo, enRegistro, "el espejo de Behavior.js lista exactamente las poses del registro")
h.eq(B.validateTable(null), [], "la tabla por defecto valida contra el espejo al dia")

h.suite("Behavior / el registro de poses se puede inyectar")
h.eq(B.canMove("beg"), false, "una pose que este registro no espeja se trata como quieta")
h.eq(B.canMove("stand", { stand: { canMove: true } }), true,
     "con un registro inyectado manda el registro, no la tabla de este archivo")
h.eq(B.validateTable([{ from: "stand", to: "rascarse" }], { stand: {}, rascarse: {} }), [],
     "una pose nueva valida si el registro vivo la conoce")

h.report()
