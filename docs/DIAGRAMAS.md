# Diagramas

Cuatro vistas de Atom en UML, escritas en [Mermaid](https://mermaid.js.org/)
para que GitHub las dibuje y vivan en el mismo diff que el código. Si cambiás
lo que muestra un diagrama, se actualiza en el mismo PR.

| Diagrama | Responde | Fuente de verdad |
|---|---|---|
| [Estados](#1-estados-qué-pose-cuándo) | ¿qué pose toca y por qué? | `brain/Behavior.js` (`IDLE`) y `Service.qml` (viajes, click) |
| [Secuencia](#2-secuencia-cómo-decide-hablar) | ¿cómo llega una frase al globo? | `Service.qml` (`maybeSpeak`, `maybePrefetch`), `voice/` |
| [Componentes](#3-componentes-quién-conoce-a-quién) | ¿quién conoce a quién? | `plugin/` |
| [Despliegue](#4-despliegue-dónde-corre-cada-cosa) | ¿dónde corre cada cosa? | `deploy.sh`, `manifest.json` |
| [Pomodoro](#5-pomodoro-solo-si-lo-pedís) | ¿cómo se elige y qué hace? | `brain/Pomodoro.js`, `Service.qml` |

La prosa con el porqué de cada decisión sigue en [ARQUITECTURA.md](ARQUITECTURA.md).

## 1. Estados: qué pose cuándo

El cerebro evalúa la tabla `IDLE` una vez por segundo (`brainTimer`) y gana la
primera fila que aplica. Los tiempos son cuánto lleva en la pose actual.

```mermaid
stateDiagram-v2
    direction LR
    [*] --> stand

    stand --> sit : 6 s quieto
    sit --> lie : 14 s
    sit --> scratch : 9 s, 35 %
    scratch --> sit : 1.6 s
    lie --> sleep : te fuiste
    sleep --> play : volviste
    play --> stand : 2.6 s

    lie --> walk : 10 min aburrido, 3 de cada 4
    lie --> pee : 10 min aburrido, 1 de cada 4
    walk --> stand : llegó al hueco
    pee --> stand : 4.2 s y vuelve

    stand --> jump : click
    jump --> stand : aterriza

    note right of play
        Desde cualquier pose:
        hablar lleva a stand,
        volver al teclado a play.
    end note
    note left of walk
        Solo walk y jump se trasladan
        (la invariante, sección 5).
        Desde sit, lie o sleep pasa
        primero por stand.
    end note
```

Detalles que el dibujo simplifica:

- **El click no está en la tabla.** Tiene que responder al instante y la
  tabla corre una vez por segundo, así que lo maneja `Service.onDemand()`: la
  cabriola sale desde cualquier pose y además pide una frase. Dos
  excepciones: si está mudo, el click solo lo despierta (ni salto ni frase);
  si ya está hablando, salta pero no pide otra.
- **El pis reemplaza al paseo, no lo sigue.** Cuando la tabla pide `walk`,
  una de cada cuatro veces `Service` intenta `goPee()` en su lugar, y si no
  hay dónde, pasea.
- **`walk` es un viaje, no una pose suelta.** `Trips.js` arma los tramos
  (mudarse de hueco, punta a punta, la vuelta por el borde, la ronda, la
  corrida) y `Service.runNextLeg()` los ejecuta. Al terminar el último tramo
  vuelve a `stand`.
- **`pee` y `jump` también son viajes**: `pee` se queda 4.2 s en el lugar y
  vuelve a un hueco; `jump` es la cabriola, un salto y un rebote.

## 2. Secuencia: cómo decide hablar

El caso normal: la regla `stretch` va a disparar a los 45 minutos y la frase
se pide 3 minutos antes, para que el globo salga sin esperar a Claude.

```mermaid
sequenceDiagram
    autonumber
    participant T as brainTimer (1 s)
    participant S as Service
    participant Se as Sensors
    participant R as Rules.js
    participant V as Voice.qml
    participant A as atom-say
    participant C as claude -p
    participant B as Bubble

    T->>S: tick()
    S->>Se: context()
    Se-->>S: app, streakMinutes 42, sessionMinutes…

    Note over S: maybeSpeak: ninguna regla dispara todavía
    S->>R: pick(contexto + 3 min)
    R-->>S: stretch
    S->>V: request(stretch, futuro)
    V->>A: --timeout 90 --model haiku {json}
    A->>C: prompt con personalidad e historial

    alt responde a tiempo
        C-->>A: frase
        A-->>V: frase saneada (exit 0)
        V-->>S: said(stretch, frase, "claude")
    else timeout, sin red o sin claude
        A-->>V: exit ≠ 0
        V->>R: fallback(stretch)
        R-->>V: frase del banco local
        V-->>S: said(stretch, frase, "local")
    end
    Note over S: prefetched[stretch] = frase

    T->>S: tick() (3 min después)
    S->>R: pick(contexto)
    R-->>S: stretch
    S->>B: show(frase) y pose stand
    Note over B: bubbleSeconds (14 s) y se cierra
```

Lo que no se ve en el dibujo:

- **Antes de `pick` hay cuatro filtros**: si está mudo, si estás lejos del
  teclado, si el globo todavía está abierto, o si habló hace menos de
  `quietMinutes` (20), no habla. En el último caso igual aprovecha para
  anticipar.
- **Si la frase no estaba lista** cuando la regla dispara, se pide en el
  momento y el globo sale cuando llegue. Es el mismo camino que sigue el click
  (regla `ondemand`).
- **Con `useClaude: false`**, `Voice` va directo al banco local sin lanzar
  ningún proceso.

## 3. Componentes: quién conoce a quién

UML tiene un diagrama de componentes, pero Mermaid no; este es un flowchart
con la misma idea. Las flechas son "usa" o "le habla a".

```mermaid
flowchart LR
    subgraph shell["omarchy-shell (Quickshell)"]
        direction LR
        BW["BarWidget.qml<br/>presencia en la barra"]

        subgraph svc["Service.qml · el cerebro"]
            direction TB
            Tick["brainTimer · tick()"]
            Trip["viajes · runNextLeg()"]
            IPC["IpcHandler · omarchy-shell atom …"]
        end

        subgraph sens["sensors/"]
            Agg["Sensors.qml · agregador"]
            Foc["FocusSensor"]
            Idl["IdleSensor"]
            Clk["ClockSensor"]
        end

        subgraph brain["brain/ · JS puro, testeado con node"]
            Rul["Rules.js<br/>cuándo hablar"]
            Beh["Behavior.js<br/>qué pose"]
            Gap["Gaps.js<br/>huecos de la barra"]
            Trp["Trips.js<br/>tramos de un viaje"]
            Clo["Clocks.js<br/>rachas y pausas"]
        end

        subgraph body["cuerpo"]
            Mov["Mover.qml<br/>la x"]
            Atm["Atom.qml<br/>renderer"]
            Pos["poses/*.qml + Poses.js"]
            Bub["Bubble.qml"]
        end

        Voi["voice/Voice.qml"]
    end

    Probe(["focus-probe<br/>python"])
    Say(["atom-say<br/>python"])
    Cl(["claude -p"])
    Hypr(["Hyprland<br/>hyprctl, ToplevelManager, IdleMonitor"])
    St[("~/.local/state/atom/<br/>state.json")]

    BW --> svc
    Tick --> Agg
    Agg --> Foc & Idl & Clk
    Foc --> Probe
    Foc & Idl --> Hypr
    Probe --> Hypr
    Tick --> Rul & Beh & Clo
    Trip --> Gap & Trp
    Trip --> Mov
    Tick --> Voi
    Voi --> Rul
    Voi --> Say --> Cl
    Mov -- "pregunta canMove" --> Atm
    Atm --> Pos
    svc --> Bub
    Clo -. persiste .-> St
```

Las reglas que el dibujo debería dejar claras:

- **`brain/` no importa QML.** Por eso se testea con `node` pelado y por eso
  el CI no necesita una barra.
- **El renderer no conoce ninguna pose por su nombre**: carga lo que diga
  `Poses.js`. El `Mover` le pregunta a la pose activa si puede trasladarse.
- **Los dos procesos externos son de Python y nunca fallan hacia arriba**:
  ante un problema, `focus-probe` imprime `{}` y `atom-say` sale con error,
  y en los dos casos Atom sigue con lo que tiene.

## 4. Despliegue: dónde corre cada cosa

```mermaid
flowchart TB
    subgraph gh["GitHub · leono81/atom-cito"]
        Main["main"]
        Tags["tags v0.1.0, v0.1.1, …"]
        CI["Actions · tests.yml<br/>node + plugin/tests"]
        Main --> CI
    end

    subgraph pc["la máquina"]
        Repo["~/Projects/atom<br/>el clon"]
        Dep{{"deploy.sh"}}
        Inst["~/.config/omarchy/plugins/leono.atom"]
        Cfg["~/.config/omarchy/shell.json<br/>los ajustes"]
        State[("~/.local/state/atom/")]
        Shell["omarchy-shell"]
    end

    Claude(["API de Claude<br/>vía claude -p"])

    Repo <-- "push / pull" --> Main
    Tags --> Repo
    Repo --> Dep
    Dep -- "./deploy.sh vX.Y.Z<br/>copia fija del tag" --> Inst
    Dep -. "./deploy.sh dev<br/>symlink al repo" .-> Inst
    Dep -- "omarchy restart shell" --> Shell
    Shell -- carga --> Inst
    Shell -- lee --> Cfg
    Shell -- "relojes" --> State
    Shell -- "frases, si useClaude" --> Claude
```

- **Lo que corre en la barra es siempre un tag**, salvo en modo `dev`.
  `./deploy.sh` a secas dice cuál.
- **El estado vive afuera del plugin**, así que cambiar de versión, o volver a
  una anterior, no pierde los relojes.
- **Lo único que sale de la máquina** es el pedido de frase a Claude, y se
  apaga con `useClaude: false`. Ver [privacidad](../MANIFIESTO.md#7-privacidad).

## 5. Pomodoro: solo si lo pedís

Dos máquinas: el selector, que dura unos segundos mientras elegís, y el ciclo.
Atom nunca entra a ninguna de las dos por su cuenta.

```mermaid
stateDiagram-v2
    direction LR
    [*] --> off

    off --> eligiendo : scroll sobre el perro
    eligiendo --> eligiendo : scroll, ±5 min
    eligiendo --> off : 6 s sin tocar, sacar el puntero o dos dedos
    eligiendo --> foco : tap

    foco --> descanso : terminó el foco
    descanso --> off : terminó el descanso
    foco --> off : dos dedos, dos veces
    descanso --> off : dos dedos, dos veces

    note right of foco
        Echado y callado: las reglas
        no hablan y no pasea.
    end note
    note right of descanso
        Pasea como siempre,
        pero tampoco habla.
    end note
```

- **El estado se guarda** en `~/.local/state/atom/pomodoro.json`, así que un
  reinicio del shell no corta el foco. Si las dos etapas terminaron con el
  shell apagado, pasa a `off` sin anunciar nada.
- **Ladra** al arrancar (`bark-ok`), dos veces al terminar el foco y una al
  terminar el descanso (`bark-alert`), con `pw-play`. En mudo, no.
- **Las frases son fijas** y viven en `Pomodoro.js`: la cancelación pasa en el
  momento y no da tiempo a pedirle nada a Claude.
- **Con el puntero encima se queda quieto**, incluso a mitad de un paseo: un
  blanco de 28 px que camina es imposible de agarrar con touchpad. Para eso el
  área sensible lo sigue a 4 Hz mientras camina, y mientras elegís se agranda
  a perro + selector.
