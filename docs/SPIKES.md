# Fase 0 — resultados de los spikes

Seis preguntas abiertas, resueltas antes de escribir una línea de producto.
Dos frentes en paralelo: investigación de API (solo lectura) y spikes en vivo
sobre el shell (plugin descartable `leono.atomspike`, ya desinstalado; el
código quedó en `spikes/plugin/` como registro).

**Veredicto: ninguna respuesta tumba el diseño.** Dos correcciones importantes
de implementación, una simplificación grande, y un cambio de prioridades en el
presupuesto de rendimiento.

---

## U1 · ¿Se pueden medir los widgets de la barra? — **SÍ, y completo**

Desde el `BarWidget` se trepa 9 niveles por `parent` hasta el `QQuickRootItem`
de la ventana de la barra, se baja recursivamente y salen **los 17 slots** con
su `moduleName`, su sección y sus rectángulos exactos vía `mapToItem`.

```
omarchy.menu        left    x=   8  w=  27
omarchy.workspaces  left    x=  35  w= 106
omarchy.indicators  center  x= 610  w=  21
omarchy.clock       center  x= 631  w= 104
...
omarchy.power       right   x=1321  w=  27
```

Huecos reales de esta barra: **141→610** (469 px) y **756→1132** (376 px).
Sobra lugar para un perro de 28 px.

**Corrección al supuesto de ARQUITECTURA §7:** la capa 1 **no** depende de
internals frágiles. No usa `bar.moduleWidgets()` (ese camino sí está acotado
al propio módulo y es una pared) ni ninguna API privada: solo `parent`,
`children`, `mapToItem` y la convención de que un slot tiene `moduleName` —
que es parte del contrato público documentado de `BarWidget`. El riesgo R3
("un update rompe la capa 1") baja bastante.

**Decisión: se implementa la capa 1, y la capa 3 (zonas por sección) como
piso. La capa 2 se descarta.** No aporta nada que la 1 no dé mejor, y no
resuelve R10: `barConfig` no cambia cuando un widget cambia de ancho, y se vio
en vivo a `omarchy.indicators` pasar de 21 px a 126 px entre dos muestras.

Tres cosas a codificar desde el día uno:

- **Filtrar por `w > 0`, no por `visible`**: `tray`, `keyboard-layout` y
  `system-update` están montados con ancho cero.
- **Re-medir en cada tick, nunca cachear.**
- Todo en `try/catch`; ante cualquier excepción, `null` → capa 3.

El climb es por ventana, así que cada `BarWidget` ve solo los slots de su
monitor. Es justo lo que hace falta para multi-monitor.

---

## U6 · ¿Cuándo llega la config? — **y un camino mejor del esperado**

| Momento | Estado |
|---|---|
| `Component.onCompleted` del servicio | `shell` es **`null`** |
| `Component.onCompleted` del widget | `settings` está **vacío (`{}`)** |
| Cualquier `Qt.callLater` posterior | todo presente |

**Nunca leer `settings` ni `shell` dentro de `Component.onCompleted`.**

Y la buena: **el servicio puede leer su propia entrada desde
`shell.barConfig`**, con los ajustes inline incluidos.

```
SVC t-callLater  own entry via barConfig =
  {"section":"right","index":9,
   "entry":{"id":"leono.atomspike","probeName":"hola-atom","probeValue":42}}
```

O sea que el canal widget → servicio **no es la única vía** para la config
(sigue siendo necesario para la geometría). `shell.shellConfig` es
`undefined`, como ya sabíamos.

### Hallazgo extra: cualquier escritura de `shell.json` recrea el plugin

`reloadConfig` — que dispara **cualquier** escritura de `shell.json`, incluido
un `omarchy bar move` o un cambio de ajuste del propio Atom — **destruye y
recrea el servicio y el widget**. Se verificó cambiando `probeValue` de 42 a
99: el valor llegó nuevo, pero en una instancia nueva, con `Component.onCompleted`
y `registerWidget` disparando otra vez.

Consecuencias: **R6 es más amplio de lo escrito** (no es solo `rescanPlugins`),
la persistencia de relojes es obligatoria desde temprano, y `registerWidget()`
tiene que ser **idempotente**.

### Hallazgo extra 2: el loop de desarrollo estaba mal documentado (otra vez)

**`omarchy-shell shell rescanPlugins` NO recarga el código QML de un plugin de
terceros.** Re-instancia el servicio, pero desde el componente **cacheado**:
se agregaron funciones al `IpcHandler` y `qs ipc show` siguió mostrando la
lista vieja; se agregó un marcador a un `console.log` y nunca apareció.
Borrar y recrear el symlink tampoco.

Causa, en `/usr/share/omarchy/shell/shell.qml:1470`:

```qml
if (typeof Qt.clearComponentCache === "function") Qt.clearComponentCache()
```

`Qt.clearComponentCache` **no existe como función QML** — es API C++ de
`QQmlEngine` — así que el guard falla en silencio y el caché nunca se limpia.

**El ciclo de desarrollo real es `omarchy restart shell`.** Es un candidato a
reporte upstream.

---

## U3 · Máscara de input — **funciona, y el costo no está donde creíamos**

La máscara es exacta al píxel y la ventana no reserva espacio:

```
Layer level 3 (overlay):
    Layer …: xywh: 240 0 200 40, namespace: atomspike
$ hyprctl monitors | grep reserved
    reserved: 0 26 0 0        # solo la barra
```

Con la ventana tapando cuatro widgets y la máscara cubriendo solo un
rectángulo de 40 px, el compositor entregó eventos **únicamente dentro de la
máscara**; un `MouseArea` que cubría toda la ventana no se disparó jamás fuera
de ella.

### El presupuesto de rendimiento estaba mal enfocado

Delta de CPU del proceso del shell, ventanas de 10 s, escritorio quieto:

| Condición | CPU |
|---|---|
| Quieto | **0.02 %** |
| Animado a 60 fps, máscara atada al item animado | **~16.6 %** de un core |
| Animado a 60 fps, máscara **fija** | **~16.1 %** |
| Solo la máscara animada, nada se mueve en pantalla | **~16.3 %** |

**La reemisión de la región es ruido; lo caro es que la superficie tenga
frames.** Una `NumberAnimation` sobre la máscara cuesta igual que animar
píxeles, porque el animation driver de QML pide un frame de todos modos.

El número accionable: **una superficie overlay animada a 60 fps cuesta ~16 %
de un core en esta laptop; quieta, 0.02 %.**

Reordena ARQUITECTURA §8: el enemigo no es la máscara, es **el frame rate del
perro**. Pausar animaciones cuando no se ven sube de "pulido" (Fase 9) a
**necesario**, y hay que evaluar caminar a 30 fps o menos.

> La recomendación de atar la máscara a un hitbox que solo salta al llegar
> sigue siendo buena — simplifica y hace el input predecible — pero **no se
> justifica por rendimiento**, como creíamos.

### ✅ Confirmado por el usuario (Fase 1)

Click sobre el reloj **a través** de la ventana → abre el calendario. Click
sobre el perro → lo recibe Atom, y el reloj no se entera. La máscara funciona
en los dos sentidos. **R1 cerrado.**

<details><summary>Cómo se confirmó</summary>

#### Era una confirmación humana de 10 segundos

No se pudo verificar automáticamente que un click **atraviese** la ventana.
Se logró inyectar clicks con `hyprctl eval` y llegan a superficies Overlay
propias, pero **no a las superficies `Top`** (la barra), así que la prueba
queda inválida por una asimetría del dispatcher. `ydotool` no está instalado;
`wtype` es solo teclado.

**Cuando exista la ventana de Atom (Fase 1), son 10 segundos:**

1. Dejar el perro quieto en un hueco, con el resto de la ventana tapando el
   reloj.
2. **Click sobre el reloj**, a través de la ventana. Tiene que cambiar a la
   fecha larga. → click-through OK.
3. **Click sobre el perro**. Atom reacciona y el reloj **no** cambia. → la
   máscara está bien de los dos lados.

Si (2) no hace nada, la máscara está mal y hay que mirarla antes de seguir.

</details>

---

## U2 · Z-order — **los desplegables siempre ganan, y está bien así**

Un desplegable de la barra **no es un xdg-popup**: es una `PanelWindow`
propia, `WlrLayer.Overlay`, namespace `omarchy-keyboard-panel`, **de pantalla
completa y con máscara de input de pantalla completa**, que se mapea al
abrirse y se desmapea al cerrarse.

Como Atom mapea su superficie una sola vez al arrancar, **cualquier popup que
se abra después queda encima**. Verificado por input, no por la lista:

```
A  panel CERRADO, cursor en la zona enmascarada -> llega
B  panel ABIERTO, mismo punto                   -> NO llega
C  panel cerrado de nuevo                       -> vuelve a llegar
```

**R12 queda mitigado sin hacer nada.** Y `rescanPlugins` cierra el popup
abierto antes de recrear a Atom, así que la secuencia "Atom mapeado después
del popup" no se puede dar.

Efecto colateral a asumir: **mientras un desplegable está abierto se come todo
el input de la pantalla**, Atom incluido. El perro se sigue viendo (la
superficie del panel es transparente fuera de su tarjeta) pero no es
clickeable. Es aceptable.

### La regla que sale de acá

> **Mapear la ventana una vez y no desmapearla nunca.**

Cualquier `visible: false` desmapea la superficie, y remapearla la reinserta
**arriba de todo** en la capa Overlay, tapando popups y notificaciones. Para
esconder al perro — barra oculta, monitor sin foco, silenciado — se toca
**opacidad y máscara**, jamás `visible`. Es además ~7× más barato: el propio
bar de Omarchy documenta 150 ms contra 20 ms.

---

## U5 · Monitor con foco — `Hyprland.focusedMonitor`

`Hyprland.focusedMonitor.name` comparado contra `modelData.name`, que es lo
que hace el propio bar de Omarchy (`Bar.qml:714`). Es reactivo. Viene vacío
hasta que Hyprland reporta, y ahí hay que caer al primer screen en vez de
adivinar.

`ToplevelManager.activeToplevel` no sirve como fuente primaria: queda nulo en
un workspace vacío.

**Nunca alternar `visible` para mover el perro de pantalla** (ver U2). Las
ventanas quedan siempre mapeadas en todos los monitores; lo que cambia es la
opacidad del contenido y la máscara.

---

## U4 · Posición de la barra — **una corrección que habría costado horas**

### `Normal` + `exclusiveZone: 0` hace lo contrario de lo que necesitamos

ARQUITECTURA §9 decía de copiar la técnica de `bar-shadow`. Esa combinación
significa *"no reservo nada pero respeto lo que reservan los demás"*, así que
el compositor te empuja **fuera** de la zona de la barra. Medido en vivo:

```
omarchy-bar         xywh: 0  0 1366 26
omarchy-bar-shadow  xywh: 0 26 1366 16   <- el compositor lo parkeó DEBAJO
```

Perfecto para una sombra, exactamente lo contrario para Atom.
**Va `ExclusionMode.Ignore`**, y el tamaño lo ponemos nosotros.

### Anclas por posición

Se anclan **tres** lados —el de la barra más los dos perpendiculares— y el
`implicit*` del eje libre va en 0. Es el patrón de `Bar.qml:1257`:

| position | top | bottom | left | right | implicitWidth | implicitHeight |
|---|---|---|---|---|---|---|
| `top` | ✔ | ✘ | ✔ | ✔ | 0 | `barSize` |
| `bottom` | ✘ | ✔ | ✔ | ✔ | 0 | `barSize` |
| `left` | ✔ | ✔ | ✔ | ✘ | `barSize` | 0 |
| `right` | ✔ | ✔ | ✘ | ✔ | `barSize` | 0 |

### La simplificación: `shell.bar`

`shell.bar` expone **`position`, `barSize`, `barHidden`, `fontFamily`** con
bindings vivos, disponible para cualquier plugin sin capability especial.

No hace falta el `Process` ni el `FileView` vigilando
`~/.local/state/omarchy/toggles/bar-off` que estaba documentado. Y **mejor no
copiarlo**: el propio código de Omarchy avisa que ese watcher de directorio
puede dejar de entregar eventos, y por eso `omarchy-toggle-bar` le manda un
nudge por IPC a `omarchy.bar` — que a nosotros no nos llegaría.

**Caveat:** `shell.bar` se pone en `null` mientras el Loader del bar se
recarga. Habrá frames con `barSize == 0`; hay que defenderse con defaults.

---

## Extra · Una ventana, no dos

**Una sola `PanelWindow` por monitor, de geometría fija** (alto = `barSize` +
espacio del globo), con dos zonas en la máscara.

1. **Sincronía visual.** El globo cuelga de la cabeza del perro. Con una
   ventana salen en el mismo buffer y el mismo commit. Con dos, mover el globo
   es un round-trip asíncrono con el compositor y **se arrastraría uno o más
   frames detrás**.
2. **Un solo lugar en el z-stack.** Un globo que se mapea al hablar aparecería
   **arriba de todo** cada vez (U2).
3. **Nada de resize de superficie.** Precedente textual en el servicio de
   notificaciones de Omarchy: superficie fija para que el compositor no escale
   un buffer viejo al cambiar el contenido.

---

## Qué cambia en el plan

| Hallazgo | Impacto |
|---|---|
| Capa 1 viable y robusta | Se descarta la capa 2; capa 3 como piso |
| `ExclusionMode.Ignore`, no `Normal`+0 | Corrige ARQUITECTURA §9 |
| `shell.bar` con bindings vivos | Menos código: sin `Process`, sin `FileView` |
| Servicio lee `barConfig` | La config tiene dos vías; el widget sigue siendo necesario para geometría |
| `reloadConfig` recrea el plugin | R6 más amplio; `registerWidget` idempotente |
| `rescanPlugins` no recarga código | El loop de desarrollo es `omarchy restart shell` |
| 60 fps = 16 % de un core | R4 sube; pausar animaciones deja de ser pulido |
| Popups siempre ganan | R12 mitigado gratis |
| Mapear una vez, nunca desmapear | Regla dura nueva |

**Ningún hallazgo obliga a replantear la arquitectura.** La Fase 1 puede
arrancar.
