# Atom

Un perro que vive en la barra de [Omarchy](https://omarchy.org/), sabe en qué
estás trabajando y hace cuánto, y te habla cuando conviene parar.

El resto del tiempo camina la barra, se sienta en los huecos entre los
widgets, se acuesta si lo dejás tranquilo, y se duerme cuando te vas.

```
[☰][1 2 3]········🐕·······[domingo 21:47]·········[wifi][vol][⏻]

   ┌─────────────────────────────────────────────────────┐
   │ Van 47 minutos clavado en herdr. ¿No te parece que  │
   │ podríamos parar para estirar y tomar agua... o      │
   │ parpadear?                                          │
   └─────────────────────────────────────────────────────┘
```

## Cómo funciona

Reglas locales deciden **cuándo** hablar; Claude escribe **qué** decir. Sin
red, sin `claude` en el PATH o con `useClaude: false`, usa su banco de frases
local y sigue siendo un producto entero.

Observa dos cosas: qué ventana tenés enfocada y hace cuánto que no parás.
Nada más. Ver [privacidad](MANIFIESTO.md#7-privacidad).

## Instalación

Requiere Omarchy 4.x (con `omarchy-shell`) y, opcionalmente, el CLI `claude`.

```bash
git clone https://github.com/leono81/atom-cito ~/Projects/atom
cd ~/Projects/atom
./deploy.sh v0.1.0
```

`deploy.sh` copia esa versión a `~/.config/omarchy/plugins/leono.atom` y
reinicia el shell. Para actualizar o volver atrás, `./deploy.sh <otro tag>`;
`./deploy.sh` a secas dice qué versión está corriendo.

Después, habilitarlo agregando su entrada en `~/.config/omarchy/shell.json`:

```json
{
  "plugins": [
    { "id": "leono.atom" }
  ]
}
```

Los cambios en `shell.json` se aplican al guardar, sin reiniciar el shell.
(El código del plugin es otra cosa: ver [Desarrollo](#desarrollo).)

## Configuración

Todo va en la misma entrada de `shell.json`. Los valores son los que trae por
defecto:

```json
{
  "id": "leono.atom",
  "stretchMinutes": 45,      // minutos en la misma app antes de sugerir pausa
  "marathonMinutes": 120,    // minutos sin pausa real antes de insistir
  "waterMinutes": 60,        // recordatorio de agua
  "quietMinutes": 20,        // nunca habla dos veces dentro de esta ventana
  "breakSeconds": 180,       // inactividad que cuenta como pausa real
  "switchGraceSeconds": 90,  // alt-tab más corto que esto no corta la racha
  "bubbleSeconds": 14,       // cuánto dura el globo
  "useClaude": true,         // false = solo frases locales, cero red
  "sendTitles": true,        // false = no manda el título de la ventana
  "model": "haiku",          // modelo para las frases
  "pomodoroScrollPx": 60,    // cuánto deslizar para sumar o restar 5 minutos
  "pomodoroPickSeconds": 6   // sin tocar nada, la elección se cancela
}
```

## Uso

| Acción | Qué hace |
|---|---|
| click | le pedís un comentario ahora |
| click derecho | lo silenciás / lo despertás |
| click del medio | "volví de una pausa": reinicia los relojes |
| hover | los dos relojes: app actual y sesión. Mientras tanto se queda quieto |

### Pomodoro

Solo si lo pedís: Atom nunca lo propone ni lo arranca solo.

| Gesto sobre el perro | Qué hace |
|---|---|
| scroll vertical (dos dedos) | elige los minutos de foco: 25 a 90, de a 5 |
| scroll horizontal | elige el descanso: 5 a 20 |
| tap / click | arranca. La próxima vez, el selector empieza desde estos valores |
| tap con dos dedos / click derecho | cancela la elección; durante un pomodoro, dos seguidos lo cortan |
| hover durante el pomodoro | cuánto falta |

En el foco se echa y no habla; al terminar te avisa y en el descanso pasea.
También por IPC, por ejemplo para un atajo de Hyprland:

```bash
omarchy-shell atom pomodoro 50 10   # foco 50, descanso 10
omarchy-shell atom pomodoroAgain    # repite el último
omarchy-shell atom pomodoroStop
omarchy-shell atom pomodoroStatus
```

El prototipo con el que se diseñó el gesto está en
[docs/pomodoro.html](docs/pomodoro.html).

## La demo

```bash
./demo.sh            # los trece actos, unos dos minutos
./demo.sh 7          # solo uno
./demo.sh --list     # cuáles hay
```

Está pensada para filmar: carteles grandes en la terminal diciendo qué mirar,
y el perro haciéndolo arriba en la barra. Dejá la terminal en la mitad de
abajo de la pantalla y apuntá la cámara a la pantalla entera.

## Documentación

| Documento | Para qué |
|---|---|
| [MANIFIESTO.md](MANIFIESTO.md) | qué es, qué no es, y por qué cada decisión |
| [PLAN.md](PLAN.md) | plan de implementación por fases |
| [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md) | cómo está construido |
| [docs/EXTENDER.md](docs/EXTENDER.md) | **recetas para agregarle cosas** |
| [docs/PERSONAJE.md](docs/PERSONAJE.md) | especificación del perro |
| [docs/RED-TEAM.md](docs/RED-TEAM.md) | la revisión adversarial del plan y qué cambió |
| [docs/SPIKES.md](docs/SPIKES.md) | resultados de la Fase 0: lo que se midió contra el sistema real |
| [docs/perro.html](docs/perro.html) | referencia visual viva (abrir en el navegador) |

## Extenderlo

Es el requisito central del proyecto: agregarle algo tiene que ser **un
archivo nuevo y una línea de registro**.

```js
// brain/Rules.js — que hable en una situación nueva
{ id: "uncommitted", priority: 25, gapMinutes: 60,
  test: c => c.gitDirtyMinutes >= 90,
  intent: "Hace {gitDirtyMinutes} minutos que no commitea en {gitRepo}.",
  lines: ["Commiteá aunque sea un WIP."] }
```

```js
// poses/Poses.js — una pose nueva
{ id: "scratch", file: "Scratch.qml" }
```

Las cinco recetas completas (reglas, poses, sensores, voces, comportamiento)
están en [docs/EXTENDER.md](docs/EXTENDER.md).

Para entender cómo encaja todo antes de tocar nada:
[docs/DIAGRAMAS.md](docs/DIAGRAMAS.md) tiene los estados del perro, la
secuencia de cómo decide hablar, los componentes y el despliegue.

## Desarrollo

Para trabajar sobre el código vivo, `./deploy.sh dev` cambia la copia fija
por un symlink al repo. No hay recarga en caliente (el porqué está en
[docs/EXTENDER.md](docs/EXTENDER.md#0-el-ciclo-de-trabajo)): cada cambio se
recoge con

```bash
omarchy restart shell
journalctl --user -f | grep -i atom  # ver los logs
plugin/tests/run.sh                  # la lógica pura, con node
```

### Versiones

`main` está siempre estable; lo nuevo entra por rama y PR. Para publicar una
versión: subir `version` en `plugin/manifest.json`, commitear, y

```bash
git tag -a v0.2.0 -m "..." && git push --follow-tags
./deploy.sh v0.2.0
```

`deploy.sh` se niega a instalar un tag que no coincide con el manifest.

Las reglas son JavaScript puro sin imports de QML, así que se testean con
`node` sin levantar el shell.

## Licencia

MIT.
