# Atom — especificación del personaje

La referencia visual viva es [`perro.html`](perro.html) (abrilo en un
navegador): ahí están las cuatro poses animadas, el ciclo de ocio y la regla
de los huecos, funcionando. Este documento fija los números para que la
implementación en QML sea una transcripción y no una reinterpretación.

---

## 1. Identidad

Un perro de perfil mirando a la derecha: **cuerpo largo, patas cortas, orejas
caídas**. Ni raza concreta ni realismo — las proporciones están elegidas para
sobrevivir a 20 px de alto.

| Decisión | Por qué |
|---|---|
| Perfil, no de frente | Un perro de frente no puede caminar. Se pierde el mirar a los ojos, se gana postura. |
| Patas cortas y cuerpo largo | Un perro de proporciones realistas a 20 px son cuatro rayitas temblando. |
| Orejas caídas | Rompen la silueta de la cabeza y son una pieza animable. |
| Cola siempre visible | Es el medidor de ánimo: lo que más se lee de lejos. |
| Patas del fondo al 45% | Profundidad sin una línea nueva. |
| Cuerpo relleno con el color de la barra | Las patas del fondo quedan detrás; la silueta se lee limpia. |

## 2. Sistema de coordenadas

**`viewBox` de 34 × 24 unidades. Piso en `y = 21`. Mira a la derecha.**

Todas las poses comparten ese marco. Caminar hacia la izquierda es
`scaleX(-1)` sobre el conjunto, nunca un dibujo aparte.

Tamaño de render: **28 × 20 px** en una barra de 26 px de alto.

> **Tres correcciones que salieron de implementarlo** (Fase 2):
>
> - **`34 × 24` no entra exacto en `28 × 20`.** Las proporciones son 1.4167 y
>   1.40, así que manda el ancho: `u = 28/34` y el dibujo ocupa 19.76 px de
>   alto. Como el viewBox tiene 3 unidades de aire debajo del piso, a tamaño
>   real las patas apoyan a ~18 px del tope y sobran ~2 px. Para que apoye en
>   el borde de la barra hay que recortar el viewBox a 22 de alto, o
>   renderizar a 28 × 18.
> - **El piso `y = 21` es conceptual.** Las patas terminan en `y2 = 20.8` y la
>   punta redonda agrega media línea: el apoyo real cae en 21.85.
> - **La respiración no se ve a tamaño real.** −0.35 u son 0.29 px y el
>   `scaleY 1.02` sobre el cuerpo son 0.13 px, y cuesta ~2.3 % de un core.
>   Es un gesto para tamaños grandes; en la barra conviene evaluar apagarla.

### Piezas y pivotes

| Pieza | Posición (unidades) | Pivote |
|---|---|---|
| cuerpo | `rect 5.4, 8.8, 17.6 × 7.8, r 3.9` | `14, 17` (respiración) |
| cabeza | `circle 24.8, 8, r 3.9` | — |
| hocico | `rect 26.8, 7.6, 5.3 × 3.7, r 1.6` | — |
| nariz | `circle 31.5, 8.7, r 0.78` (relleno) | — |
| ojo | `circle 25.3, 7.1, r 0.85` (relleno) | — |
| — | *la oreja llega a x≈25.4 y tapa el ojo: a tamaño real el ojo no se lee. Es así también en el prototipo aprobado; el ojo es detalle de tamaño grande, no parte de la silueta.* | |
| oreja | `ellipse 23.2, 7.7, 1.55 × 3.1, rot −11°` | `23.2, 4.8` |
| cola | `path M6.4 10.2 q−3.2 −.6 −3.1 −4.3` | `6.2, 10.2` |
| pata del. cercana | `line 21.2, 15.4 → 20.8` | `21.2, 15.4` |
| pata del. lejana | `line 19.4, 15.4 → 20.6` | `19.4, 15.4` |
| pata tras. cercana | `line 10.4, 15.4 → 20.8` | `10.4, 15.4` |
| pata tras. lejana | `line 8.6, 15.4 → 20.6` | `8.6, 15.4` |

Grosores: cuerpo y cabeza `1.05`, patas `2.1` (con punta redonda), cola `1.7`.

## 3. Las poses

| Pose | `canMove` | Significado | Respiración |
|---|---|---|---|
| `stand` | **no** | fresco, atento, quieto | 3200 ms |
| `walk` | **sí** | yendo a algún lado | — (rebote) |
| `sit` | no | tranqui, esperando | 3800 ms |
| `lie` | no | frito, se rindió | 4600 ms |
| `sleep` | no | no estás | 6000 ms |
| `scratch` | no | se rasca; a veces, estando sentado | 3200 ms |
| `play` | no | te recibe jugando cuando volvés | — |
| `jump` | **sí** | la cabriola: salta de un lado a otro cuando lo tocás | — |
| `pee` | no | le hace pis a un widget | — |

Sobre las cuatro últimas, dicho por quien las dibujó y confirmado mirándolas:

- **`play` es la que mejor se lee a 28×20** — la diagonal del lomo con la cola
  parada es inconfundible.
- **`jump` solo se lee en el aire.** El ciclo tiene 170 ms de apoyo en los que
  es idéntica a `stand`, así que dura 1,2 segundos y se va: más tiempo y
  parece que parpadea.
- **`scratch` no tiene silueta propia**: es `stand` más una manchita que vibra
  bajo la panza. Se lee por el movimiento, no por la forma.
- **El chorro es un arco punteado** que sale de la ingle y cae hacia atrás,
  no gotas cayendo a plomo. Sale del viewBox a propósito: un arco contenido
  adentro del dibujo mide seis píxeles y no se entiende. A tamaño real los
  puntos quedan tan juntos que se leen como una línea — a 28 px eso es lo que
  hay, y el gesto igual se entiende por la dirección.
- **`pee` y `scratch` se parecen** — las dos son algo que sobresale atrás. Se
  distinguen por el lado y por la cola levantada, y el ciclo no las dispara
  juntas.

**`walk` es una pose registrada como cualquier otra, y la única con
`canMove: true`.** Reusa las mismas piezas de `poses/parts/` que `stand` —
mismo dibujo, patas animadas — pero es una entrada propia del registro.

Que `stand` valga `canMove: false` es deliberado y es el corazón de la
invariante: un perro parado tampoco se traslada. Para moverse, primero pasa a
`walk`.

### Animaciones

| Animación | Piezas | Timing |
|---|---|---|
| caminar | patas en contrafase: `fn`+`bf` contra `ff`+`bn`, ±17° | 500 ms, infinito |
| rebote | cuerpo, −0.45 u | 500 ms, en fase con las patas |
| flopear | oreja, −4° a +7° | 500 ms |
| cola alegre | cola, ±13° | 380 ms |
| cola tranquila | cola, ±7° | 1900 ms |
| respirar | cuerpo, −0.35 u + `scaleY 1.02` | según pose |
| parpadear | párpado tapa el ojo | 130 ms, cada 3–7.5 s al azar |
| zzz | dos "z" que flotan y se desvanecen | 3 s, solo en `sleep` |

Cuando habla: cola alegre + orejas flopeando + color acento, 4–5 segundos.

## 4. La invariante de movimiento

> **La `x` solo cambia mientras la pose activa declara `canMove: true`.**

Hoy son dos las que lo declaran: `walk` y `jump`. La regla empezó siendo
"solo cuando camina" y pasó a ser "solo las poses que lo declaran" cuando
apareció la cabriola — un salto que no te lleva a ningún lado no es jugar.

**El mecanismo no cambió ni una línea**, y eso es lo que hace que el cambio
sea barato: el `Mover` siempre le preguntó a la pose activa, nunca a una
lista de nombres. Y lo que importaba sigue igual: sentado, echado, dormido,
rascándose, jugando o haciendo pis, el perro no se desliza. Se verifica sobre
el registro entero:

```
$ omarchy-shell atom invariant
stand=quieto · walk=SE MUEVE · sit=quieto · lie=quieto · sleep=quieto ·
scratch=quieto · play=quieto · jump=SE MUEVE · pee=quieto
```

Concretamente:

1. Para trasladarse, primero pasa a `walk`. **Después** se mueve.
2. Al llegar, primero para el traslado. **Después** cambia de pose.
3. Cualquier cambio de pose congela la posición donde esté.
4. Un pedido de movimiento con una pose que no lo permite **se rechaza**; no
   se encola ni se corrige después.

Es la regla que más fácil se rompe accidentalmente y la que más caro sale:
un perro sentado deslizándose por la barra rompe la ilusión entera. Por eso
`canMove` es un dato de cada pose y el `Mover` lo consulta, en vez de ser una
condición suelta en el que llama.

## 5. Dónde se para

Camina toda la barra; **se detiene solo en los huecos entre widgets**.

```
[☰][1 2 3]·······[domingo 21:47][☀]·······[wifi][vol][⏻]
        └─ hueco ─┘             └─ hueco ─┘
```

- Los huecos se calculan midiendo la barra real, no con posiciones escritas a
  mano: si agregás, sacás o movés un widget, se recalculan solos.
- Un hueco es válido si mide **al menos el ancho del perro**.
- Los widgets pegados se fusionan en un obstáculo solo.
- Cuando elige destino, descarta el hueco donde ya está (a menos que sea el
  único).
- Si no hay ningún hueco válido — barra llena — se queda donde está. No se
  superpone "por esta vez".

### La única excepción: hacerle pis a algo

Uno de cada cuatro paseos no va a un hueco sino **al borde de un widget**, a
hacerle pis. Se acerca por el lado que tenga libre, dándose vuelta si hace
falta, porque la pata que levanta tiene que apuntarle.

El reloj tiene prioridad, y ahí aparece la única excepción a la regla de no
detenerse encima de un widget: con el formato `dddd HH:mm` el reloj queda
**encajonado** entre los indicadores y el clima, sin un píxel libre al lado,
así que respetando la regla sería inalcanzable para siempre. Hacerle pis dura
cuatro segundos y la pose no deja dudas de que es a propósito — no es un
lugar donde se queda a vivir. Para cualquier otro objetivo la regla sigue
entera: solo se elige si el lugar está limpio.

### Cinco formas de pasear, sorteadas

Cada vez que decide moverse, Atom saca una al azar:

| Paseo | Qué hace |
|---|---|
| `stop` | se muda al hueco de al lado, sin hacer un número |
| `endToEnd` | cruza la barra entera, se queda un momento, y vuelve |
| `wrap` | **sale por un borde de la pantalla y entra por el otro** |
| `patrol` | hace la ronda parando en cada hueco un par de segundos |
| `dash` | se manda una corrida rápida hasta la otra punta y vuelve |

La vuelta por el borde no tiene truco: la ventana de Atom ocupa el ancho
completo de la pantalla, así que salir de cuadro es caminar un poco más allá
del borde. El salto al otro lado ocurre cuando ya no se lo ve.

Todo esto lo arma `brain/Trips.js`, que es JS puro: un viaje es una lista de
tramos con destino, velocidad, pose y pausas, y el servicio los ejecuta de a
uno. Es el único lugar del proyecto que mueve al perro.

### Cuando el hueco se mueve solo

El reloj cambia de ancho cada minuto (`dddd HH:mm`: "miércoles" mide bastante
más que "lunes"), así que el hueco donde Atom está sentado puede invalidarse
sin que él se mueva. Eso enfrenta a dos criterios: no trasladarse sin
caminar, y no quedar encima de un widget.

**Gana la invariante de movimiento.** Cuando el hueco activo se invalida,
Atom *se levanta, camina* hasta un hueco válido y recién ahí se vuelve a
sentar. Nunca se recoloca de prepo. Si no hay a dónde ir, se queda parado
donde está hasta que aparezca un hueco.

La mecánica de medición, con sus tres capas de degradación, está en
[`ARQUITECTURA.md`](ARQUITECTURA.md) §7.

## 6. El ciclo de ocio

Lo que hace cuando no pasa nada:

```
  camina ──► parado ──6 s──► sentado ──14 s──► echado ──ausente──► durmiendo
     ▲                                                                  │
     └──────────── algo que decir, o volvés al teclado ◄────────────────┘
```

- **camina → parado**: al llegar al hueco elegido.
- **parado → sentado**: 6 s sin novedad.
- **sentado → echado**: 14 s más.
- **echado → durmiendo**: solo si estás realmente ausente (3 min sin teclado).
- **cualquiera → parado**: cuando tiene algo que decir, o cuando volvés.

La tabla vive en `brain/Behavior.js` y se amplía agregando filas
([`EXTENDER.md`](EXTENDER.md) §5).

## 7. Color

El color sale del tema de Omarchy; el personaje no tiene paleta propia.

| Estado | Color |
|---|---|
| normal | `foreground` de la barra |
| atento (pasó el umbral de pausa) | `yellow` / warning del tema |
| frito (pasó el umbral de maratón) | `red` del tema |
| ausente o dormido | `muted` |
| silenciado | gris apagado, sin animaciones |
| hablando | `accent` |

La postura es el canal principal; **el color acompaña, no reemplaza**. Tiene
que leerse bien en un tema monocromático.

## 8. Interacción

| Acción | Qué hace |
|---|---|
| click | le pedís un comentario ahora (regla `ondemand`) |
| click derecho | lo silenciás / lo despertás |
| click del medio | "acabo de volver de una pausa": reinicia los relojes |
| hover | tooltip con los dos relojes: `herdr · 47 min · sesión 1 h 52` |

El globo de diálogo aparece debajo de donde esté parado, dura ~14 s, y **no
toma foco de teclado** (`keyboardFocus: None`, sin *focus grab*).
