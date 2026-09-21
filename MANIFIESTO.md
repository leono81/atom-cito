# Atom

> Un perro que vive en la barra de Omarchy, sabe en qué estás trabajando
> y hace cuánto, y te habla cuando conviene parar.

---

## 1. Qué es

Un plugin de `omarchy-shell` (Quickshell) que pone un perro en la barra de
estado. El perro observa dos cosas — **qué ventana tenés enfocada** y **hace
cuánto que no parás** — y a partir de eso decide, cada tanto, decirte algo
corto. El resto del tiempo camina, se sienta, se acuesta y duerme.

El caso testigo que define el proyecto:

> Estás 45 minutos seguidos en `herdr`. Atom se para, camina hasta un hueco
> libre de la barra y te dice:
> *"¿No te parece que podríamos parar para estirar y tomar agua... o parpadear?"*

Eso es todo el producto. El resto de la documentación existe para que ese
momento salga bien, y para que dentro de seis meses siga siendo fácil
agregarle cosas.

## 2. Qué NO es

Definir esto importa más que definir lo anterior, porque casi todo lo que
puede salir mal es scope creep.

- **No es un tracker de productividad.** No hay reportes, no hay gráficos de
  horas, no hay "tu semana en números".
- **No es un asistente.** No responde preguntas, no ejecuta comandos, no abre
  ventanas. Habla, camina, y nada más.
- **No es un pomodoro.** No impone una estructura de trabajo ni te pide que
  declares lo que vas a hacer. Observa, no configura.
- **No es un bot de notificaciones.** No compite con el centro de
  notificaciones ni deja nada en el historial.
- **No juzga.** No existe el concepto de "hoy rendiste poco".

## 3. Principios

Criterios para resolver cualquier duda futura.

1. **Nunca interrumpe.** Nada de lo que haga puede robar foco del teclado,
   tapar una ventana ni obligarte a cerrar algo. Si Atom llega a costarte un
   solo keystroke, está roto.
2. **El silencio es el estado por defecto.** Hablar es la excepción. Ante la
   duda entre decir algo y callarse, se calla.
3. **Local primero.** Todo lo que decide *cuándo* hablar corre en la máquina,
   sin red, sin latencia y sin costo. La red solo decide *cómo* decirlo, y
   nunca es obligatoria.
4. **Degrada bien.** Sin internet, sin quota, sin `claude` en el PATH: sigue
   funcionando con su banco de frases local.
5. **Se puede callar.** Un click lo silencia. Siempre, sin menú, sin diálogo.
6. **Barato en todo sentido.** En tokens, en CPU, en atención.
7. **Nunca miente sobre lo que sabe.** Si comenta algo, es porque lo observó.
8. **Agregarle algo es agregar una línea, no editar cinco archivos.** Ver
   [`docs/EXTENDER.md`](docs/EXTENDER.md). Si una funcionalidad nueva obliga a
   tocar el núcleo, el que está mal es el núcleo.

## 4. El personaje

**Atom es un perro**: de perfil, cuerpo largo, patas cortas, orejas caídas.
Registro *"no pasa nada, pero pará"*. Nunca alarmista, nunca motivacional,
nunca en tono de coach.

Dibujado con **vectores** (`QtQuick.Shapes` + primitivas de QML), no con
fuente ni con sprites: toma el color del tema solo, escala sin romperse, y
cada parte se anima por separado.

La especificación completa — poses, pivotes, timings, máquina de ocio — está
en [`docs/PERSONAJE.md`](docs/PERSONAJE.md).

### Postura antes que color

Darle cuerpo cambió la forma de comunicar estado: el humor dejó de ser un
cambio de color y pasó a ser **postura**, que se lee de reojo.

| Pose | Qué significa |
|---|---|
| parado | fresco; recién volviste de una pausa |
| caminando | yendo hacia algún lado; es la **única** pose que se traslada |
| sentado | tranqui; llegó a su lugar y espera |
| echado | frito; dos horas sin que te levantes |
| durmiendo | no estás; tres minutos sin teclado |

### La invariante de movimiento

> **Atom solo cambia de posición en las poses que lo declaran.**

Son dos: caminar y la cabriola. Sentado, echado, dormido, rascándose,
jugando o haciendo pis, su `x` está congelada, y cualquier cambio de estado
congela la posición donde esté. Un perro sentado que se desliza por la barra
rompe la ilusión entera, y arreglarlo después es más caro que respetarlo
desde el principio — por eso la regla es estructural y no una condición
suelta: cada pose declara `canMove`, y el que mueve se niega a trabajar si la
pose activa no lo permite.

### Dónde se para

Camina toda la barra, pero **solo se detiene en los huecos entre widgets**.
Nunca queda parado encima del reloj ni de un ícono. Los huecos se calculan
midiendo la barra real, así que si agregás, sacás o movés un widget, los
lugares de descanso se recalculan solos.

## 5. Cómo piensa

Cerebro **híbrido**, partido en dos mitades con responsabilidades distintas:

```
  reglas locales  ─────►  deciden CUÁNDO hablar   (JS puro, sin red, instantáneo)
        │
        └── contexto ──►  Claude decide QUÉ decir  (claude -p, opcional)
                              │
                              └── si falla ──►  banco de frases local
```

Las reglas son deterministas y auditables: se lee el archivo y se sabe bajo
qué condiciones habla. El texto es lo que se gasta con la repetición — frases
fijas, al mes ya las conocés y dejás de leerlas. Claude se invoca solo cuando
una regla ya decidió que vale la pena hablar, así que el gasto queda acotado
por diseño.

El banco de frases local **no es un plan B degradado**: está escrito con el
mismo cuidado que el prompt, y Atom con `useClaude: false` sigue siendo un
producto entero.

## 6. Las reglas

| Regla | Dispara cuando | Prioridad | Espera mínima |
|---|---|---|---|
| `marathon` | 120 min sin ninguna pausa real | 40 | 45 min |
| `late` | entre 00:00 y 05:00 con 20+ min de sesión | 35 | 90 min |
| `stretch` | 45 min seguidos en la misma app | 30 | 30 min |
| `water` | 60 min desde la última pausa | 20 | 60 min |
| `welcome` | volvés después de 25+ min afuera | 10 | 15 min |
| `ondemand` | le hacés click | — | — |

Sobre todas rige una **ventana de silencio global** de 20 minutos: pase lo que
pase, nunca habla dos veces dentro de ese lapso. Cuando varias reglas
coinciden, gana la de mayor prioridad.

### Los dos relojes

- **Racha** (`streak`): minutos seguidos en la *misma* app. Cambiar de ventana
  por menos de 90 segundos **no** la corta — alt-tabear al browser no te
  perdona los 45 minutos que llevás en el editor.
- **Sesión** (`session`): minutos desde la última pausa real, sin importar la
  app.

Una **pausa real** son 3 minutos sin tocar teclado ni mouse (`IdleMonitor` de
Wayland). No cuenta mirar un video: se mide input, no pantalla.

### Qué app es "la app"

Saber que estás en *foot* no dice nada; saber que estás en *herdr* lo dice
todo. Y el título tampoco alcanza: dice "Berserker: Projects" mientras
adentro corre herdr con seis paneles.

Por eso Atom **mira el árbol de procesos** de la ventana enfocada y reporta el
TUI más cercano a la terminal (`herdr`, `nvim`, `lazygit`, `btop`…). Si abrís
claude adentro de herdr, seguís estando en herdr.

De paso cuenta cuántos agentes `claude` viven ahí adentro, y ese número entra
al contexto. Es el dato que más personalidad le da a las frases, porque es el
único que Atom sabe y que uno no espera que sepa:

> *Ciento cuarenta minutos sin pausa y casi la una. Los seis agentes ni notan
> si te vas cinco minutos. Andá, que yo vigilo.*

## 7. Privacidad

Con `useClaude` activo, cada vez que Atom decide hablar sale de la máquina
esto y nada más:

- el `appId` de la ventana enfocada;
- el título de la ventana — **apagable** con `sendTitles: false`;
- los dos contadores en minutos y la hora local;
- las últimas frases que dijo, para no repetirse.

Nunca sale: contenido de ninguna ventana, lo que escribís, nombres de archivo
que no estén en el título, ni nada acumulado de sesiones anteriores.

Con `useClaude: false` no sale absolutamente nada de la máquina.

> El plugin corre **sin sandbox dentro del proceso `omarchy-shell`**. Es código
> propio en la máquina propia, pero conviene tenerlo presente al modificarlo.

## 8. Costo

Una invocación a `claude -p` por frase dicha, modelo chico (`haiku`) por
defecto, prompt de pocos cientos de tokens. Con la ventana de silencio de 20
minutos el techo teórico son ~20-25 invocaciones en una jornada larga, y el
piso real es bastante menor. `useClaude: false` lo lleva a costo cero sin
perder el producto.

## 9. Estructura del repo

```
~/Projects/atom/
├── MANIFIESTO.md     este documento: qué es y por qué
├── PLAN.md           plan de implementación por fases
├── README.md         instalación y uso
├── plugin/           el plugin (fuente de verdad)
└── docs/             arquitectura, personaje, cómo extenderlo, maquetas
```

El directorio de plugins de Omarchy apunta acá por symlink:

```
~/.config/omarchy/plugins/leono.atom -> ~/Projects/atom/plugin
```

El descubrimiento de plugins de terceros itera con `for sub in "$dir"/*/`, que
resuelve symlinks a directorios, así que el shell lo encuentra igual
(verificado). El código vive versionado en `~/Projects` y no como copias
sueltas en `~/.config`.

**Nunca se edita `/usr/share/omarchy/`.** Es del paquete y se pisa en cada
`omarchy update`. Se lee todo lo que haga falta, eso sí.

## 10. Roadmap

Ideas que **no** entran en la primera versión, anotadas para no rediscutirlas:

- Reconocer proyectos, no solo apps (`herdr` en `~/Projects/kenos` ≠ `herdr`
  en `~/Projects/cenit`).
- Engancharse con el widget `omarchy.agents` para saber cuándo hay un agente
  laburando y comentar sobre eso.
- Memoria entre sesiones: que sepa que ayer también estuviste hasta las 3 AM.
- Más poses: rascarse, sacudirse, perseguirse la cola, estirarse.
- Que reaccione al cursor: seguirlo con la cabeza cuando pasa cerca.
- Publicarlo como plugin instalable por terceros (`omarchy plugin add`).

## 11. Bitácora de decisiones

| Decisión | Alternativas descartadas | Por qué |
|---|---|---|
| Cerebro híbrido | solo reglas / Claude siempre | Las reglas dan control y costo cero sobre el *cuándo*; Claude evita que el *qué* se gaste. Llamarlo siempre gastaba quota para, casi siempre, decidir callarse. |
| Personaje siempre visible | punto discreto | El pedido era "que esté ahí dando vueltas". Uno que solo aparece para retarte se vuelve un reto; uno que está siempre, es compañía. |
| Globo desde la barra | notificación del sistema | No debe competir con las notificaciones reales ni entrar al historial. |
| Perro con cuerpo | carpincho de frente | El cuerpo habilita poses, y la postura comunica estado mejor que el color. Se pierde el mirar de frente: un perro que camina tiene que ir de perfil. |
| Camina y para en huecos | slot fijo / carril reservado | Recorre la barra entera sin pisar widgets. Cuesta más código que el slot fijo, pero es la diferencia entre un ícono y un personaje. |
| Movimiento acoplado a la pose | mover libre | Un perro sentado deslizándose rompe la ilusión. La regla es estructural (`canMove` por pose), no una condición suelta. |
| `service` con `PanelWindow` propia | plugin `kind: "panel"` | El servicio de terceros arranca solo y con su config; el ciclo de vida de los paneles depende de que alguien los invoque. Patrón verificado en `nosignal.motion-wallpaper`. |

---

*Este documento es la fuente de verdad del proyecto. Si el código lo
contradice, el que está mal es el código.*
