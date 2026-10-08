import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "sensors"
import "voice"
import "brain/Gaps.js" as Gaps
import "brain/Trips.js" as Trips
import "poses/Poses.js" as Poses
import "brain/Behavior.js" as Behavior
import "brain/Clocks.js" as Clocks
import "brain/Rules.js" as Rules
import "brain/Pomodoro.js" as Pomodoro

// Atom — el servicio.
//
// Es el singleton del plugin: tiene el estado y es dueño de las ventanas
// layer-shell donde vive el perro. El BarWidget es su órgano sensorial (mide
// la barra) y su canal de configuración; el servicio nunca alcanza la barra
// por su cuenta, porque el host lo crea con `parent: null` a propósito.
//
// Fase 1: la ventana existe, está bien ubicada, no roba input y no reserva
// espacio. El perro todavía es un rectángulo.
Item {
  id: root

  // ---- inyectado por el host (shell.qml) ---------------------------------
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  property var pluginRegistry: null

  readonly property string pluginId: "leono.atom"
  readonly property string logTag: "[atom]"

  function log(msg) { console.log(root.logTag + " " + msg) }

  // ---- estado de la barra ------------------------------------------------
  // `shell.bar` son escalares con bindings vivos (position, barSize,
  // barHidden, fontFamily). No hace falta vigilar ningún archivo de estado, y
  // conviene no hacerlo: el watcher de `bar-off` que usa bar-shadow puede
  // quedarse mudo y depende de un nudge por IPC que a nosotros no nos llega.
  readonly property var barState: shell ? shell.bar : null
  readonly property string barPosition: barState ? String(barState.position || "top") : "top"
  readonly property bool barVertical: barPosition === "left" || barPosition === "right"
  readonly property bool barHidden: barState ? barState.barHidden === true : false

  // `shell.bar` queda en null mientras el Loader de la barra se recarga, así
  // que barSize pasa por 0 en algunos frames. El default evita que la ventana
  // colapse durante ese parpadeo.
  readonly property int barSize: {
    var s = barState ? Number(barState.barSize) : 0
    return (isFinite(s) && s > 0) ? Math.round(s) : 26
  }

  // Alto de la ventana: la franja de la barra más lugar para el globo. Es
  // FIJO a propósito — una superficie que se redimensiona hace que el
  // compositor escale un buffer viejo por un frame.
  readonly property int balloonRoom: 120

  // ---- el monitor con foco ----------------------------------------------
  // Un solo perro, en la pantalla que el usuario está mirando. Vacío hasta
  // que Hyprland reporta; ahí caemos al primer screen en vez de adivinar.
  readonly property string focusedScreenName:
    Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : ""

  // ---- configuración -----------------------------------------------------
  // La entrada del plugin vive en `bar.layout.<sección>` de shell.json, no en
  // `plugins[]`, porque el manifiesto declara un kind `bar-widget`.
  //
  // Se lee de `shell.barConfig` y NO del widget: probamos el camino del
  // widget y trae una carrera de arranque real — empuja un objeto vacío
  // antes de que el host le llene `settings`, y pisa lo bueno.
  // `shell.barConfig` es la fuente autoritativa y siempre está completa: no
  // hay carrera de arranque que resolver, ni forma de que un empujón vacío
  // del widget pise la config buena. Se reevalúa sola cuando el host
  // refresca las fachadas.
  readonly property var settings: {
    var bc = shell ? shell.barConfig : null
    if (!bc || !bc.layout) return ({})
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var list = bc.layout[sections[s]]
      if (!list || typeof list.length !== "number") continue
      for (var i = 0; i < list.length; i++) {
        var e = list[i]
        if (e && String(e.id).replace(/^@/, "") === root.pluginId) return e
      }
    }
    return ({})
  }

  onSettingsChanged: root.log("settings: " + JSON.stringify(root.settings))

  onBarVerticalChanged: if (root.barVertical)
    root.log("barra vertical: Atom se esconde. Caminar en el otro eje es otro diseño, no un ajuste.")

  function cfg(name, fallback) {
    var v = settings ? settings[name] : undefined
    return (v === undefined || v === null) ? fallback : v
  }

  // ---- el widget ---------------------------------------------------------
  // Idempotente: cualquier escritura de shell.json destruye y recrea servicio
  // y widget, así que esto se llama más de una vez por sesión.
  property var widget: null

  function registerWidget(w) {
    if (root.widget === w) return
    root.widget = w
    root.log("widget registrado")
  }

  // Adelanto verificado de la Fase 5: el widget es el único que ve la barra.
  function barGeometry() {
    if (!root.widget || typeof root.widget.measure !== "function") return null
    try {
      return root.widget.measure()
    } catch (e) {
      root.log("measure() falló: " + e)
      return null
    }
  }

  // ---- el cuerpo ---------------------------------------------------------
  readonly property int dogWidth: 28
  readonly property int dogHeight: 20

  // Un solo cerebro: una pose, una posición, un ciclo. Las ventanas de los
  // otros monitores existen pero dibujan vacío.
  // Las dos poses que el servicio necesita nombrar. El renderer y el Mover no
  // nombran ninguna: `canMove` es dato de la pose y el cross-fade recorre el
  // registro. Acá quedan porque orquestar necesita saber cuál es la pose de
  // reposo y cuál es la que se traslada. Si algún día hay una segunda pose
  // que se mueve (correr, saltar), esto es lo único que hay que revisar.
  readonly property string restPose: "stand"
  readonly property string movingPose: "walk"

  property string poseId: root.restPose
  property bool speaking: false
  property real stateSince: Date.now()

  onPoseIdChanged: root.stateSince = Date.now()

  // El renderer del monitor con foco. Es quien le da al Mover la pose activa
  // como objeto, para que `canMove` salga de la pose y no de una tabla
  // paralela que se puede desincronizar.
  property var activeAtom: null

  Mover {
    id: mover
    pose: root.activeAtom ? root.activeAtom.current : null
    speed: 55
  }

  // Destino pendiente mientras el perro todavía no está en pose de caminar.
  // Es la invariante hecha secuencia: primero cambia de pose, DESPUÉS se
  // mueve. Nunca al revés, nunca las dos cosas a la vez.
  property real pendingTarget: NaN

  // ---- motor de viajes ---------------------------------------------------
  // Un viaje es una lista de tramos (brain/Trips.js). Esto los ejecuta uno
  // por uno, y es el único lugar del proyecto que mueve al perro.
  property var trip: []
  property int tripIndex: 0
  property var currentLeg: null

  function startTrip(legs) {
    if (!legs || legs.length === 0) return false
    root.trip = legs
    root.tripIndex = 0
    root.runNextLeg()
    return true
  }

  function runNextLeg() {
    if (root.tripIndex >= root.trip.length) {
      root.trip = []
      root.currentLeg = null
      if (root.canPoseMove(root.poseId)) root.poseId = root.restPose
      return
    }

    var leg = root.trip[root.tripIndex]
    root.tripIndex += 1
    root.currentLeg = leg

    mover.speed = Number(leg.speed) > 0 ? Number(leg.speed) : 55

    var want = leg.pose ? String(leg.pose) : root.movingPose
    if (!root.hasPose(want)) want = root.movingPose

    // La pose primero, el movimiento después. Siempre en ese orden: el
    // pedido de traslado queda pendiente y sale cuando la pose lo permite.
    if (root.poseId !== want) {
      root.pendingTarget = Number(leg.x)
      root.poseId = want
    } else {
      mover.walkTo(Number(leg.x))
    }
  }

  // Las poses que se trasladan. La regla dejó de ser "solo caminando" y pasó
  // a ser "solo las poses que lo declaran": la cabriola necesita moverse y
  // fingir lo contrario habría sido esconder el traslado del mecanismo que
  // lo controla. Lo que importaba —que un perro sentado, echado o dormido no
  // se deslice— sigue intacto y se sigue verificando sobre el registro
  // entero con `omarchy-shell atom invariant`.
  function canPoseMove(id) {
    return id === root.movingPose || id === root.jumpPose
  }

  function goTo(x) {
    return root.startTrip([{ x: x }])
  }

  Connections {
    target: mover

    // Cuando la pose activa pasa a una que se traslada, recién ahí sale el
    // viaje que estaba esperando.
    function onCanMoveChanged() {
      if (mover.canMove && isFinite(root.pendingTarget)) {
        var t = root.pendingTarget
        root.pendingTarget = NaN
        mover.walkTo(t)
      }
    }

    function onArrived(at) {
      var leg = root.currentLeg
      if (!leg) {
        if (root.canPoseMove(root.poseId)) root.poseId = root.restPose
        return
      }

      // La vuelta al mundo: el salto al otro borde ocurre cuando el perro ya
      // está fuera de cuadro, así que no se ve nada raro.
      if (isFinite(Number(leg.wrapTo))) {
        mover.freeze()
        mover.pos = Number(leg.wrapTo)
      }

      // Llegó con una intención: quedarse en otra pose un rato.
      if (leg.holdPose && root.hasPose(String(leg.holdPose))) {
        if (leg.faceLeft !== undefined) mover.facingLeft = leg.faceLeft === true
        root.poseId = String(leg.holdPose)
        if (leg.log) root.log(String(leg.log))
        holdTimer.interval = Math.max(300, Number(leg.holdMs) || 2000)
        holdTimer.restart()
        return
      }

      var pause = Number(leg.pauseMs) || 0
      if (pause > 0) {
        pauseTimer.interval = pause
        pauseTimer.restart()
        return
      }
      root.runNextLeg()
    }

    // El rechazo no es un error: es el mecanismo funcionando.
    function onRefused(target, reason) {
      root.log("movimiento rechazado (" + reason + ")")
    }
  }

  // ---- el ciclo de ocio --------------------------------------------------

  // Una pose solo se usa si está en el registro. Así se pueden agregar filas
  // de comportamiento antes de que exista el dibujo, y no pasa nada.
  function hasPose(id) {
    return Poses.byId(String(id)) !== null
  }

  // ---- hacerle pis a un widget -------------------------------------------
  // El único viaje con intención: en vez de ir a un hueco cualquiera, va al
  // borde de un widget concreto. Mirando a la derecha la pata trasera queda
  // del lado izquierdo, así que se para JUSTO a la derecha del widget y el
  // objetivo le queda contra la cola.
  property var pendingEvents: []

  function fireEvent(name) {
    var q = root.pendingEvents
    q.push(String(name))
    root.pendingEvents = q
  }

  property string peeTarget: ""

  // Mirando a la derecha la pata trasera queda a la izquierda del perro, así
  // que el objetivo tiene que quedarle detrás. Hay dos formas de lograrlo:
  // pararse a la derecha del widget mirando a la derecha, o a la izquierda
  // mirando a la izquierda. Considerar los dos lados importa: el lado derecho
  // del reloj está tapado por el widget del clima, y sin esto el reloj —que
  // es el que el usuario pidió— sería inalcanzable.
  function peeSpots(g) {
    var out = []
    for (var i = 0; i < g.obstacles.length; i++) {
      var o = g.obstacles[i]
      if (o.id === root.pluginId) continue          // no se hace pis a sí mismo

      // `clean` = el lugar está libre. Los sucios también entran, pero solo
      // se usan si el objetivo lo vale: ver la excepción en goPee().
      var right = o.x + o.w + 4
      if (right + root.dogWidth <= g.barWidth - 2) {
        out.push({ x: right, id: o.id, faceLeft: false,
                   clean: Gaps.isStillValid(right, root.dogWidth, g.obstacles) })
      }

      var left = o.x - 4 - root.dogWidth
      if (left >= 2) {
        out.push({ x: left, id: o.id, faceLeft: true,
                   clean: Gaps.isStillValid(left, root.dogWidth, g.obstacles) })
      }
    }
    return out
  }

  function goPee() {
    if (!root.hasPose("pee")) return false
    var g = root.barGeometry()
    if (!g) return false
    var spots = root.peeSpots(g)
    if (spots.length === 0) return false

    // El reloj tiene prioridad: fue el pedido explícito del usuario.
    //
    // Y acá va la única excepción a "nunca se detiene encima de un widget":
    // el reloj está encajonado entre los indicadores y el clima, sin un píxel
    // libre al lado, así que respetando la regla sería inalcanzable para
    // siempre. Hacerle pis es un acto breve y deliberado —cuatro segundos, en
    // una pose que no deja dudas de que es a propósito—, no un lugar donde se
    // queda a vivir. Para todo lo demás la regla sigue en pie: los otros
    // objetivos solo se eligen si el lugar está limpio.
    var pick = null
    for (var i = 0; i < spots.length; i++) {
      if (String(spots[i].id).indexOf("clock") >= 0) { pick = spots[i]; break }
    }
    if (!pick) {
      var clean = []
      for (var j = 0; j < spots.length; j++) if (spots[j].clean) clean.push(spots[j])
      if (clean.length === 0) return false
      pick = clean[Math.floor(Math.random() * clean.length)]
    }

    root.peeTarget = pick.id
    var legs = Trips.peeTrip(pick, 4200, spots, "pee")
    legs[0].faceLeft = pick.faceLeft === true
    legs[0].log = "le hace pis a " + pick.id
    return root.startTrip(legs)
  }

  property Timer holdTimer: Timer {
    repeat: false
    onTriggered: root.runNextLeg()
  }

  property Timer pauseTimer: Timer {
    repeat: false
    onTriggered: root.runNextLeg()
  }

  property Timer hoverDemoTimer: Timer {
    repeat: false
    onTriggered: root.hovering = false
  }

  // Cinco formas de pasear, sorteadas: mudarse de hueco, cruzar de punta a
  // punta, dar la vuelta por el borde de la pantalla, hacer la ronda parando
  // en cada hueco, o mandarse una corrida y volver.
  function wander() {
    var g = root.barGeometry()
    if (!g) return false
    var stops = Gaps.restStops(g.barWidth, g.obstacles, root.dogWidth)
    if (stops.length === 0) return false      // barra llena: se queda donde está

    var plan = Trips.randomWalk({
      stops: stops,
      barWidth: g.barWidth,
      dogWidth: root.dogWidth,
      currentX: mover.pos,
      stop: Gaps.pickStop(stops, mover.pos, 40)
    })
    if (!plan.legs || plan.legs.length === 0) return false
    root.log("pasea: " + plan.kind)
    return root.startTrip(plan.legs)
  }

  // La cabriola: un salto grande y un rebote corto al caer. Viaja en la pose
  // `jump`, que es la segunda pose que declara que se traslada.
  readonly property string jumpPose: "jump"

  function cabriola() {
    if (!root.hasPose(root.jumpPose)) return false
    var g = root.barGeometry()
    var w = g ? g.barWidth : 1366
    var legs = Trips.cabriola(mover.pos, w, root.dogWidth, Math.random, root.jumpPose)
    return root.startTrip(legs)
  }

  // ¿Hay alguna pantalla donde se lo pueda ver? Con la barra oculta o
  // vertical no hay a quién hablarle: los relojes siguen contando —eso no se
  // detiene nunca— pero no camina ni tira un globo que nadie va a leer.
  readonly property bool onStage: !root.barHidden && !root.barVertical

  function tick() {
    var now = Date.now()
    // El pomodoro avanza aunque no haya barra: el tiempo no se detiene.
    root.pomoTick(now)
    if (!root.onStage) return

    // R10: el hueco donde está sentado se puede invalidar solo — el reloj
    // cambia de ancho cada minuto. Se levanta y camina; jamás se recoloca
    // sentado, porque eso rompería la invariante de movimiento.
    //
    // Pero solo cuando NO está en medio de un viaje: si está haciendo pis
    // está parado sobre un widget a propósito, y sin este guard el chequeo
    // lo lee como "estás en un mal lugar" y lo manda a pasear a los dos
    // segundos, cortando el gesto por la mitad.
    var enViaje = root.trip.length > 0 || holdTimer.running || pauseTimer.running
    if (!enViaje && !mover.moving && !isFinite(root.pendingTarget) && !root.holdingStill) {
      var g = root.barGeometry()
      if (g && !Gaps.isStillValid(mover.pos, root.dogWidth, g.obstacles)) {
        root.log("el hueco se invalidó; a buscar otro")
        root.wander()
        return
      }
    }

    var ctx = root.context(now)

    // Con el puntero encima (o eligiendo un pomodoro) se queda sentado
    // mirándote; en foco, echado y callado. En los dos casos no pasea ni
    // habla: la tabla de ocio no corre.
    if (root.holdingStill || root.pomo.mode === "focus") {
      root.pendingEvents = []
      var still = root.pomo.mode === "focus" && !root.holdingStill
                    ? (ctx.away ? "sleep" : "lie") : "sit"
      if (!enViaje && !mover.moving && !root.speaking
          && root.poseId !== still && root.hasPose(still))
        root.poseId = still
      return
    }

    // Los eventos puntuales (un click, una vuelta al teclado) se encolan
    // cuando pasan y se consumen en el tick siguiente: el ciclo de ocio se
    // evalua una vez por segundo y no queremos que se pierdan en el medio.
    var events = root.pendingEvents
    root.pendingEvents = []
    if (ctx.away) events.push("away")
    if (root.speaking) events.push("speaking")

    var next = Behavior.nextState(root.poseId, now - root.stateSince, events)
    if (next === root.movingPose) {
      // Uno de cada cuatro paseos es con intención.
      if (Math.random() < 0.25 && root.goPee()) return
      root.wander()
    } else if (next && root.hasPose(next)) {
      root.poseId = next
    }

    root.maybeSpeak(ctx, now)
  }

  // ═══ Fase 6 · sensores, relojes y contexto ═══════════════════════════════

  readonly property int breakSeconds: Number(root.cfg("breakSeconds", 180))
  readonly property int switchGraceSeconds: Number(root.cfg("switchGraceSeconds", 90))

  readonly property var clockOpts: ({
    pauseMs: root.breakSeconds * 1000,
    graceMs: root.switchGraceSeconds * 1000
  })

  Sensors {
    id: sensors
    breakSeconds: root.breakSeconds
    probePath: root.pluginDir + "/sensors/focus-probe"
  }

  // El estado de los dos relojes. Vive como dato plano porque Clocks.js es
  // JS puro y testeable: acá no hay lógica, solo el resultado.
  property var clocks: Clocks.create(Date.now(), "")

  Connections {
    target: sensors.windowFocus
    function onLabelChanged() {
      var app = sensors.windowFocus.label
      if (app === "") return
      root.clocks = Clocks.onFocus(root.clocks, app, Date.now(), root.clockOpts)
      root.dirty = true
    }
  }

  Connections {
    target: sensors.idleState
    function onIdleFlipped(isIdle) {
      root.clocks = Clocks.onIdleChanged(root.clocks, isIdle, Date.now(), root.clockOpts)
      root.dirty = true
      root.log(isIdle ? "te fuiste" : "volviste")
      if (!isIdle) root.fireEvent("back")
    }
  }

  // El contexto: lo único que las reglas conocen del mundo.
  function context(nowMs) {
    var now = nowMs || Date.now()
    var ctx = sensors.context()
    var snap = Clocks.snapshot(root.clocks, now, root.clockOpts)
    for (var k in snap) ctx[k] = snap[k]
    ctx.cfg = {
      stretchMinutes: Number(root.cfg("stretchMinutes", 45)),
      marathonMinutes: Number(root.cfg("marathonMinutes", 120)),
      waterMinutes: Number(root.cfg("waterMinutes", 60))
    }
    return ctx
  }

  // ---- persistencia ------------------------------------------------------
  // Obligatoria, no opcional: cualquier escritura de shell.json —un
  // `omarchy bar move`, un ajuste propio— destruye y recrea este servicio.
  // Sin esto, mover un widget te reinicia la sesión de trabajo.
  property bool dirty: false

  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/atom/state.json"

  // FileView puede disparar onLoaded más de una vez durante el arranque (la
  // precarga implícita al resolverse `path`, más el reload() explícito), así
  // que el arranque de los relojes está guardado por una bandera.
  property bool clocksBooted: false

  property FileView stateFile: FileView {
    path: root.statePath
    printErrors: false
    onLoaded: root.bootClocks(stateFile.text())
    onLoadFailed: root.bootClocks("")
  }

  // Restaurar SIEMPRE antes de sembrar: al revés, la siembra crearía relojes
  // nuevos y el primer guardado pisaría la sesión que el usuario traía.
  function bootClocks(raw) {
    if (root.clocksBooted) return
    root.clocksBooted = true

    var now = Date.now()
    if (raw && String(raw).length > 2) {
      try {
        root.clocks = Clocks.parse(raw, now, root.clockOpts)
        root.log("relojes restaurados: " + JSON.stringify(Clocks.snapshot(root.clocks, now, root.clockOpts)))
      } catch (e) {
        root.log("no pude restaurar los relojes: " + e)
      }
    }

    // Sembrar la racha con lo que ya está enfocado: `onLabelChanged` solo
    // dispara en los cambios, y al arrancar la ventana ya está elegida.
    var app = sensors.windowFocus.label
    if (app !== "") {
      root.clocks = Clocks.onFocus(root.clocks, app, now, root.clockOpts)
      root.log("racha en: " + app)
    }
    root.persist()
  }

  function persist() {
    // Sin condición de `dirty`: el estado son cuatro timestamps y perder la
    // sesión de trabajo del usuario cuesta mucho más que escribir 200 bytes
    // por minuto. El `dirty` quedó para no escribir antes de tener nada.
    if (!root.clocks) return
    root.dirty = false
    try {
      stateFile.setText(Clocks.stringify(root.clocks, Date.now()))
    } catch (e) {
      root.log("no pude guardar: " + e)
    }
  }

  // Con throttle: el disco no tiene por qué enterarse de cada alt-tab.
  property Timer persistTimer: Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: root.persist()
  }

  property Process mkStateDir: Process {
    running: true      // sin esto el Process se queda quieto para siempre
    command: ["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/atom"]
  }

  // ═══ Fase 7 · hablar ═════════════════════════════════════════════════════

  readonly property int quietMinutes: Number(root.cfg("quietMinutes", 20))
  readonly property int bubbleSeconds: Number(root.cfg("bubbleSeconds", 14))

  // Cuántos minutos antes se pide la frase. Medido: `claude -p` con nuestro
  // prompt tarda de 12 a 81 segundos, así que pedirla en el momento en que la
  // regla dispara llega tarde siempre. Las reglas son predecibles: a los 42
  // minutos ya sabemos que `stretch` va a disparar a los 45.
  readonly property int prefetchMinutes: 3

  property bool muted: false
  property var lastFired: ({})
  property real lastSpokeAt: 0
  property var prefetched: ({})
  property string prefetchingFor: ""

  readonly property string pluginDir: {
    var u = String(Qt.resolvedUrl("."))
    return u.replace(/^file:\/\//, "").replace(/\/$/, "")
  }

  Voice {
    id: voice
    scriptPath: root.pluginDir + "/voice/atom-say"
    useClaude: root.cfg("useClaude", true) === true
    sendTitles: root.cfg("sendTitles", true) === true
    model: String(root.cfg("model", "haiku"))
    // Holgado a propósito: la frase se pide prefetchMinutes antes de hacer
    // falta, así que esperar no se nota. Cortar antes la manda al banco local.
    timeoutSeconds: 90

    onSaid: function (ruleId, text, source) {
      // Si era un pedido anticipado, se guarda y nadie se entera todavía.
      if (root.prefetchingFor === ruleId) {
        root.prefetched[ruleId] = text
        root.prefetchingFor = ""
        root.log("frase lista por adelantado (" + ruleId + ", " + source + ")")
        return
      }
      root.show(ruleId, text, source)
    }
  }

  function maybeSpeak(ctx, now) {
    // Durante un pomodoro hablan solo sus propias frases.
    if (root.pomoActive || root.picking) return
    if (root.muted) return
    if (ctx.away) return
    if (root.speaking) return

    // La ventana de silencio global: pase lo que pase, nunca dos veces
    // dentro de este rato.
    if (now - root.lastSpokeAt < root.quietMinutes * 60000) {
      root.maybePrefetch(ctx, now)
      return
    }

    var rule = Rules.pick(ctx, root.lastFired, now)
    if (!rule) {
      root.maybePrefetch(ctx, now)
      return
    }

    root.lastFired[rule.id] = now
    root.lastSpokeAt = now

    var cached = root.prefetched[rule.id]
    if (cached) {
      delete root.prefetched[rule.id]
      root.show(rule.id, cached, "anticipada")
      return
    }
    // No estaba lista: se pide ahora y el globo aparece cuando llegue. Si
    // falla, la cadena de voces contesta con el banco local al instante.
    voice.request(rule, ctx)
  }

  // Mira el futuro cercano y pide la frase de la regla que está por disparar.
  function maybePrefetch(ctx, now) {
    if (voice.busy || root.prefetchingFor !== "") return

    var future = {}
    for (var k in ctx) future[k] = ctx[k]
    future.streakMinutes = Number(ctx.streakMinutes) + root.prefetchMinutes
    future.sessionMinutes = Number(ctx.sessionMinutes) + root.prefetchMinutes

    var rule = Rules.pick(future, root.lastFired, now + root.prefetchMinutes * 60000)
    if (!rule) return
    if (root.prefetched[rule.id]) return

    root.prefetchingFor = rule.id
    voice.request(rule, future)
  }

  function show(ruleId, text, source) {
    root.spokenText = text
    root.speaking = true
    root.poseId = root.restPose      // hablar lo pone de pie
    root.log("dice (" + source + "): " + text)
    bubbleTimer.restart()
  }

  // ═══ Fase 8 · interacción ════════════════════════════════════════════════

  property string spokenText: ""
  property bool hovering: false

  // Un solo globo para dos usos. Hablar le gana al hover: si Atom tiene algo
  // que decirte, no se lo tapa un dato que podés mirar cuando quieras.
  readonly property string bubbleText: root.speaking ? root.spokenText : root.hoverText
  readonly property bool bubbleShown: (root.speaking || root.hovering) && !root.picking

  function minutesLabel(m) {
    var n = Math.max(0, Math.floor(Number(m) || 0))
    if (n < 60) return n + " min"
    var h = Math.floor(n / 60)
    var r = n % 60
    return r === 0 ? h + " h" : h + " h " + r
  }

  readonly property string hoverText: {
    if (root.pomoActive)
      return (root.pomo.mode === "focus" ? "foco" : "descanso") + " · faltan "
             + Pomodoro.minutesLeftLabel(Pomodoro.remainingMs(root.pomo, root.hoverStamp))
    var s = Clocks.snapshot(root.clocks, root.hoverStamp, root.clockOpts)
    var app = s.streakApp || sensors.windowFocus.label || "nada"
    var head = root.muted ? "(mudo) " : ""
    return head + app + " · " + root.minutesLabel(s.streakMinutes)
         + "   ·   sesión " + root.minutesLabel(s.sessionMinutes)
         + (root.muted ? "" : "\n↕ deslizá para un pomodoro")
  }

  // El texto del hover se recalcula al entrar, no cada segundo: es un dato
  // que se mira un instante, no un cronómetro.
  property real hoverStamp: 0

  // Click izquierdo: le pedís un comentario ahora.
  function onDemand() {
    if (root.muted) { root.toggleMute(); return }
    // La cabriola sale al instante: un click tiene que responder ya, y el
    // ciclo de ocio se evalúa una vez por segundo.
    root.cabriola()
    if (root.speaking) return
    var rule = Rules.ruleById("ondemand")
    if (!rule) return
    root.lastSpokeAt = Date.now()
    voice.request(rule, root.context(Date.now()))
  }

  // Click derecho: lo silenciás o lo despertás.
  function toggleMute() {
    root.muted = !root.muted
    root.speaking = false
    root.log(root.muted ? "silenciado" : "despierto")
  }

  // Click del medio: "acabo de volver de una pausa". Reinicia los dos relojes.
  function resetClocks() {
    var app = sensors.windowFocus.label
    root.clocks = Clocks.create(Date.now(), app)
    root.dirty = true
    root.persist()
    root.lastFired = ({})
    root.log("relojes reiniciados a mano")
  }

  property Timer bubbleTimer: Timer {
    interval: Math.max(4, root.bubbleSeconds) * 1000
    repeat: false
    onTriggered: root.speaking = false
  }

  property Timer brainTimer: Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.tick()
  }

  // ═══ Pomodoro ═══════════════════════════════════════════════════════════
  // Solo si lo pedís: arranca con el gesto sobre el perro (o por IPC) y Atom
  // nunca lo sugiere. La lógica es pura y vive en brain/Pomodoro.js; acá se
  // conecta con el cuerpo, el globo y el disco.

  readonly property int pomodoroScrollPx: Math.max(10, Number(root.cfg("pomodoroScrollPx", 60)))
  readonly property int pomodoroPickMs: Math.max(2, Number(root.cfg("pomodoroPickSeconds", 6))) * 1000

  property var pomo: Pomodoro.create()
  property var picker: null                 // no es null mientras elegís
  readonly property bool picking: root.picker !== null
  readonly property bool pomoActive: Pomodoro.isActive(root.pomo)
  property var pomoLastLine: ({})           // para no repetir la frase anterior
  property real askStopUntil: 0
  property bool wagging: false

  // Con el puntero encima se queda quieto: un blanco de 28 px que camina es
  // imposible de agarrar con touchpad. Durante el foco no hace falta, ya está
  // echado.
  readonly property bool holdingStill: root.picking || (root.hovering && !root.pomoActive)

  // El selector se dibuja en cada ventana; estas señales les llegan a todas.
  signal pickerPoked()
  signal pickerBumped()

  function pomoBubble(text, ms) {
    if (!text) return
    bubbleTimer.stop()
    root.spokenText = text
    root.speaking = true
    pomoBubbleTimer.interval = ms
    pomoBubbleTimer.restart()
    root.log("pomodoro: " + text)
  }

  function pomoSay(kind, ms) {
    var vars = { focus: root.pomo.focus || root.pomo.last.focus,
                 rest: root.pomo.rest || root.pomo.last.rest }
    var l = Pomodoro.line(kind, vars, root.pomoLastLine[kind], Math.random)
    root.pomoLastLine[kind] = l.index
    root.pomoBubble(l.text, ms)
  }

  function pomoTick(now) {
    var r = Pomodoro.tick(root.pomo, now)
    if (!r.event) return
    root.pomo = r.state
    root.persistPomo()
    root.lastSpokeAt = now           // las reglas esperan su ventana de silencio
    // Si terminó con el shell apagado, anunciarlo ahora no tiene sentido.
    if (r.lateMs > 120000) { root.log("pomodoro: " + r.event + " (tarde, en silencio)"); return }
    root.pomoSay(r.event, r.event === "focusEnd" ? 9000 : 6000)
  }

  // Frena lo que esté haciendo y se sienta. Respeta la invariante: congela
  // primero y recién después cambia a una pose quieta.
  function holdStill() {
    var moving = root.trip.length > 0 || mover.moving || isFinite(root.pendingTarget)
    root.trip = []
    root.currentLeg = null
    root.pendingTarget = NaN
    holdTimer.stop()
    pauseTimer.stop()
    mover.freeze()
    if ((moving || root.canPoseMove(root.poseId)) && root.hasPose("sit")) root.poseId = "sit"
  }

  function pickStart(axis) {
    root.picker = Pomodoro.pickerCreate(root.pomo.last, axis)
    root.holdStill()
    pickTimer.restart()
    root.pickerPoked()
  }

  // `dx` y `dy` en la convención de los dedos: positivo = arriba / derecha.
  function pickWheel(dx, dy) {
    if (root.muted || root.pomoActive) return
    if (!root.picking) root.pickStart(Math.abs(dx) > Math.abs(dy) ? "x" : "y")
    var r = Pomodoro.pickerWheel(root.picker, dx, dy, Date.now(), root.pomodoroScrollPx)
    root.picker = r.picker
    if (r.steps !== 0) {
      root.wagging = true
      wagTimer.restart()
    }
    if (r.bumped) root.pickerBumped()
    pickTimer.restart()
    root.pickerPoked()
  }

  function pickConfirm() {
    if (!root.picking) return
    var p = root.picker
    root.picker = null
    pickTimer.stop()
    root.pomo = Pomodoro.start(root.pomo, p.focus, p.rest, Date.now())
    root.persistPomo()
    root.log("pomodoro: foco " + p.focus + " / descanso " + p.rest)
    root.cabriola()
    root.pomoSay("start", 1800)
  }

  function pickCancel() {
    if (!root.picking) return
    root.picker = null
    pickTimer.stop()
    root.pomoSay("cancelPick", 2600)
  }

  function pomoStop() {
    if (!root.pomoActive) return
    root.pomo = Pomodoro.stop(root.pomo)
    root.persistPomo()
    root.askStopUntil = 0
    root.pomoSay("cancelStop", 2800)
  }

  // Dos dedos durante un pomodoro: el primero pregunta, el segundo corta.
  function askStop() {
    var now = Date.now()
    if (now < root.askStopUntil) { root.pomoStop(); return }
    root.askStopUntil = now + 3000
    root.pomoSay("askStop", 3000)
  }

  // Lo que manda Qt, traducido a la convención de los dedos. El touchpad trae
  // píxeles; una rueda de mouse trae muescas de 120, y cada muesca es un paso.
  // `inverted` es el natural scroll: se deshace para que "dedos arriba" sea
  // siempre "más minutos".
  property real lastWheelLogMs: 0
  function onWheel(w) {
    var dx, dy
    if (w.pixelDelta.x !== 0 || w.pixelDelta.y !== 0) {
      dx = -w.pixelDelta.x
      dy = w.pixelDelta.y
    } else {
      dx = -w.angleDelta.x / 120 * root.pomodoroScrollPx
      dy = w.angleDelta.y / 120 * root.pomodoroScrollPx
    }
    if (w.inverted) { dx = -dx; dy = -dy }

    var now = Date.now()
    if (now - root.lastWheelLogMs > 1000)
      root.log("rueda: px=" + w.pixelDelta.x + "," + w.pixelDelta.y
               + " ang=" + w.angleDelta.x + "," + w.angleDelta.y
               + " inverted=" + w.inverted)
    root.lastWheelLogMs = now
    root.pickWheel(dx, dy)
  }

  function onPress(button) {
    if (button === Qt.RightButton) {
      if (root.picking) root.pickCancel()
      else if (root.pomoActive) root.askStop()
      else root.toggleMute()
    } else if (button === Qt.MiddleButton) {
      root.resetClocks()
    } else {
      if (root.picking) root.pickConfirm()
      else if (root.pomoActive) root.cabriola()     // en foco, saltar sí; hablar no
      else root.onDemand()
    }
  }

  property Timer pickTimer: Timer {
    interval: root.pomodoroPickMs
    repeat: false
    onTriggered: root.pickCancel()
  }

  // Al agrandarse la región de input el compositor puede mandar un salir y
  // un entrar seguidos. Un salir solo cuenta si no volvés enseguida.
  property Timer exitGrace: Timer {
    interval: 400
    repeat: false
    onTriggered: if (!root.hovering) root.pickCancel()
  }

  property Timer pomoBubbleTimer: Timer {
    repeat: false
    onTriggered: root.speaking = false
  }

  property Timer wagTimer: Timer {
    interval: 260
    repeat: false
    onTriggered: root.wagging = false
  }

  // ---- persistencia del pomodoro ----
  // Archivo propio y no dentro de state.json: los relojes tienen su formato
  // versionado y esto no tiene por qué tocarlo.
  readonly property string pomoPath: Quickshell.env("HOME") + "/.local/state/atom/pomodoro.json"
  property bool pomoBooted: false

  property FileView pomoFile: FileView {
    path: root.pomoPath
    printErrors: false
    onLoaded: root.bootPomo(pomoFile.text())
    onLoadFailed: root.bootPomo("")
  }

  function bootPomo(raw) {
    if (root.pomoBooted) return
    root.pomoBooted = true
    // Si ya arrancó uno (por IPC, antes de que el archivo cargara), manda ese.
    if (raw && String(raw).length > 2 && !root.pomoActive) root.pomo = Pomodoro.parse(raw)
    if (root.pomoActive)
      root.log("pomodoro restaurado: " + root.pomo.mode + ", faltan "
               + Pomodoro.minutesLeftLabel(Pomodoro.remainingMs(root.pomo, Date.now())))
  }

  function persistPomo() {
    try {
      pomoFile.setText(Pomodoro.stringify(root.pomo))
    } catch (e) {
      root.log("no pude guardar el pomodoro: " + e)
    }
  }

  // El hitbox sigue al perro mientras camina, pero a 4 Hz y no por frame: lo
  // justo para poder agarrarlo con el puntero sin reemitir la región de input
  // sesenta veces por segundo.
  property real hitX: 0
  property Timer hitFollow: Timer {
    interval: 250
    repeat: true
    running: mover.moving
    onTriggered: root.hitX = mover.pos
  }
  Connections {
    target: mover
    function onPosChanged() { if (!mover.moving) root.hitX = mover.pos }
    function onMovingChanged() { root.hitX = mover.pos }
  }

  // ---- ventanas ----------------------------------------------------------
  // Una por monitor, mapeadas UNA VEZ y nunca desmapeadas: dentro de la capa
  // Overlay el orden lo fija el momento de mapeo, así que un `visible: false`
  // y su vuelta nos pondrían arriba de los desplegables de la barra y de las
  // notificaciones. Para esconder al perro se toca opacidad y máscara.
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData

      screen: modelData
      color: "transparent"
      visible: true

      WlrLayershell.namespace: "atom"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      // Ignore, NO Normal+exclusiveZone:0 — esa combinación respeta lo que
      // reservan los demás y el compositor te parkea DEBAJO de la barra.
      exclusionMode: ExclusionMode.Ignore

      // Tres lados anclados: el de la barra más los dos perpendiculares.
      anchors {
        top: root.barPosition === "top" || root.barVertical
        bottom: root.barPosition === "bottom" || root.barVertical
        left: root.barPosition === "left" || !root.barVertical
        right: root.barPosition === "right" || !root.barVertical
      }

      implicitWidth: root.barVertical ? root.barSize + root.balloonRoom : 0
      implicitHeight: root.barVertical ? 0 : root.barSize + root.balloonRoom

      readonly property bool isFocusedScreen:
        root.focusedScreenName !== ""
          ? root.focusedScreenName === String(modelData.name)
          : modelData === Quickshell.screens[0]

      // Fase 9. Con la barra vertical el perro tendría que caminar en el otro
      // eje: es otro diseño, no un ajuste. Se desactiva con un log claro en
      // vez de dibujar algo roto.
      readonly property bool shown: isFocusedScreen && !root.barHidden && !root.barVertical

      // La máscara se ata a un hitbox que NO se anima: solo salta cuando el
      // perro llega. Con el hitbox en 0×0 la región queda vacía, que en
      // layer-shell significa "nada recibe input, todo pasa al de abajo".
      mask: Region { item: hitbox }

      // El hitbox NO se anima: salta a la posición de reposo recién cuando el
      // perro llega. Mientras camina no es clickeable, que es justo lo que
      // queremos — y de paso la región de input no se reemite por frame.
      //
      // Mientras elegís un pomodoro se agranda a perro + selector, con margen:
      // con touchpad, correrse unos píxeles no puede cancelar la elección.
      Item {
        id: hitbox
        readonly property bool wide: root.picking && win.shown
        readonly property bool barTop: root.barPosition !== "bottom"
        readonly property real dogX: Math.round(root.hitX)
        readonly property real edgeL: Math.min(picker.x, dogX) - 12
        readonly property real edgeR: Math.max(picker.x + picker.width, dogX + root.dogWidth) + 12

        x: wide ? edgeL : dogX
        y: wide ? (barTop ? 0 : picker.y - 12)
                : (root.barPosition === "bottom" ? win.height - root.barSize : 0)
        width: wide ? edgeR - edgeL : (win.shown ? root.dogWidth : 0)
        height: wide ? (barTop ? picker.y + picker.height + 12 : win.height - (picker.y - 12))
                     : (win.shown ? root.barSize : 0)
      }

      Atom {
        id: atom

        x: Math.round(mover.pos)
        y: (root.barPosition === "bottom" ? win.height - root.barSize : 0)
           + root.barSize - root.dogHeight
        width: root.dogWidth
        height: root.dogHeight

        pose: root.poseId
        mirrored: mover.facingLeft
        speaking: root.speaking || root.wagging
        inkColor: root.muted ? root.mutedColor : root.inkColor
        fillColor: root.fillColor

        // Decisión medida: a tamaño real la respiración son 0.29 px — no se
        // ve — y cuesta ~2.4 puntos de CPU permanentes. Se apaga en la barra
        // y queda para los tamaños grandes.
        idleFps: 0
        motionFrameRate: 30

        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // Nada se anima si no se ve. Medido: una superficie animada cuesta
        // ~16 % de un core y quieta 0.02 %, así que esto no es pulido.
        reduceMotion: !win.shown || root.muted

        // El renderer del monitor con foco es el que le presta su pose activa
        // al Mover.
        onChosenChanged: if (chosen) root.activeAtom = atom
        readonly property bool chosen: win.shown
        Component.onCompleted: if (win.shown) root.activeAtom = atom
      }

      // El globo cuelga de donde esté el perro, dentro de la MISMA ventana.
      // No entra en la máscara de input a propósito: es informativo, y un
      // click encima pasa de largo. Es la forma más barata de "nunca
      // interrumpe".
      Bubble {
        id: bubble

        text: root.bubbleText
        shown: root.bubbleShown && win.shown
        inkColor: root.inkColor
        fillColor: root.fillColor
        borderColor: root.accentColor
        fontFamily: root.fontFamily
        maxWidth: Math.min(320, win.width - 24)

        x: Math.max(6, Math.min(atom.x - 16, win.width - width - 6))
        y: root.barPosition === "bottom"
             ? win.height - root.barSize - height - 6
             : root.barSize + 6
      }

      PomodoroPicker {
        id: picker

        focusMinutes: root.picker ? root.picker.focus : root.pomo.last.focus
        restMinutes: root.picker ? root.picker.rest : root.pomo.last.rest
        field: root.picker ? root.picker.field : "focus"
        expireMs: root.pomodoroPickMs
        shown: root.picking && win.shown
        inkColor: root.inkColor
        fillColor: root.fillColor
        accentColor: root.accentColor
        fontFamily: root.fontFamily

        x: Math.max(6, Math.min(atom.x - 16, win.width - width - 6))
        y: root.barPosition === "bottom"
             ? win.height - root.barSize - height - 6
             : root.barSize + 6

        Connections {
          target: root
          function onPickerPoked() { picker.restartExpiry() }
          function onPickerBumped() { picker.bump() }
        }
      }

      MouseArea {
        anchors.fill: hitbox
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onEntered: {
          root.hoverStamp = Date.now()
          root.hovering = true
          exitGrace.stop()
          if (!root.pomoActive && !root.picking) root.holdStill()
        }
        onExited: {
          root.hovering = false
          if (root.picking) exitGrace.restart()
        }

        onClicked: function (mouse) { root.onPress(mouse.button) }
        onWheel: function (wheel) { root.onWheel(wheel) }
      }
    }
  }

  // Colores del tema. Los empuja el widget, que sí puede importar qs.Commons.
  // `fillColor` es el fondo de la barra: con él se rellena el cuerpo para que
  // las patas del fondo queden detrás.
  property color inkColor: "#f6dcac"
  property color fillColor: "#05182e"
  property color accentColor: "#faa968"
  property color mutedColor: "#2a6b78"
  property string fontFamily: "monospace"

  // ---- IPC ---------------------------------------------------------------
  // Un plugin de terceros puede registrar su propio target (verificado).
  // Ojo: omarchy-shell corta a los 2 s, así que nada de esto puede esperar
  // una respuesta lenta.
  IpcHandler {
    target: "atom"

    function ping(): string {
      return "ok"
    }

    // Pasa por goTo, así que respeta la invariante: si la pose activa no se
    // traslada, primero cambia de pose y después camina.
    function moveTo(x: string): string {
      var n = Number(x)
      if (!isFinite(n)) return "nan"
      root.goTo(n)
      return "ok"
    }

    function pose(id: string): string {
      var want = String(id || "")
      var ids = Poses.ids()
      if (ids.indexOf(want) === -1) return "desconocida: " + ids.join(",")
      root.poseId = want
      return "ok"
    }

    function wander(): string {
      return root.wander() ? "ok" : "sin huecos"
    }

    // Teletransporta al perro sin caminar. Es lo único del proyecto que
    // mueve la `x` sin pasar por una pose que se traslade, y existe para dos
    // cosas puntuales: entrar en escena desde fuera de pantalla, y depurar.
    // No lo usa ningún comportamiento automático.
    function place(x: string): string {
      var n = Number(x)
      if (!isFinite(n)) return "nan"
      root.trip = []
      root.currentLeg = null
      root.pendingTarget = NaN
      mover.freeze()
      mover.pos = n
      return "ok"
    }

    // Fuerza un paseo concreto en vez de sortearlo. Existe para la demo y
    // para depurar: el comportamiento normal es el sorteo.
    function walk(kind: string): string {
      var g = root.barGeometry()
      if (!g) return "sin geometría"
      var stops = Gaps.restStops(g.barWidth, g.obstacles, root.dogWidth)
      if (stops.length === 0) return "sin huecos"
      var legs = Trips.planWalk(String(kind || "stop"), {
        stops: stops,
        barWidth: g.barWidth,
        dogWidth: root.dogWidth,
        currentX: mover.pos,
        stop: Gaps.pickStop(stops, mover.pos, 40)
      }, Math.random)
      if (!legs || legs.length === 0) return "ese paseo no da tramos acá"
      root.log("pasea: " + kind + " (a pedido)")
      return root.startTrip(legs) ? "ok" : "no"
    }

    function cabriola(): string {
      return root.cabriola() ? "ok" : "no hay pose jump"
    }

    // Muestra el globo del hover sin que haya un mouse encima.
    function hover(seconds: string): string {
      var s = Number(seconds)
      root.hoverStamp = Date.now()
      root.hovering = true
      hoverDemoTimer.interval = Math.max(1000, (isFinite(s) ? s : 4) * 1000)
      hoverDemoTimer.restart()
      return "ok"
    }

    function pee(): string {
      if (!root.hasPose("pee")) return "todavía no existe la pose"
      return root.goPee() ? "en camino a " + root.peeTarget : "sin lugar donde"
    }

    // Prueba de la invariante, sobre el registro entero y no sobre una pose
    // elegida a mano: para cada pose, pide un traslado y anota si se movió.
    function invariant(): string {
      var ids = Poses.ids()
      var before = root.poseId
      var out = []
      for (var i = 0; i < ids.length; i++) {
        root.poseId = ids[i]
        var accepted = mover.walkTo(mover.pos + 50)
        if (accepted) mover.freeze()
        out.push(ids[i] + "=" + (accepted ? "SE MUEVE" : "quieto"))
      }
      root.poseId = before
      return out.join(" · ")
    }

    // Fuerza una frase ya, sin esperar a que una regla cumpla su condición.
    function say(ruleId: string): string {
      var want = String(ruleId || "ondemand")
      var rule = Rules.ruleById(want)
      if (!rule) return "regla desconocida"
      root.lastSpokeAt = Date.now()
      root.lastFired[want] = Date.now()
      var ok = voice.request(rule, root.context(Date.now()))
      return ok ? "queued" : "ocupado"   // nunca espera: el CLI corta a los 2 s
    }

    function context(): string {
      return JSON.stringify(root.context(Date.now()))
    }

    // `omarchy-shell atom pomodoro 50 10`. Sin números ("" "") usa los últimos.
    function pomodoro(focus: string, rest: string): string {
      root.picker = null
      root.pomo = Pomodoro.start(root.pomo, focus, rest, Date.now())
      root.persistPomo()
      root.pomoSay("start", 1800)
      return "foco " + root.pomo.focus + " / descanso " + root.pomo.rest
    }

    // Para un atajo de teclado: repite el último.
    function pomodoroAgain(): string {
      return pomodoro("", "")
    }

    function pomodoroStop(): string {
      if (!root.pomoActive) return "no hay pomodoro"
      root.pomoStop()
      return "cortado"
    }

    function pomodoroStatus(): string {
      var p = root.pomo
      if (!Pomodoro.isActive(p)) return "off (último: " + p.last.focus + "/" + p.last.rest + ")"
      return p.mode + " " + p.focus + "/" + p.rest + ", faltan "
             + Pomodoro.minutesLeftLabel(Pomodoro.remainingMs(p, Date.now()))
    }

    // Para depurar sin touchpad: un evento de scroll en la convención de los
    // dedos (positivo = arriba / derecha), y el tap que confirma.
    function pick(dx: string, dy: string): string {
      root.pickWheel(Number(dx) || 0, Number(dy) || 0)
      return root.picking ? "foco " + root.picker.focus + " / descanso " + root.picker.rest
                            + " (" + root.picker.field + ")" : "no se pudo"
    }

    function tap(): string {
      root.onPress(Qt.LeftButton)
      return root.picking ? "eligiendo" : (root.pomoActive ? root.pomo.mode : "off")
    }

    function mute(): string {
      root.muted = !root.muted
      return root.muted ? "mudo" : "hablando"
    }

    function state(): string {
      return JSON.stringify({
        barPosition: root.barPosition,
        barSize: root.barSize,
        barHidden: root.barHidden,
        focusedScreen: root.focusedScreenName,
        pose: root.poseId,
        pos: Math.round(mover.pos),
        moving: mover.moving,
        canMove: mover.canMove,
        facingLeft: mover.facingLeft,
        settings: root.settings,
        widget: root.widget !== null
      })
    }

    function geometry(): string {
      var g = root.barGeometry()
      return g ? JSON.stringify(g) : "null"
    }
  }

  // ---- arranque ----------------------------------------------------------
  Component.onCompleted: {
    // Acá `shell` todavía es null. Todo lo que dependa del host va diferido.
    root.log("servicio creado")
    Qt.callLater(function () {
      root.log("shell=" + (root.shell ? "ok" : "null")
             + " barConfig=" + (root.shell && root.shell.barConfig ? "ok" : "null")
             + " barSize=" + root.barSize
             + " position=" + root.barPosition)
      root.log("settings iniciales: " + JSON.stringify(root.settings))

      stateFile.reload()
      pomoFile.reload()
    })
  }
}
