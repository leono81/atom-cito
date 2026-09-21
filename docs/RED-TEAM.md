# Revisión adversarial del plan

Antes de escribir una línea de producto, el plan v1 se sometió a una revisión
adversarial: un agente con acceso a la máquina, con la instrucción explícita
de **no confiar en la documentación** y verificar cada afirmación contra el
código real de Omarchy 4.0.4 y Quickshell 0.3.1.

Encontró 16 hallazgos. Los cuatro más graves los volví a verificar a mano
antes de aceptarlos; los cuatro dieron positivo.

**Veredicto:** la arquitectura general era correcta — service + `PanelWindow`
Overlay + registros + JS puro testeable, todo respaldado por dos plugins de
terceros que ya corren en esta máquina. Lo que estaba mal era **la base de
supuestos**: dos de los ocho "verificados" eran falsos, uno de los seis "a
resolver" ya era falso sin necesidad de spike, y tres riesgos no listados eran
más peligrosos que los seis que sí estaban.

Lo más incómodo: **los dos requisitos que el usuario marcó como innegociables
fallaban en el papel.**

---

## Hallazgos y resolución

| # | Sev | Hallazgo | Estado |
|---|---|---|---|
| 1 | FATAL | `shell.shellConfig` no existe para plugins de terceros; el plan lo daba por verificado | Resuelto |
| 2 | FATAL | `canMove` no garantizaba la invariante: `stand` valía `true` | Resuelto |
| 3 | GRAVE | El watcher no atraviesa symlinks: no hay recarga en caliente | Resuelto |
| 4 | GRAVE | El service de terceros no está en el árbol QML: no puede medir la barra | Resuelto |
| 5 | GRAVE | Sacar el widget de la barra deshabilita el plugin entero | Documentado |
| 6 | GRAVE | El manifiesto promete `BarWidget.qml` y ninguna fase lo construía | Resuelto |
| 7 | GRAVE | Ningún `{placeholder}` de las reglas renderizaba | **Corregido en el código** |
| 8 | GRAVE | La receta de "pose nueva" de EXTENDER no compilaba | Resuelto |
| 9 | GRAVE | Multi-monitor: un cerebro, N ventanas, sin decidir | Resuelto |
| 10 | GRAVE | El hueco se mueve solo y enfrenta dos criterios de terminado | Resuelto |
| 11 | GRAVE | La máscara de input atada a un item animado = un commit por frame | Resuelto |
| 12 | GRAVE | `omarchy-shell` corta a los 2 s; `claude` tarda 3–5 | Resuelto |
| 13 | MENOR | Cuatro criterios de aceptación que sonaban medibles y no lo eran | Resuelto |
| 14 | MENOR | `IdleMonitor` da un booleano por umbral, no segundos, y mide puntero | Resuelto |
| 15 | MENOR | Dependencias ocultas: F0 decide la forma del manifiesto; el globo es de F1 | Resuelto |
| 16 | MENOR | Barra abajo/vertical, `bar-off`, z-order, recarga global, `claude` por shim | Resuelto |

### 1 · `shellConfig` no existe (FATAL)

El plan afirmaba, como verificado, que un servicio lee su configuración de
`shell.shellConfig.plugins[]`. La fachada que recibe un plugin de terceros
(`services/PluginShellApi.qml:13-28`) expone `pluginId`, `appLibrary`, `bar`,
`barConfig` e `idleConfig` — **no `shellConfig`**.

El "patrón verificado" venía de `motion-wallpaper`, donde ese código existe…
y devuelve `null` siempre. Copié el código, no el resultado. Por eso ese
plugin guarda todo su estado real en `~/.local/state/`.

Peor: como Atom declara un kind `bar-widget`, su entry ni siquiera va a
`plugins[]`, sino a `bar.layout.<sección>` (confirmado: en `shell.json`,
`motion-wallpaper` está en `bar.layout.right` y `bar-shadow`, que es service
puro, en `plugins[]`).

Sin esto, `ctx.cfg` llegaba vacío, `Rules.js` tiraba excepción en
`c.cfg.marathonMinutes`, el `try/catch` se la comía y **ninguna regla
disparaba nunca** — un perro mudo sin un solo error en el log.

**Resolución:** los ajustes llegan por el `BarWidget` (que sí recibe su entry
en `settings`) y se pasan al servicio por `shell.serviceFor()`, con lectura
de `shell.json` del disco como respaldo. ARQUITECTURA §2 y §6.

### 2 · La invariante de movimiento no se sostenía (FATAL)

`PERSONAJE.md` §3 decía `stand → canMove: sí` y, dos líneas más abajo, que
`walk` no era una pose aparte sino "stand con las patas animadas". El único
dato que implementa la invariante valía `true` estando quieto.

Y el criterio de aceptación de la Fase 4 estaba escrito de forma que **no
podía detectarlo**: probaba `sit`/`lie`/`sleep`, nunca `stand`.

**Resolución:** `walk` es una pose registrada propia y la única con
`canMove: true`; `stand` vale `false`. El criterio de la Fase 4 ahora itera
el registro entero.

### 7 · Los placeholders (GRAVE, ya corregido)

Las reglas usaban `{streak}`, `{session}`, `{away}`; el contexto define
`streakMinutes`, `sessionMinutes`, `awayMinutes`. Ninguna coincidía: todas
las frases locales salían con llaves literales, y el `intent` que iba a
Claude también. `{app}` funcionaba por casualidad, por ser el único nombre
que coincidía.

El dato incómodo es que la evidencia estaba a la vista en una corrida de
`node` hecha mucho antes, y pasó desapercibida.

**Corregido en `plugin/brain/Rules.js`**, y verificado: las seis reglas
renderizan sus placeholders, `intent` incluido. Quedó como criterio de
aceptación de la Fase 7.

### 9, 10, 11 · Los riesgos que no estaban

- **Multi-monitor**: `Variants` crea una ventana por pantalla, pero el
  cerebro es uno. O se clona el perro y acierta el hueco en una pantalla y
  falla en la otra, o hacen falta N cerebros y la ventana de silencio se
  multiplica. → **Un perro, en el monitor con foco.**
- **El hueco móvil**: el reloj está en `dddd HH:mm` y cambia de ancho cada
  minuto. El hueco donde Atom está sentado se invalida solo, y ahí chocan dos
  criterios de terminado. → **Gana la invariante**: se levanta, camina, se
  sienta.
- **La máscara por frame**: `mask: Region { item: perro }` con el perro
  animándose reemite la región de input de la superficie Wayland en cada
  frame, dentro del proceso de la barra. Es costo de protocolo, que el
  presupuesto de rendimiento no contemplaba. → **Máscara estática**,
  recalculada al llegar.

---

## Lo que la revisión confirmó que estaba bien

- Una ventana `Overlay` (nivel 3) queda encima de la barra (`Top`, nivel 2).
- El click-through existe y está resuelto: `mask: Region`, ya usada por
  `leono.bar-shadow`.
- Un plugin de terceros **sí** puede registrar su propio target de IPC —
  `omarchy-shell motion-wallpaper ping` devuelve `ok` —, así que
  `omarchy-shell atom pose sit` es un criterio legítimo.
- `Variants` + `Quickshell.screens` es la API vigente.
- El tema es accesible con `import qs.Commons`.
- `claude -p --model haiku` tarda 3–5 s: el timeout de 10 s alcanza.

---

## Qué aprendí de esto

1. **"Verificado" tiene que significar que vi el resultado, no que vi el
   código que lo produce.** El error fatal nació de leer un patrón en otro
   plugin y asumir que funcionaba. Funcionaba en el sentido de que no tiraba
   error; devolvía `null`.
2. **Un criterio de aceptación que no puede fallar no es un criterio.** Tres
   de los míos pasaban con el código roto: `hyprctl clients` (que nunca lista
   layer-shell), el `%CPU` de `top`, y el test de la invariante que no
   probaba la pose culpable.
3. **La prueba de extensibilidad vale corrida en seco.** Ese solo ejercicio,
   sin escribir QML, destapó dos defectos reales.
