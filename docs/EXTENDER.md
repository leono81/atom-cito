# Extender Atom

Recetas para agregarle cosas sin romper nada. La promesa del proyecto es que
cada una de estas es **un archivo nuevo y una línea de registro** — si alguna
te obliga a editar el núcleo, es un bug de arquitectura, no tuyo (ver §6).

Antes de empezar: `ARQUITECTURA.md` explica el porqué de estas formas.

---

## 0. El ciclo de trabajo

```bash
cd ~/Projects/atom          # el código vive acá, no en ~/.config
$EDITOR plugin/brain/Rules.js
omarchy-shell shell rescanPlugins      # ← obligatorio, ver abajo
```

**No hay recarga en caliente en este proyecto. Punto.** Dos cosas
independientes lo impiden, las dos verificadas:

1. El shell vigila `~/.config/omarchy/plugins/` con `inotifywait -m -r`, que
   **no atraviesa symlinks** — y nuestra instalación es un symlink al repo.
   Guardar en `~/Projects/atom` no dispara ningún evento.
2. Peor: **`rescanPlugins` tampoco recarga el código.** Re-instancia el
   servicio, pero desde el componente **cacheado**. La culpa es de
   `shell.qml:1470`, que hace
   `if (typeof Qt.clearComponentCache === "function") …` — y
   `Qt.clearComponentCache` no existe como función QML (es API C++ de
   `QQmlEngine`), así que el guard falla en silencio.

Entonces el ciclo real es:

```bash
$EDITOR plugin/brain/Rules.js
omarchy restart shell        # único modo de recoger cambios de código
```

Para automatizarlo:

```bash
# desde ~/Projects/atom
find plugin -type f | entr -s 'omarchy restart shell'
```

`rescanPlugins` sigue sirviendo para que el shell **descubra** un plugin nuevo
o note que cambió el `manifest.json`; para cambios de QML, no.

> Ojo: un restart —y también cualquier escritura de `shell.json`— recrea
> **todos** los plugins de terceros. Por eso los relojes se persisten
> (ARQUITECTURA §6).

Ver qué está pasando:

```bash
journalctl --user -f | grep -i atom    # los console.log del plugin
```

---

## 1. Que hable en una situación nueva

**Ejemplo: avisarte cuando llevás mucho rato sin commitear.**

Un archivo: `plugin/brain/Rules.js`. Agregás un objeto al array `RULES`:

```js
{
  id: "uncommitted",
  priority: 25,
  gapMinutes: 60,
  test: function (c) {
    return c.gitDirtyMinutes >= 90        // campo que aporta un sensor (§3)
  },
  intent: "Hace {gitDirtyMinutes} minutos que tiene cambios sin commitear en " +
          "{gitRepo}. Sugerile commitear, sin sonar a supervisor.",
  lines: [
    "Hace un rato largo que no commiteás. ¿Y si guardás lo que va?",
    "{gitRepo} tiene cambios sin commitear desde hace {gitDirtyMinutes} minutos.",
    "Commiteá aunque sea un WIP. Después te vas a agradecer."
  ]
}
```

Eso es todo. El motor la levanta sola.

**Los campos:**

| Campo | Qué hace |
|---|---|
| `id` | único; se usa para el cooldown propio |
| `priority` | cuando varias reglas aplican a la vez, gana la más alta |
| `gapMinutes` | mínimo entre dos disparos de **esta** regla |
| `test(ctx)` | función **pura**: contexto adentro, `true`/`false` afuera |
| `intent` | qué pedirle a Claude que escriba; admite `{placeholders}` del contexto |
| `lines[]` | banco local; se usa si Claude está apagado o falla |

**Probala sin levantar el shell** — para eso `Rules.js` no importa nada de QML:

```bash
cd ~/Projects/atom/plugin/brain
node -e '
  const src = require("fs").readFileSync("Rules.js","utf8").replace(".pragma library","");
  const m = {}; new Function("exports", src + ";Object.assign(exports,{RULES,pick,fallback})")(m);
  const ctx = { gitDirtyMinutes: 120, gitRepo: "atom", streakMinutes: 10,
                sessionMinutes: 20, hour: 15,
                cfg: { stretchMinutes: 45, marathonMinutes: 120, waterMinutes: 60 } };
  const r = m.pick(ctx, {}, Date.now());
  console.log(r.id, "→", m.fallback(r, ctx));
'
```

**Cuidado con las prioridades.** La ventana de silencio global (20 min) es
compartida: una regla nueva con prioridad alta le saca el turno a las demás.
Si la tuya no es más urgente que `marathon`, no le pongas más de 40.

---

## 2. Una pose o animación nueva

**Ejemplo: que se rasque.**

### a) El dibujo — `plugin/poses/Scratch.qml`

```qml
import QtQuick
import ".."
import "../parts"

AtomPose {
  poseId: "scratch"
  canMove: false           // rascándose no se traslada
  breathPeriod: 3000

  // El dibujo, en el mismo viewBox de 34×24 que el resto de las poses.
  // Las piezas compartidas son archivos en poses/parts/: Body.qml, Head.qml,
  // Ear.qml, Leg.qml, Tail.qml. Un archivo por tipo, porque en QML un tipo
  // usable como `Body { }` tiene que ser un Body.qml.
  Body   { }
  Head   { x: 24.8; y: 8 }
  Ear    { flapping: true }
  Leg    { id: hind; x: 10.4; pivotY: 15.4
           SequentialAnimation on rotation {
             loops: Animation.Infinite; running: root.active
             NumberAnimation { to: -38; duration: 140 }
             NumberAnimation { to: -22; duration: 140 }
           } }
}
```

### b) El registro — `plugin/poses/Poses.js`

```js
{ id: "scratch", file: "Scratch.qml" }
```

Listo. El renderer instancia todas las poses del registro y hace cross-fade;
no hay ningún lugar donde estén enumeradas a mano.

### c) Que la use alguien

Una pose que nadie invoca no se ve nunca. Dos formas:

**Desde el ocio** (`brain/Behavior.js`) — se rasca al ratito de sentarse:

```js
{ from: "sit", to: "scratch", afterMs: 9000, chance: 0.4 },
{ from: "scratch", to: "sit", afterMs: 1800 }
```

**Desde una regla** — una regla puede pedir una pose junto con la frase:

```js
{ id: "welcome", …, pose: "scratch" }
```

### Las reglas del dibujo

- **Mismo `viewBox`: `0 0 34 24`.** Piso en `y = 21`, perro mirando a la
  derecha. Si tu pose no respeta el piso, el perro va a flotar.
- **`canMove` es obligatorio.** Es la invariante de movimiento; sin declararlo
  la pose no valida.
- **Las animaciones se atan a `root.active`**, así las poses ocultas no gastan
  ciclos.
- **Nada de colores literales.** El color sale de `currentColor`, que viene
  del tema.
- **Las piezas compartidas viven en `poses/parts/*.qml`**, un archivo por
  pieza. Si tu pose necesita una cabeza distinta, agregá `HeadTilted.qml`
  antes de copiar y pegar el dibujo de la existente.
- **Si la pose se traslada, `canMove: true` — y hoy la única es `walk`.**
  Antes de crear una segunda, leé la invariante de movimiento
  ([`PERSONAJE.md`](PERSONAJE.md) §4): es un requisito del proyecto, no una
  convención.

---

## 3. Que sepa algo nuevo

**Ejemplo: que sepa si el repo tiene cambios sin commitear.**

### a) El sensor — `plugin/sensors/GitSensor.qml`

```qml
import QtQuick
import Quickshell.Io
import "."

AtomSensor {
  id: root
  sensorId: "git"

  property string repo: ""
  property int dirtyMinutes: 0

  // Los sensores que consultan el sistema lo hacen con su propio timer,
  // SIEMPRE con timeout y SIEMPRE asincrónico.
  Timer {
    interval: 60000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: if (!proc.running) proc.running = true
  }

  Process {
    id: proc
    command: ["timeout", "3", "bash", "-c",
              "cd \"$HOME/Projects\" && git status --porcelain 2>/dev/null | head -1"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.dirtyMinutes = text.trim() === "" ? 0 : root.dirtyMinutes + 1
    }
  }

  // Lo único que el resto del sistema ve.
  function contribute() {
    return { gitRepo: root.repo, gitDirtyMinutes: root.dirtyMinutes }
  }
}
```

### b) El registro — `plugin/sensors/Sensors.qml`

```qml
GitSensor { id: git }
// y agregarlo a la lista:
readonly property var all: [focus, idle, clock, git]
```

Ahora `ctx.gitDirtyMinutes` existe para cualquier regla.

### Las reglas de los sensores

- **`contribute()` no puede tirar excepción.** Si algo falla, devolvé `{}`.
  Un sensor roto no puede dejar mudo a Atom.
- **Nombres de campo con prefijo** (`gitRepo`, no `repo`): el contexto es
  plano y compartido, y dos sensores no pueden pelearse una clave.
- **Ningún subproceso sin `timeout`.** Compartimos proceso con la barra.
- **Nada de leer contenido de ventanas ni archivos del usuario.** Lo que el
  sensor ve, eventualmente puede salir hacia Claude: mirá la sección de
  privacidad del manifiesto antes de agregar un sensor nuevo.

---

## 4. Que hable distinto

**Ejemplo: una voz que usa un modelo local por `ollama`.**

`plugin/voice/OllamaVoice.qml`:

```qml
AtomVoice {
  voiceId: "ollama"
  priority: 5                       // entre LocalVoice (0) y ClaudeVoice (10)

  function available() {
    return root.cfg("useOllama", false) === true
  }

  function say(rule, ctx, done) {
    // done(texto) si salió; done(null) para pasarle el turno a la siguiente
  }
}
```

y registrarla en `voice/Voices.qml`. La cadena se recorre de mayor a menor
prioridad hasta que una entrega texto; `LocalVoice` está al final con
`available()` siempre verdadero, así que **nunca se queda sin respuesta**.

---

## 5. Otro comportamiento de ocio

`plugin/brain/Behavior.js` es una tabla, no una cascada de `if`:

```js
var IDLE = [
  { from: "walk",  to: "stand", when: "arrived" },
  { from: "stand", to: "sit",   afterMs: 6000 },
  { from: "sit",   to: "lie",   afterMs: 14000 },
  { from: "lie",   to: "sleep", when: "away" },
  { from: "*",     to: "stand", when: "speaking" }
]
```

"Que si está echado más de diez minutos se levante y camine a otro lado":

```js
{ from: "lie", to: "walk", afterMs: 600000 }
```

| Campo | Qué hace |
|---|---|
| `from` | pose de origen, o `"*"` para cualquiera |
| `to` | pose destino; tiene que existir en `poses/Poses.js`. **Apuntar a `walk` significa "arrancá un viaje"**: el servicio no la asigna como pose, elige un destino y va. Una fila así tiene que salir de una pose quieta |
| `afterMs` | tiempo en `from` antes de pasar |
| `when` | evento que lo dispara: `arrived`, `away`, `back`, `speaking`, `click` |
| `chance` | probabilidad 0–1; para que no sea siempre igual |

La tabla se evalúa en orden: la primera fila que aplica, gana.

---

## 6. Cuando ninguna receta alcanza

Si lo que querés agregar no entra en ninguna de las cinco, **no lo metas a la
fuerza en el núcleo**. Lo que hay que hacer es agregar un punto de extensión
nuevo, y eso tiene su propia receta:

1. Escribí el caso de uso concreto en un issue o en el roadmap del manifiesto.
2. Definí el contrato mínimo (¿qué recibe?, ¿qué devuelve?, ¿qué pasa si
   falla?).
3. Implementalo como **registro + interfaz**, igual que los otros cinco: una
   carpeta, un archivo base (`AtomLoQueSea.qml`), y una lista.
4. Documentalo acá con una receta.
5. Recién entonces, escribí la primera implementación.

El olor a evitar es un `if (id === "…")` en el núcleo. Si aparece uno, el
núcleo está aprendiendo algo que debería ser un dato.

---

## 7. Errores comunes

| Síntoma | Causa casi segura |
|---|---|
| El perro no aparece | El plugin no está habilitado: tiene que figurar en `plugins[]` de `shell.json` |
| Los cambios de código no se aplican | Es lo normal y hay dos causas: el watcher no atraviesa el symlink, y `rescanPlugins` recarga desde caché. Va `omarchy restart shell` |
| Desapareció el perro al sacar el ícono de la barra | Esperado: el entry del widget **es** lo que mantiene habilitado el plugin (ARQUITECTURA §2) |
| Se desliza estando sentado | Alguien llamó a `walkTo()` sin pasar por el `Mover`, o una pose nueva no declaró `canMove` |
| Habla dos veces seguidas | La regla nueva tiene `gapMinutes` muy bajo, o dos reglas distintas con la misma prioridad |
| Se para encima del reloj | `BarGeometry` cayó a la capa 3 (zonas por sección). Mirá el log; suele ser un cambio de internals de Omarchy |
| La barra se pone lenta | Algún sensor sin `timeout`, o una animación corriendo en una pose oculta |
| Se resetean los contadores | El servicio se recreó y no encontró `~/.local/state/atom/state.json` |
