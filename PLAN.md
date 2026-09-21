# Plan de implementación

**Estado: v7 — las diez fases completadas.** La v1 está entera. Los seis spikes están resueltos en
[docs/SPIKES.md](docs/SPIKES.md); sus hallazgos ya están incorporados acá y en
la arquitectura. **La Fase 1 puede arrancar.**

**Revisado adversarialmente.** Los hallazgos y su resolución
están en [docs/RED-TEAM.md](docs/RED-TEAM.md). Dos supuestos que la v1 daba
por verificados eran falsos, y tres riesgos centrales no estaban listados;
este documento ya los incorpora.

El *qué* y el *por qué* están en [MANIFIESTO.md](MANIFIESTO.md); el *cómo*
estructural, en [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md).

---

## 1. Criterio de terminado

La v1 está lista cuando, en la máquina del usuario:

1. Atom aparece en la barra al arrancar la sesión, sin intervención.
2. Camina, se sienta, se acuesta y duerme siguiendo el ciclo de ocio.
3. **Nunca se traslada si no está en la pose `walk`.**
4. **Nunca queda detenido encima de un widget** — incluso cuando el hueco se
   invalida solo porque el reloj cambió de ancho.
5. A los 45 minutos en la misma app, habla — con Claude si está disponible,
   con el banco local si no, y **sin llaves literales en la frase**.
6. Nunca habla dos veces dentro de la ventana de silencio.
7. No roba foco de teclado ni se come clicks de la barra, nunca.
8. Sobrevive a `omarchy-shell shell rescanPlugins` sin perder los relojes.
9. **La prueba de extensibilidad (§6) pasa.**

Todo lo que no esté en esa lista es v2.

## 2. Supuestos

### Verificados contra el código real

| Supuesto | Evidencia |
|---|---|
| El shell descubre plugins a través de un symlink | `listPlugins` devuelve `leono.atom`; el scan itera `for sub in "$dir"/*/` |
| Un `service` de terceros se monta al estar habilitado | `nosignal.motion-wallpaper` y `leono.bar-shadow` corren así |
| Un `service` puede crear `PanelWindow` layer-shell propias | `motion-wallpaper/Service.qml:527`, `Variants` sobre `Quickshell.screens` |
| `Variants` + `Quickshell.screens` es API vigente en quickshell 0.3.1 | `quickshell-core.qmltypes:943`, y la usan los dos plugins instalados |
| Una ventana `Overlay` queda por encima de la barra | `hyprctl layers`: `omarchy-bar` está en `Top` (nivel 2); Overlay es el 3 |
| Existe máscara de input (`mask: Region`) para dejar pasar clicks | `quickshell-window.qmltypes:367`; `leono.bar-shadow` la usa |
| Un plugin de terceros puede registrar su propio target IPC | `omarchy-shell motion-wallpaper ping` → `ok` |
| El tema es accesible con `import qs.Commons` | `motion-wallpaper/BarWidget.qml` usa `Color.accent` |
| `claude -p --model haiku` responde en 3–5 s | Medido, dos corridas |
| **La fachada de terceros NO expone `shellConfig`** | `services/PluginShellApi.qml:13-28`: hay `barConfig`, no `shellConfig` |
| **Un `service` de terceros se crea con `parent: null`** | `shell.qml:923`, con comentario explícito: frontera de seguridad |
| **Con un kind `bar-widget`, el entry va a `bar.layout`, no a `plugins[]`** | `shell.json`: `motion-wallpaper` está en `bar.layout.right`; `bar-shadow` (service puro) en `plugins[]` |
| **El watcher `inotifywait -m -r` NO atraviesa symlinks** | Probado en aislado: 0 eventos al escribir del otro lado del symlink |
| `IdleMonitor` da **un booleano por umbral**, no segundos, y mide teclado **y** puntero | `_IdleNotify/*.qmltypes`: solo `enabled`, `timeout`, `respectInhibitors`, `isIdle` |

Las cuatro últimas en negrita son las que la v1 de este plan tenía mal — dos
como "verificadas" siendo falsas, dos sin listar.

### Sin verificar — los resuelve la Fase 0

| # | Pregunta | Respuesta (Fase 0) |
|---|---|---|
| U1 | ¿Se llega a los rectángulos de los widgets desde el `BarWidget`? | **Sí**, los 17 slots con id, sección y rects exactos. Capa 2 descartada |
| U2 | ¿Es estable el z-order contra los desplegables? | **Sí**: mapean después, siempre ganan. R12 mitigado gratis |
| U3 | ¿Cuánto cuesta recalcular la máscara? | **Nada relevante**: el costo es el frame rate (~16 % de un core a 60 fps) |
| U4 | ¿Posiciones de barra y `bar-off`? | `ExclusionMode.Ignore` (**no** `Normal`+0) y `shell.bar` con bindings vivos |
| U5 | ¿Monitor con foco? | `Hyprland.focusedMonitor.name`, sin tocar `visible` |
| U6 | ¿Cuándo llega la config? | Post-`Component.onCompleted`; el servicio además la lee de `shell.barConfig` |

Tres hallazgos que no estaban en ninguna lista y cambian el plan:

- **`rescanPlugins` no recarga código QML** (`Qt.clearComponentCache` no existe
  como función QML: `shell.qml:1470` es un no-op silencioso). El ciclo de
  desarrollo es `omarchy restart shell`.
- **Cualquier escritura de `shell.json` destruye y recrea servicio y widget.**
  R6 es más amplio de lo escrito; `registerWidget()` tiene que ser idempotente.
- **Una superficie animada a 60 fps cuesta ~16 % de un core**, quieta 0.02 %.
  Pausar animaciones deja de ser pulido.

Queda **una sola cosa pendiente de confirmación humana**: que un click
atraviese la ventana. No se pudo automatizar (`hyprctl eval` inyecta clicks a
superficies Overlay propias pero no llega a las `Top` de la barra; `ydotool` no
está instalado). Son 10 segundos en la Fase 1, con el procedimiento exacto en
[SPIKES §U3](docs/SPIKES.md).

## 3. Fases

Cada fase termina en algo que se puede ver funcionando.

---

### Fase 0 · Spikes — ✅ COMPLETADA

Resultados en [docs/SPIKES.md](docs/SPIKES.md). El código descartable quedó en
`spikes/plugin/` como registro; el plugin `leono.atomspike` se desinstaló y el
sistema se verificó limpio (`shell.json` byte a byte idéntico).

<details><summary>Lo que pedía originalmente</summary>

**Construye:** código desechable en `spikes/`, no producto.

- **U1 — geometría:** un `BarWidget.qml` mínimo que trepe por `parent` hasta
  el panel de la barra, mapee los rectángulos de sus hermanos y los loguee.
  Decide qué capa de `BarGeometry` se implementa primero.
- **U2 — z-order:** abrir el desplegable del audio con el perro al lado y ver
  quién tapa a quién. Repetir después de un `rescanPlugins`.
- **U3 — máscara:** ventana con `mask: Region` atada a un item animado contra
  máscara estática; comparar el costo (ver §8 para cómo se mide).
- **U4 — posiciones:** `omarchy bar set position bottom` y ver dónde queda la
  ventana. Probar el toggle `bar-off`.
- **U5 — monitor con foco:** ver si `ToplevelManager.activeToplevel` permite
  deducir la pantalla.
- **U6 — config:** loguear en qué frame llega `settings` al widget y cuándo
  lo recibe el servicio vía `shell.serviceFor()`.

**Acepta cuando:** existe `docs/SPIKES.md` con las seis respuestas y, para
U1, cuál capa se implementa.

</details>

---

### Fase 1 · Esqueleto — ✅ COMPLETADA

Verificado en vivo el 2026-09-21: superficie `atom` en la capa overlay
(`0 0 1366 146`), `reserved` sin cambios, IPC propio (`ping`/`state`/`moveTo`/
`geometry`) respondiendo, y **click-through confirmado por el usuario en los
dos sentidos**: el click sobre el reloj lo atraviesa y abre el calendario, y
el click sobre el perro lo recibe Atom (6 clicks en el log) sin tocar el reloj.
**R1 cerrado.**

Dos bugs de arranque encontrados y corregidos: el widget pisaba con `{}` la
config que el servicio ya había leído de `barConfig`, y el primer parche
(ignorar empujones vacíos) no distinguía "todavía no llegó" de "lo vaciaste a
propósito". La config ahora sale **solo** de `shell.barConfig`.

Adelanto verificado de la Fase 5: `omarchy-shell atom geometry` devuelve los
14 slots vivos de la barra real. Huecos actuales: **147→604** y **762→1126**.

<details><summary>Lo que pedía originalmente</summary>

**Construye:** `manifest.json` (revisado), `Service.qml`, `BarWidget.qml`
**real aunque mínimo**, una `PanelWindow` por monitor con un rectángulo de
28×20 px sobre la barra, `mask` estática, y el canal de config
widget → servicio.

> `BarWidget.qml` entra acá y no "más adelante": el manifiesto ya declara el
> entry point, y `validateManifest` **no comprueba que el archivo exista**, así
> que sin él la barra intenta cargar un componente fantasma desde el primer
> día.

**Acepta cuando:**
- Aparece al habilitar el plugin (la primera vez alcanza `rescanPlugins`;
  para cambios de código posteriores va `omarchy restart shell`).
- `hyprctl layers` muestra la superficie con el namespace `atom` en la capa
  overlay, y `hyprctl monitors` **no** muestra cambios en `reserved`.
- **Confirmación humana de 10 s** ([SPIKES §U3](docs/SPIKES.md)): un click
  sobre el reloj *a través* de la ventana lo hace cambiar de formato, y un
  click sobre el perro lo activa a él sin tocar el reloj.
- Se puede escribir en una terminal con el rectángulo encima sin perder
  teclas.
- El servicio loguea los valores de config, leídos desde `Qt.callLater` — no
  desde `Component.onCompleted`, donde `settings` y `shell` todavía están
  vacíos.
- La ventana se mapea una sola vez: ningún camino del código toca `visible`.

</details>

---

### Fase 2 · El perro, quieto — ✅ COMPLETADA

Renderer (`Atom.qml`), piezas en `poses/parts/`, `Stand.qml`, y las constantes
del dibujo en `poses/Geometry.js` con 60 aserciones contra la tabla de la
spec. El color entra por propiedad (`inkColor` ← `bar.foreground`, binding
vivo) — verificado por construcción, no por experimento.

Implementarlo corrigió tres números de `PERSONAJE.md` §2: el viewBox no entra
exacto en 28×20, el piso `y=21` es conceptual, y la respiración es invisible a
tamaño real. **Decisión tomada: `idleFps: 0` en la barra** — 0.29 px de
movimiento no justifican 2.4 puntos de CPU permanentes.

<details><summary>Lo que pedía originalmente</summary>

**Construye:** `Atom.qml` (renderer), `poses/parts/{Body,Head,Ear,Leg,Tail}.qml`,
`poses/AtomPose.qml`, `poses/Stand.qml`, `poses/Poses.js`,
`poses/Geometry.js` (las constantes del dibujo).

**Acepta cuando:**
- Se ve el perro de [`PERSONAJE.md`](docs/PERSONAJE.md) §2, a 28×20.
- Respira y parpadea.
- Cambia de color al correr `omarchy theme set <otro>`, sin reiniciar.
- `node` valida `Geometry.js` contra la tabla de la spec: las coordenadas
  viven en un solo lugar y se testean, en vez de compararse a ojo.

</details>

---

### Fase 3 · Las poses — ✅ COMPLETADA

Las cinco (`stand`, `walk`, `sit`, `lie`, `sleep`) con cross-fade y el IPC
`atom pose <id>`. **`walk` es una pose propia del registro**, no "stand con
las patas animadas" — que era el error que el red team encontró en el papel.

Criterio verificado: `grep -nE '"(stand|walk|sit|lie|sleep)"' Atom.qml
Mover.qml` no devuelve nada. El servicio nombra dos (`restPose` y
`movingPose`, una constante cada una) porque orquestar necesita saber cuál es
la de reposo y cuál la que se traslada; el renderer y el Mover, ninguna.

<details><summary>Lo que pedía originalmente</summary>

**Construye:** `Walk.qml`, `Sit.qml`, `Lie.qml`, `Sleep.qml`, cross-fade en el
renderer, `IpcHandler { target: "atom" }` con `pose <id>`.

**Acepta cuando:**
- `omarchy-shell atom pose sit` (y las demás, `walk` incluida) cambian la
  pose con fundido.
- El núcleo no menciona ninguna pose por nombre:
  `grep -nEo "\"(stand|walk|sit|lie|sleep)\"" Atom.qml Service.qml Mover.qml`
  no devuelve nada — ids leídos del registro, todos los archivos del núcleo,
  no solo `Atom.qml`.
- Agregar una pose de prueba al registro la hace invocable sin tocar el
  renderer.

</details>

---

### Fase 4 · Movimiento y su invariante — ✅ COMPLETADA

`Mover.qml` con las dos defensas estructurales: `walkTo()` se niega si la pose
activa no se traslada, y `onPoseChanged` congela solo — el freeze no lo
dispara el que llama, lo dispara el cambio.

Criterio verificado **sobre el registro entero**, como exigió el red team:

```
$ omarchy-shell atom invariant
stand=quieto · walk=SE MUEVE · sit=quieto · lie=quieto · sleep=quieto
```

<details><summary>Lo que pedía originalmente</summary>

**Construye:** `Mover.qml`, volteo (`scaleX(-1)`) al ir hacia la izquierda.

**Acepta cuando:**
- Camina de punta a punta con las patas animadas.
- **Para toda pose del registro que no sea `walk` — `stand` incluida —
  `walkTo()` devuelve `false` y `x` no cambia.** Se prueba iterando el
  registro, no con una pose elegida a mano.
- Cambiar de pose a mitad de camino **congela** la posición en el acto.
- A mano: `atom pose sit` mientras camina → se sienta y se queda donde
  estaba, sin deslizarse.

</details>

---

### Fase 5 · Los huecos — ✅ COMPLETADA

`brain/Gaps.js` (35 aserciones en node, incluidos los 17 rectángulos reales de
la barra del usuario) más la medición viva desde el `BarWidget`. En caliente:
el perro camina solo entre los huecos y nunca se detiene sobre un widget.

R10 resuelto y observado en el log: cuando el hueco activo se invalida —el
reloj cambia de ancho cada minuto— **se levanta y camina**, nunca se recoloca
sentado.

<details><summary>Lo que pedía originalmente</summary>

**Construye:** `BarGeometry.qml` (capas según la Fase 0) y `Geometry.js`
(`restStops()`, función pura).

**Acepta cuando:**
- `node` corre los tests de `restStops()`: barra vacía, barra llena, un solo
  hueco, huecos más chicos que el perro, widgets pegados.
- En vivo, después de 20 paradas, ninguna quedó encima de un widget.
- **Con el reloj en `dddd HH:mm`, se observa un cambio de minuto y de día que
  invalide el hueco activo: Atom se levanta, camina y se sienta en otro —
  nunca se recoloca sentado.**
- Mover un widget con `omarchy bar move` cambia los lugares de descanso sin
  reiniciar.
- Si no hay hueco válido, se queda parado donde está.

</details>

---

### Fase 6 · Sensores, relojes y contexto — ✅ COMPLETADA

`sensors/` con el tipo base y tres sensores (foco, inactividad, reloj) más el
agregador. `Clocks.js` cableado a `IdleMonitor` y a `ToplevelManager`.
Persistencia en `~/.local/state/atom/state.json`, verificada sobreviviendo a
dos reinicios seguidos con la racha y la sesión intactas.

La identidad de la racha es la **etiqueta**, no el `appId`: "Alacritty" no
dice nada y "herdr" lo dice todo.

Cuatro bugs de integración, todos encontrados corriendo:

- `readonly property alias focus:` **hacía que el tipo entero no cargara** —
  `focus` es propiedad FINAL de `Item`.
- El `Process` que crea el directorio de estado nunca corría: sin
  `running: true` un `Process` se queda quieto para siempre.
- `persist()` estaba condicionado a `dirty`, así que el archivo no se creaba
  nunca hasta que algo cambiara.
- **Sembrar la racha antes de restaurar** pisaba la sesión del usuario en el
  primer guardado. Ahora restaurar va primero, con un guard porque
  `FileView.onLoaded` puede disparar más de una vez.

<details><summary>Lo que pedía originalmente</summary>

**Construye:** `sensors/AtomSensor.qml`, `FocusSensor`, `IdleSensor`,
`ClockSensor`, `Sensors.qml`, persistencia en `~/.local/state/atom/state.json`.

> `IdleMonitor` solo avisa cuando se cruza un umbral. `awayMinutes` se
> cronometra desde las transiciones de `isIdle`, no se lee de ningún lado. Y
> como mide teclado **y** puntero, la spec dice "3 min sin teclado" pero lo
> que se implementa es "3 min sin input": la documentación se corrige, no el
> código.

**Acepta cuando:**
- La racha cuenta bien: 5 min en una app, alt-tab de 30 s, vuelta → sigue
  contando.
- Un alt-tab de más de 90 s sí cambia la racha de app.
- 3 min sin input reinician la sesión y marcan `justReturned`.
- `rescanPlugins` no pierde los contadores.
- El sensor de foco reporta `herdr` cuando la terminal tiene ese título.

</details>

---

### Fase 7 · Hablar — ✅ COMPLETADA

`voice/Voice.qml` (cadena Claude → banco local), `Bubble.qml`, la ventana de
silencio global y la **anticipación**: la frase se pide unos minutos antes de
que la regla cumpla su condición, porque `claude -p` tarda de 12 a 81
segundos y pedirla en el momento llega tarde siempre.

Verificado en vivo, con frases reales de Claude:

> *Tomá agua, que a medianoche la terminal no es tu aliada*
> *Levantate, salí del cuarto, andá a caminar, que a medianoche pegado no suma nada*

Y la degradación, también en vivo: cuando una llamada pasó los 45 s, habló el
banco local al instante. Es el comportamiento diseñado, y con estas latencias
va a pasar seguido.

El globo **no entra en la máscara de input**: es informativo, y un click
encima pasa de largo a lo que haya abajo. Es la forma más barata de cumplir
"nunca interrumpe".

IPC para no esperar 45 minutos: `atom say <regla>`, `atom context`,
`atom mute`. `say` devuelve `queued` al instante — el CLI corta a los 2 s y
Claude tarda treinta.

<details><summary>Lo que pedía originalmente</summary>

**Construye:** `brain/Rules.js` (migrar), `voice/AtomVoice.qml`, `LocalVoice`,
`ClaudeVoice`, `voice/atom-say`, el globo.

> El globo es **una segunda superficie layer-shell**, con su propia máscara y
> su propio z-order. Su andamiaje se diseña junto con la ventana principal en
> la Fase 1, no se improvisa acá.

**Acepta cuando:**
- Con los umbrales bajados a 1 minuto, dispara `stretch` y muestra el globo.
- **Ninguna frase ni ningún `intent` contienen `{` después de renderizar** —
  verificado con `node` sobre las seis reglas.
- Con `useClaude: false`, dice una frase local.
- Con `claude` fuera del PATH, cae a local sin quedarse mudo ni tirar error
  visible.
- Respeta la ventana de silencio.
- Se puede seguir escribiendo con el globo abierto.
- `atom-say` nunca corre sin `timeout`.
- **`omarchy-shell atom say <regla>` devuelve al toque** (`queued`) y el texto
  sale por el globo: el CLI corta a los 2 s y Claude tarda 3–5, así que el
  handler IPC no puede esperar la respuesta.

</details>

---

### Fase 8 · Comportamiento de ocio e interacción — ✅ COMPLETADA

Los tres clicks (izquierdo pide un comentario, derecho silencia, medio
reinicia los relojes), el hover con los dos relojes, y el silenciado con su
propio color del tema.

**Un solo globo para dos usos**, y hablar le gana al hover: si Atom tiene algo
que decirte, no se lo tapa un dato que podés mirar cuando quieras.

Verificado moviendo el cursor por IPC de Hyprland: el globo de hover apareció
con `la terminal · 4 min · sesión 4 min`. Los clicks sintéticos resultaron
poco confiables —llegan a las superficies Overlay propias pero no siempre— así
que la lógica se probó por IPC (`atom mute` alterna y el perro cambia a
`Color.muted`) y el click real queda para el usuario.

<details><summary>Lo que pedía originalmente</summary>

**Construye:** `brain/Behavior.js`, clicks (izq/der/medio), tooltip, mute.

**Acepta cuando:**
- El ciclo camina → parado → sentado → echado corre solo con los tiempos de
  la spec.
- Click derecho silencia; el perro se ve apagado y no habla más.
- Click del medio reinicia los relojes.
- Hablar lo pone de pie desde cualquier pose.

</details>

---

### Fase 9 · Pulido — ✅ COMPLETADA

- **Nada se anima si no se ve**: `reduceMotion` cuando la ventana no está
  mostrada o Atom está mudo. No es pulido — se midió que una superficie
  animada cuesta ~16 % de un core.
- **Barra abajo**: verificado en vivo. La ventana se reubicó a
  `0 622 1366 146` y `reserved` pasó a `0 0 0 26`.
- **Barra vertical**: se esconde con un log claro. Caminar en el otro eje es
  otro diseño, no un ajuste.
- **Barra oculta** (`bar-off`): verificado prendiendo y apagando. Atom se
  esconde y vuelve.
- **`onStage`**: con la barra oculta o vertical no camina ni habla. Los
  relojes siguen contando — eso no se detiene nunca.

<details><summary>Lo que pedía originalmente</summary>

**Construye:** pausa de animaciones cuando no se ven, posiciones de barra,
`bar-off`, monitor con foco, logs consistentes.

**Acepta cuando:**
- Con el perro dormido, la barra no dibuja frames de más: medido con
  `QSG_RENDER_TIMING=1` o contando commits de la superficie, **no** con el
  `%CPU` de `top` — el shell hostea tray, red y bluetooth y su CPU basal
  oscila más que el delta del perro.
- Con la barra abajo, izquierda o derecha: o funciona, o se desactiva con un
  log claro. No se rompe.
- Con `bar-off` activo, Atom se esconde.

</details>

---

## 4. Orden y dependencias

```
F0 spikes ──► F1 esqueleto ──► F2 perro ──► F3 poses ──► F4 movimiento ──► F5 huecos
                   │                                          │
                   └──► F6 sensores ──► F7 hablar ──► F8 ocio ──► F9 pulido
```

F0 decide la forma del manifiesto y dónde se mide la barra, así que F1 no
arranca antes. F6 es independiente de F4/F5. El andamiaje de ventanas del
globo (F7) se define en F1.

## 5. Riesgos

| # | Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|---|
| ~~R1~~ | ~~La ventana se come clicks de la barra~~ | — | — | **Cerrado en la Fase 1.** `mask: Region` atada a un hitbox; confirmado a mano en los dos sentidos |
| R2 | La geometría de los widgets no es alcanzable ni desde el widget | media | medio | Capa 2 (`barConfig`) es buena; la 3 siempre funciona |
| R3 | Un `omarchy update` rompe la capa 1 | media | bajo | Degradación automática + log |
| R4 | El plugin hace lenta la barra | **alta** | alto | **Medido: 60 fps = ~16 % de un core.** Pausar animaciones fuera de vista es obligatorio, no pulido; evaluar 30 fps para la caminata |
| R5 | `claude -p` cuelga | baja | alto | `timeout` obligatorio, asincrónico, fallback local |
| R6 | La recarga resetea contadores | **alta** | **medio** | Persistencia desde F6. No es solo un rescan: **cualquier escritura de `shell.json`** (un `omarchy bar move`, un ajuste propio) recrea servicio y widget |
| R7 | Molesta más de lo que aporta | media | alto | Umbrales configurables, mute de un click, ventana de silencio amplia |
| R8 | El movimiento se desacopla de la pose | media | alto | `walk` única con `canMove`; criterio que itera el registro entero |
| R9 | Multi-monitor: dos perros, o uno que acierta en una pantalla y no en la otra | **alta** | alto | Un perro en el monitor con foco (ARQUITECTURA §9); decidido en F0/F1 |
| R10 | El hueco se invalida solo (el reloj cambia de ancho cada minuto) | **alta** | medio | Se levanta y camina; nunca se recoloca sentado |
| R11 | Sacar el widget de la barra deshabilita el plugin | media | alto | Documentado en README y ARQUITECTURA; el widget es estructural |
| ~~R12~~ | ~~Z-order contra los desplegables~~ | — | — | **Mitigado gratis** (U2): los popups mapean después y siempre ganan. Se acepta que mientras hay uno abierto el perro no es clickeable |
| R13 | `claude` viene de un shim de mise en el PATH del shell | baja | bajo | Ruta absoluta configurable; fallback local si no existe |

## 6. La prueba de extensibilidad

Es un criterio de aceptación, no una aspiración. **Al terminar la v1, estas
dos tareas tienen que poder hacerse sin tocar ningún archivo del núcleo:**

**A. Una regla nueva** que hable cuando son más de las 19:00 y la sesión pasa
las 3 horas.
- Archivos permitidos: `brain/Rules.js`.
- Se verifica con `node`, incluyendo que el `intent` renderizado no contenga
  `{`.

**B. Una pose nueva**: que se rasque.
- Archivos permitidos: `poses/Scratch.qml` (nuevo), `poses/Poses.js` (una
  línea), `brain/Behavior.js` (una fila).
- `Atom.qml`, `Service.qml` y `Mover.qml` **no se tocan**.

Si alguna obliga a abrir el núcleo, la v1 **no está terminada**, por más que
el perro camine.

> El ensayo en seco de esta prueba, hecho antes de escribir una línea de QML,
> ya encontró dos defectos reales: los `{placeholders}` que no renderizaban y
> una receta de pose que no compilaba. Conviene repetirlo al final de cada
> fase que toque un registro.

### ✅ Corrida al terminar la v1 — las dos pasan

**A.** Regla `evening` (después de las 19:00 con 3 h de sesión) agregada
tocando **solo `brain/Rules.js`**. Con `marathon` en cooldown la eligió, y ni
la frase ni el `intent` quedaron con llaves sin renderizar.

**B.** Pose `scratch` agregada con **tres archivos**: `poses/Scratch.qml`
(nuevo, reusando las piezas de `parts/`), una línea en `poses/Poses.js` y dos
filas en `brain/Behavior.js`. Apareció sola en el registro
(`… sleep=quieto · scratch=quieto`), se pudo invocar por IPC y se vio en la
barra rascándose.

**El núcleo no se tocó**: verificado por fecha de modificación, no por
`git status` — en un repo sin commits ese chequeo es vacuo porque colapsa todo
en el directorio.

Las dos pruebas se revirtieron: eran pruebas, no funcionalidades.

## 7. Fuera de alcance de la v1

Memoria entre sesiones, reconocer proyectos además de apps, integración con
`omarchy.agents`, poses más allá de las cinco, reaccionar al cursor,
empaquetado para terceros, un perro por pantalla, y cualquier cosa que
implique que Atom *haga* algo en vez de decirlo.

## 8. Cómo se prueba

- **JS puro** (`Rules.js`, `Geometry.js`, `Behavior.js`): con `node`, sin
  levantar el shell. Ahí vive la lógica que importa, incluidas las constantes
  del dibujo.
- **QML**: a mano, con los criterios de cada fase e IPC para forzar estados
  (`atom pose <id>`, `atom say <regla>`).
- **Superficies**: `hyprctl layers` para ver capa y namespace; `hyprctl
  monitors` para confirmar que no reserva espacio. `hyprctl clients` **no
  sirve**: nunca lista superficies layer-shell, así que un criterio basado en
  él pasa aunque el código esté mal.
- **Rendimiento**: por frames y commits de superficie, no por `%CPU`.
- **Integración**: la lista del §1, corrida entera antes de declarar la v1.

No hay framework de tests para QML: el costo de montarlo no se justifica para
un plugin de escritorio de un solo usuario. Por eso la lógica no trivial se
empuja a JS puro, que sí se testea.
