# Arquitectura

Cómo está construido Atom y, sobre todo, **dónde se engancha lo nuevo**. Si
vas a agregar una funcionalidad, leé primero [`EXTENDER.md`](EXTENDER.md); este
documento explica el porqué de las formas que ese otro te pide seguir.

---

## 1. Dónde corre

Todo vive dentro del proceso `omarchy-shell`, un único Quickshell de larga
vida que hostea la barra, las notificaciones y los paneles. Atom es un
plugin de terceros en `~/.config/omarchy/plugins/leono.atom/`: una copia
de un tag, o un symlink al repo en modo dev (ver `deploy.sh`).

```
omarchy-shell (un proceso)
├── omarchy.bar          la barra
├── omarchy.notifications
├── …
└── leono.atom           ← nosotros
    ├── kind: service    singleton: cerebro + ventana propia
    └── kind: bar-widget opcional: presencia mínima en la barra
```

Consecuencias que condicionan todo el diseño:

- **Corremos sin sandbox en el proceso del shell.** Un loop infinito nuestro
  cuelga la barra del usuario. Nada de trabajo pesado en el hilo de QML.
- **El shell recarga código en caliente** al guardar cualquier archivo bajo
  `~/.config/omarchy/plugins/`. Eso implica que un servicio puede ser
  destruido y recreado en cualquier momento: el estado que importa se
  persiste (ver §6).
- **No usamos `keepLoaded: true`.** Evita la recarga en caliente del servicio,
  que es justo lo que hace tolerable desarrollar esto.

## 2. Por qué `service` y no `panel`

Atom necesita una ventana propia flotando sobre la barra. Hay dos caminos:

| Camino | Problema |
|---|---|
| `kind: "panel"` | Los paneles se cargan **cuando alguien los invoca**. Para un personaje permanente habría que garantizar que algo lo invoque en cada arranque. |
| `kind: "service"` + `PanelWindow` propia | El servicio de terceros se monta solo al estar habilitado, y crea sus propias ventanas layer-shell. |

Elegimos el segundo. El patrón está verificado en `nosignal.motion-wallpaper`,
que renderiza video en la capa de fondo exactamente así:

```qml
Variants {
  model: root.activeScreens
  PanelWindow {
    required property var modelData
    screen: modelData
    color: "transparent"
    WlrLayershell.namespace: "atom"
    WlrLayershell.layer: WlrLayer.Overlay        // Atom va encima de la barra
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore          // no reserva espacio
    mask: Region { x: dog.x; y: dog.y; width: dog.width; height: dog.height }
  }
}
```

**`mask` no es opcional: es lo que impide que Atom se coma los clicks de la
barra.** La ventana cubre todo el ancho de la pantalla; sin máscara, cada
click en el reloj o en el tray se lo traga el perro. `leono.bar-shadow` usa
`mask: Region {}` (región vacía = todo pasa) para exactamente esto.

La máscara se ata a un *hitbox* invisible que solo salta cuando el perro
**llega**, no al sprite animado. Efecto lateral buscado: mientras camina no es
clickeable.

Ese diseño se justifica por simplicidad y por hacer el input predecible —
**no por rendimiento**, como se creía al escribir este documento. Medido en la
Fase 0 ([SPIKES §U3](SPIKES.md)): reemitir la región de input por frame cuesta
menos del 3% del costo del frame. Lo caro es que la superficie tenga frames.
Ver §8.

`WlrLayer.Overlay` (nivel 3) queda por encima de la barra, que vive en
`WlrLayer.Top` (nivel 2) — verificado con `hyprctl layers`. En esa misma capa
vive `omarchy-keyboard-panel`, el desplegable de los widgets: dos superficies
de la misma capa se ordenan por creación, así que el z-order relativo entre
Atom y esos popups **no es determinista** y hay que probarlo.

`Variants` sobre `Quickshell.screens` nos da **una ventana por monitor** sin
escribir lógica de multi-monitor. Cuántos perros se dibujan en esas ventanas
es otra decisión, y está en §10.

### El bar-widget no es opcional

Atom declara `kinds: ["service", "bar-widget"]`, y el widget es estructural,
no decorativo. Dos razones, las dos descubiertas contra el código real:

1. **Es el único canal de configuración.** La fachada que recibe un plugin de
   terceros (`services/PluginShellApi.qml`) expone `barConfig`, `bar`,
   `idleConfig` y `appLibrary` — **no expone `shellConfig`**, así que un
   servicio no puede leer `plugins[]`. Los ajustes inline del entry sí llegan
   al `BarWidget` por su propiedad `settings`.
2. **Es el único que ve la barra.** Ver §7.

Consecuencia que hay que asumir y documentar: como el manifiesto declara un
kind de widget, el entry del plugin vive en `bar.layout.<sección>` y no en
`plugins[]` — y *"third-party enabled ⇔ present"*. **Sacar el ícono de la
barra deshabilita el plugin entero** y el perro desaparece. El widget se
dibuja como una huella mínima, pero tiene que existir.

`keyboardFocus: None` y `exclusionMode: Ignore` son los que garantizan el
principio *"nunca interrumpe"*: la ventana no toma foco de teclado ni empuja
el layout de las ventanas.

## 3. El flujo

```
  sensores            cerebro                    cuerpo
 ┌─────────┐       ┌──────────────┐        ┌────────────────┐
 │ Focus   │──┐    │ Rules.js     │        │ Mover          │ posición
 │ Idle    │──┼──► │ ¿hablar?     │──────► │ Atom.qml       │ pose
 │ Clock   │──┘    │              │        │ Bubble         │ texto
 └─────────┘       │ Behavior.js  │        └────────────────┘
      │            │ ¿qué pose?   │
      └─ contexto ►└──────────────┘
                          │
                          ▼
                    ┌──────────┐
                    │ Voice    │  LocalVoice │ ClaudeVoice
                    └──────────┘
```

Cinco piezas, cinco responsabilidades, cinco puntos de extensión. Cada una se
amplía sin tocar a las otras.

### Contexto

El **contexto** es el único vocabulario compartido: un objeto plano que los
sensores llenan y las reglas leen.

```js
{
  app: "herdr",            // etiqueta amigable de la ventana enfocada
  appId: "Alacritty",      // el appId crudo
  title: "herdr — ~/Projects/kenos",
  streakMinutes: 47,       // minutos seguidos en la misma app
  sessionMinutes: 112,     // minutos desde la última pausa real
  away: false,             // ¿está lejos del teclado ahora?
  awayMinutes: 0,          // cuánto duró la última ausencia
  justReturned: false,
  hour: 23, clock: "23:14",
  cfg: { …ajustes del usuario… }
}
```

Agregar un sensor agrega campos al contexto. Las reglas viejas siguen
funcionando porque leen solo los campos que les importan.

## 4. Los cinco puntos de extensión

| Quiero… | Toco | Y nada más |
|---|---|---|
| que diga algo en otra situación | `brain/Rules.js` | una entrada en el array |
| una pose o animación nueva | `poses/` + `poses/Poses.js` | un archivo y una línea |
| que sepa algo nuevo | `sensors/` + registro | un archivo y una línea |
| que hable distinto | `voice/` | un archivo y una línea |
| otro comportamiento de ocio | `brain/Behavior.js` | una fila de la tabla |

Las recetas concretas están en [`EXTENDER.md`](EXTENDER.md). Lo que sigue es
el contrato de cada una.

### 4.1 Reglas — *cuándo* hablar

```js
{
  id: "stretch",
  priority: 30,                       // gana la más alta cuando varias aplican
  gapMinutes: 30,                     // cooldown propio
  test: function (ctx) { … },         // pura: contexto adentro, bool afuera
  intent: "…{streak}… {app}…",        // qué pedirle a Claude que escriba
  lines: [ "…", "…" ]                 // banco local, con los mismos {placeholders}
}
```

`Rules.js` es **JavaScript puro, sin un solo import de QML**. Se corre con
`node` y se testea sin levantar el shell. Es la parte que más se va a tocar,
así que es la que más barato tiene que ser probar.

### 4.2 Poses — *cómo* se ve

Cada pose es un componente QML que se dibuja a sí mismo y declara sus reglas:

```qml
// poses/Sit.qml
AtomPose {
  poseId: "sit"
  canMove: false        // ← la invariante de movimiento, como dato
  breathPeriod: 3800
  // … el dibujo …
}
```

y una línea en el registro:

```js
// poses/Poses.js
{ id: "sit", file: "Sit.qml" }
```

`Atom.qml` (el renderer) carga el registro, instancia todas las poses y hace
cross-fade entre ellas. **No conoce ninguna pose por nombre**: agregar una no
lo modifica.

> **La invariante de movimiento vive acá.** `canMove` es un dato de la pose, no
> un `if` en el que mueve. El `Mover` consulta la pose activa y se niega a
> trasladar si `canMove === false`. Una pose nueva hereda la garantía sin que
> su autor tenga que acordarse.
>
> Hoy **`walk` es la única pose con `canMove: true`** — `stand` incluido vale
> `false`. `walk` es una entrada propia del registro que reusa las piezas de
> `stand`; no es "stand con las patas moviéndose". Si fueran la misma pose,
> el dato que implementa la invariante valdría `true` estando quieto y la
> garantía sería falsa.

### 4.3 Sensores — *qué* sabe

```qml
// sensors/FocusSensor.qml
AtomSensor {
  sensorId: "focus"
  function contribute() {
    return { appId: …, title: …, app: … }
  }
}
```

El agregador llama a `contribute()` de cada sensor registrado y hace merge en
el contexto. Un sensor que falla devuelve `{}` y el resto sigue andando.

### 4.4 Voces — *cómo* lo dice

```qml
// voice/ClaudeVoice.qml
AtomVoice {
  voiceId: "claude"
  priority: 10                        // se intenta antes que las de menor prioridad
  function available() { … }          // ¿hay `claude` en el PATH? ¿está activado?
  function say(rule, ctx, done) { … } // done(texto) o done(null) para pasar a la siguiente
}
```

La cadena de voces se recorre por prioridad hasta que una entrega texto.
`LocalVoice` tiene prioridad 0 y `available()` siempre verdadero, así que la
cadena **nunca queda sin respuesta**. Ese es el principio "degrada bien",
hecho estructura.

### 4.5 Comportamiento de ocio — *qué pose cuándo*

Una tabla declarativa, no una cascada de `if`:

```js
// brain/Behavior.js
var IDLE = [
  // Las interrupciones van PRIMERO: gana la primera fila que aplica, y si
  // "speaking" quedara abajo, un perro sentado hace 14 s se acostaría justo
  // en el momento en que tiene algo que decirte.
  { from: "*",     to: "stand", when: "speaking" },
  { from: "*",     to: "stand", when: "back" },
  { from: "*",     to: "stand", when: "click" },

  { from: "walk",  to: "stand", when: "arrived" },
  { from: "stand", to: "sit",   afterMs: 6000 },
  { from: "sit",   to: "lie",   afterMs: 14000 },
  { from: "lie",   to: "sleep", when: "away" }
]
```

Agregar "si está echado y pasan 10 minutos, que se levante a caminar" es
agregar una fila.

## 5. La invariante de movimiento

La regla dura del proyecto:

> **`x` solo cambia mientras la pose activa tiene `canMove: true`.**

Implementación:

```qml
// Mover.qml
function walkTo(targetX) {
  if (!pose.canMove) return false      // se niega, no "corrige después"
  anim.from = root.x; anim.to = targetX; anim.start()
  return true
}
function freeze() {
  anim.stop()                          // QML deja x en el valor actual
}
```

y **todo** cambio de pose llama a `freeze()` primero. Un perro sentado no se
desliza ni aunque le pidan que se mueva: la petición se rechaza en el borde,
no se compensa después.

## 6. Estado y persistencia

| Estado | Dónde vive | Sobrevive a |
|---|---|---|
| pose actual, `x` | en memoria | nada (se recalcula) |
| relojes (`streak`, `session`) | `~/.local/state/atom/state.json` | recarga en caliente y reinicio del shell |
| últimas frases dichas | `~/.local/state/atom/history.jsonl` | todo |
| ajustes del usuario | `~/.config/omarchy/shell.json`, entrada del widget en `bar.layout` | todo |

Los ajustes llegan por dos caminos, en este orden:

1. **El `BarWidget`**, que recibe su entry inline en `settings` y se lo pasa
   al servicio por `shell.serviceFor("leono.atom")`. Es el camino normal.
2. **`shell.barConfig` desde el propio servicio**, que sí contiene la entrada
   del plugin con sus ajustes inline (verificado en la Fase 0). Sirve como
   respaldo y para arrancar antes de que el widget se monte.

Ni `settings` ni `shell` están disponibles dentro de `Component.onCompleted`:
llegan en el mismo giro del event loop, así que se leen desde un
`Qt.callLater`. Y como **cualquier escritura de `shell.json` destruye y recrea
servicio y widget**, `registerWidget()` tiene que ser idempotente.

Un servicio de terceros **no puede** leer `plugins[]`: su fachada no expone
`shellConfig` (ver §2). Cualquier código que haga `shell.shellConfig` está
leyendo `undefined` en silencio.

Los relojes se persisten **porque el shell recarga el servicio al guardar
cualquier archivo** — y recarga *todos* los servicios de terceros, no solo el
que tocaste: sin eso, tocar una coma durante el desarrollo reiniciaría
los contadores, y en uso normal un `omarchy update` te borraría la sesión.

Se escribe con throttle (a lo sumo una vez por minuto) para no castigar el
disco.

## 7. Geometría de la barra

Atom necesita saber dónde **no** pararse. Este es el punto más frágil del
diseño, porque la barra no expone su geometría interna como API pública.

Estrategia en capas, de mejor a peor, con degradación automática:

1. **Medir los widgets vivos — desde el `BarWidget`, nunca desde el servicio.**
   El servicio de terceros se crea con `parent: null` a propósito
   (`shell.qml`: *"third-party services have no visual parent"*), así que no
   tiene ningún camino hacia la barra. El widget sí: trepa por `parent` hasta
   el root de la ventana de la barra y baja recogiendo todo lo que tenga
   `moduleName`, con `mapToItem`. **Verificado en la Fase 0**: devuelve los 17
   slots con id, sección y rectángulos exactos.
2. ~~Estimar desde `barConfig`~~ — **descartada**. No aporta nada que la capa
   1 no dé mejor, y no resuelve R10: `barConfig` no cambia cuando un widget
   cambia de ancho, y se vio a `omarchy.indicators` pasar de 21 px a 126 px
   entre dos mediciones.
3. **Zonas fijas por sección.** `left`, `center` y `right` como tres bloques,
   caminando solo entre ellos. Es el piso: siempre funciona.

`BarGeometry.qml` prueba (1), valida el resultado y cae a (3) si no cierra.

La capa 1 **no usa ninguna API privada**: solo `parent`, `children`,
`mapToItem` y la convención de que un slot tiene `moduleName`, que es parte
del contrato público documentado de `BarWidget`. `bar.moduleWidgets()` sí está
acotado al propio módulo y es una pared; el árbol visual la rodea.

Tres reglas obligatorias, sacadas de la medición real:

- **Filtrar por `w > 0`, no por `visible`**: `tray`, `keyboard-layout` y
  `system-update` están montados con ancho cero.
- **Re-medir en cada tick, nunca cachear.**
- Todo en `try/catch`; ante cualquier excepción, `null` → capa 3.

El cálculo en sí es una función pura y testeable:

```js
// Geometry.js
restStops(barWidth, obstacles, dogWidth) → [x, x, x]
```

## 8. Rendimiento

Compartimos proceso con la barra del usuario, y la Fase 0 midió cuánto cuesta
de verdad una superficie animada en esta máquina:

| Estado de la superficie | CPU del shell |
|---|---|
| quieta | **0.02 %** |
| animada a 60 fps | **~16 %** de un core |

**El enemigo es el frame rate, no la lógica.** Da igual si lo que se anima son
píxeles o la máscara de input: cualquier animación QML pide un frame.

De ahí el presupuesto:

- **El perro quieto no dibuja frames.** Respiración y parpadeo son eventos
  raros y baratos, no una animación continua: la respiración puede correr a
  paso lento y el parpadeo dura 130 ms cada varios segundos.
- **Caminar es el único momento caro**, y es el más corto. Evaluar 30 fps para
  la caminata antes de asumir 60.
- **Sin animaciones cuando no se ven**: dormido, monitor sin foco o barra
  oculta paran todo. Esto **no es pulido, es necesario**.
- **Un timer de 15 s** para reevaluar reglas. Nada de polling más rápido.
- **Cero trabajo en `onPaint`**: el perro son elementos QML, no un `Canvas`.
- **Subprocesos siempre con `timeout`**, nunca sincrónicos.

### La latencia de `claude -p` obliga a anticipar

Medido con el prompt real de Atom y **haiku**: 12 a 81 segundos, mediana ~27.
Con **`claude-sonnet-5`**, que es el modelo que quedó por defecto: **4 a 12
segundos** en cuatro muestras. El modelo chico resultó ser el lento, lo que
sugiere que aquello fue una ventana mala del servicio y no el tamaño del
prompt.

Igual la anticipación se queda: 12 segundos de globo en blanco también son
demasiados, y no cuesta nada tenerla.

Un globo que aparece 30 s tarde no sirve. Pero las reglas son **predecibles**:
a los 40 minutos ya sabemos que `stretch` va a disparar a los 45. Entonces la
voz se pide **por adelantado** — unos minutos antes de que la regla cumpla su
condición — y se guarda la frase. Cuando la regla dispara, el texto ya está.

Si no llegó, habla el banco local, que es instantáneo. La anticipación es una
optimización, nunca un requisito.

## 9. Un perro, muchas pantallas

`Variants` crea una ventana por monitor, pero **el cerebro es uno solo**: un
`x`, una pose, un ciclo de ocio, una ventana de silencio. Si se dibujara el
perro en todas las ventanas, o bien se clona y se mueve sincronizado — y los
huecos de un monitor de 1366 px no son los de uno de 2560, con lo que
acertaría en uno y quedaría encima del reloj en el otro — o bien hacen falta
N cerebros y la ventana de silencio se multiplica por pantalla.

**Decisión: un solo perro, en el monitor que tiene el foco.** Las demás
ventanas existen pero se dibujan vacías. Cuando el foco cambia de pantalla,
Atom aparece en la nueva (y la transición es un detalle a resolver: por ahora,
aparece parado en el hueco más cercano al borde por el que "entró").

Si en el futuro se quiere un perro por pantalla, lo que hay que partir es el
estado de cuerpo (`x` + pose), no el cerebro: las reglas y la ventana de
silencio siguen siendo una sola.

### Mapear una vez y no desmapear nunca

Regla dura, de la Fase 0. Los desplegables de la barra son `PanelWindow` de
pantalla completa en la misma capa Overlay, y dentro de una capa el orden lo
fija el **momento de mapeo**. Atom mapea al arrancar, así que todo popup
posterior queda encima — que es lo correcto.

Cualquier `visible: false` desmapea la superficie, y al volver se reinserta
**arriba de todo**, tapando popups y notificaciones. Para esconder al perro
—barra oculta, monitor sin foco, silenciado— se toca **opacidad y máscara,
jamás `visible`**. Además es ~7× más barato: el bar de Omarchy documenta
150 ms contra 20 ms.

Efecto colateral aceptado: mientras un desplegable está abierto se come todo
el input de la pantalla. El perro se ve pero no es clickeable.

### Estados de la barra que hay que contemplar

Todo sale de `shell.bar`, que expone **`position`, `barSize`, `barHidden` y
`fontFamily`** con bindings vivos, sin capability especial. No hace falta
vigilar ningún archivo de estado.

- **`position`** puede ser `top`, `bottom`, `left` o `right`: se anclan los
  **tres** lados que corresponden (el de la barra más los dos perpendiculares)
  y el `implicit*` del eje libre va en 0, igual que `Bar.qml`.
- **`exclusionMode: ExclusionMode.Ignore`.** La técnica de `bar-shadow`
  (`Normal` + `exclusiveZone: 0`) significa "respeto lo que reservan los
  demás" y el compositor te parkea **debajo** de la barra — perfecto para una
  sombra, exactamente lo contrario para Atom.
- **Barra oculta**: `shell.bar.barHidden`. Atom se esconde con opacidad, no
  desmapeando.
- **Defenderse de `barSize == 0`**: `shell.bar` queda en `null` mientras el
  Loader del bar se recarga.

## 10. Qué NO hace el núcleo

Para que los puntos de extensión sigan siendo puntos de extensión:

- El renderer **no conoce poses por nombre**.
- El cerebro **no conoce reglas por nombre** (salvo `ondemand`, que es la
  respuesta al click y está documentada como tal).
- Las reglas **no conocen sensores**: leen campos del contexto.
- Las voces **no conocen reglas**: reciben `intent` y `ctx`.
- Nada fuera de `sensors/` habla con Wayland, Hyprland ni el sistema.

Si al agregar algo aparece un `if (id === "…")` en el núcleo, la extensión
está mal planteada — o falta un punto de extensión, que es una conversación
legítima y está documentada en [`EXTENDER.md`](EXTENDER.md) §6.
