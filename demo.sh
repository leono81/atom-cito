#!/usr/bin/env bash
#
# Demo de Atom, pensada para filmar.
#
# Pasa por todo lo que el perro sabe hacer, en orden y con carteles grandes en
# la terminal para que se entienda qué mirar. Dura unos dos minutos.
#
#   ./demo.sh           la demo entera
#   ./demo.sh 7         solo el acto 7
#   ./demo.sh --list    qué actos hay
#
# Para filmar: dejá esta terminal ocupando la mitad de abajo de la pantalla y
# apuntá el celular a la pantalla entera — arriba la barra con el perro, abajo
# el cartel que dice qué está pasando.

set -uo pipefail

ATOM="omarchy-shell atom"

# Colores del tema Retro 82.
ARENA=$'\e[38;5;223m'
NARANJA=$'\e[38;5;215m'
TEAL=$'\e[38;5;73m'
TENUE=$'\e[38;5;66m'
NEGRITA=$'\e[1m'
FIN=$'\e[0m'

ancho=$(tput cols 2>/dev/null || echo 80)
[ "$ancho" -gt 92 ] && ancho=92

# Ojo: `tr` trabaja byte a byte y destroza los caracteres de caja, que son
# multibyte. Se repiten con printf, que sí los respeta.
linea() { local c="$1" i out=''; for ((i = 0; i < ancho; i++)); do out+="$c"; done; printf '%s' "$out"; }

banner() { # banner <n> <título> <qué mirar>
  local n="$1" titulo="$2" mirar="$3"
  printf '\n\n%s%s%s\n' "$NARANJA" "$(linea '━')" "$FIN"
  printf '%s%s  %s · %s%s\n' "$NEGRITA" "$NARANJA" "$n" "$titulo" "$FIN"
  printf '%s  %s%s\n' "$TEAL" "$mirar" "$FIN"
  printf '%s%s%s\n' "$NARANJA" "$(linea '━')" "$FIN"
}

dato() { printf '%s     %s%s\n' "$TENUE" "$1" "$FIN"; }

# Espera mostrando puntos, para que se vea que algo está pasando.
esperar() {
  local s="$1"
  printf '%s     ' "$TENUE"
  for ((i = 0; i < s; i++)); do printf '·'; sleep 1; done
  printf '%s\n' "$FIN"
}

vivo() {
  if [ "$($ATOM ping 2>&1)" != "ok" ]; then
    printf '%s\n  Atom no está corriendo.%s\n' "$NARANJA" "$FIN"
    printf '  Habilitalo con:  omarchy plugin enable leono.atom right\n\n'
    exit 1
  fi
}

# ── Los actos ───────────────────────────────────────────────────────────────

acto1() {
  banner 1 "Vive en la barra" "Buscá al perro arriba. Respira, parpadea, y se queda en un hueco."
  $ATOM pose stand >/dev/null
  esperar 4
  dato "Y sabe cuánto hace que estás en lo mismo:"
  $ATOM hover 6 >/dev/null
  esperar 6
}

acto2() {
  banner 2 "Sabe en qué estás trabajando" "No mira el título de la ventana: mira el árbol de procesos."
  local ctx
  ctx=$($ATOM context 2>/dev/null)
  python3 - "$ctx" <<'PY' 2>/dev/null || true
import json, sys
c = json.loads(sys.argv[1])
app = c.get("appId") or "(la ventana no reporta appId)"
print("\033[38;5;223m     app enfocada      %s\033[0m" % app)
print("\033[38;5;66m     título            %s\033[0m" % ((c.get("title") or "(nada)")[:54]))
print("\033[1m\033[38;5;215m     lo que ve Atom    %s\033[0m" % c.get("app", "?"))
if c.get("agents"):
    print("\033[38;5;73m     agentes adentro   %s\033[0m" % c["agents"])
print("\033[38;5;66m     racha             %s min   ·   sesión %s min\033[0m"
      % (c.get("streakMinutes", 0), c.get("sessionMinutes", 0)))
PY
  esperar 7
}

acto3() {
  banner 3 "Conoce los huecos de tu barra" "Mide los widgets en vivo. Nunca se detiene encima de ninguno."
  # El JSON va por argv, NO por pipe: el heredoc ya ocupa stdin y le gana al
  # pipe, así que `json.load(sys.stdin)` leería el vacío. Pasó exactamente eso
  # la primera vez que se corrió la demo, y el `|| true` se lo tragó.
  local geo
  geo=$($ATOM geometry 2>/dev/null)
  python3 - "$geo" <<'PY' 2>/dev/null || true
import json, sys
g = json.loads(sys.argv[1])
obs = sorted(g["obstacles"], key=lambda o: o["x"])
pad, cur, gaps, merged = 6, 2, [], []
for o in obs:
    a, b = o["x"] - pad, o["x"] + o["w"] + pad
    if merged and a <= merged[-1][1]: merged[-1][1] = max(merged[-1][1], b)
    else: merged.append([a, b])
for a, b in merged:
    if a - cur >= 28: gaps.append((cur, a))
    cur = max(cur, b)
if g["barWidth"] - 2 - cur >= 28: gaps.append((cur, g["barWidth"] - 2))
print("\033[38;5;223m     %d widgets medidos en una barra de %d px\033[0m" % (len(obs), g["barWidth"]))
for a, b in gaps:
    print("\033[38;5;215m     hueco libre       %d → %d   (%d px)\033[0m" % (a, b, b - a))
PY
  $ATOM walk stop >/dev/null
  esperar 6
}

acto4() {
  banner 4 "Paseo: de punta a punta" "Cruza la barra entera y vuelve."
  $ATOM walk endToEnd >/dev/null
  esperar 12
}

acto5() {
  banner 5 "Paseo: la ronda" "Visita los huecos uno por uno, parando en cada uno."
  $ATOM walk patrol >/dev/null
  esperar 13
}

acto6() {
  banner 6 "Paseo: la corrida" "Casi siempre está quieto. Cuando se manda, se nota."
  $ATOM walk dash >/dev/null
  esperar 8
}

acto7() {
  banner 7 "Paseo: la vuelta al mundo" "Sale por un borde de la pantalla y entra por el otro."
  $ATOM walk wrap >/dev/null
  esperar 12
}

acto8() {
  banner 8 "La cabriola" "Un salto grande y un rebote al caer. Es lo que hace cuando lo clickeás."
  $ATOM cabriola >/dev/null
  esperar 4
  $ATOM cabriola >/dev/null
  esperar 4
}

acto9() {
  banner 9 "Qué hace cuando no pasa nada" "Llega, se queda parado, se sienta, se rasca, se acuesta."
  $ATOM pose stand >/dev/null;   dato "parado";     esperar 3
  $ATOM pose sit >/dev/null;     dato "sentado";    esperar 3
  $ATOM pose scratch >/dev/null; dato "rascándose"; esperar 3
  $ATOM pose lie >/dev/null;     dato "echado";     esperar 3
  $ATOM pose sleep >/dev/null;   dato "dormido — esto solo pasa si te vas del teclado"; esperar 4
  $ATOM pose stand >/dev/null
}

acto10() {
  banner 10 "Le hace pis al reloj" "Camina hasta el borde del reloj, levanta la pata, y se va."
  dato "$($ATOM pee 2>&1)"
  esperar 13
}

acto11() {
  banner 11 "Te habla" "Las reglas deciden cuándo; Claude escribe qué. Tarda unos segundos."
  $ATOM say stretch >/dev/null
  local antes ahora
  antes=$(journalctl --user -n 60 --no-pager 2>/dev/null | grep -c "\[atom\] dice")
  for ((i = 0; i < 40; i++)); do
    ahora=$(journalctl --user -n 60 --no-pager 2>/dev/null | grep -c "\[atom\] dice")
    if [ "$ahora" -gt "$antes" ]; then
      printf '%s     %s%s\n' "$ARENA" \
        "$(journalctl --user -n 20 --no-pager 2>/dev/null | grep -o '\[atom\] dice.*' | tail -1 | sed 's/\[atom\] dice //')" "$FIN"
      break
    fi
    printf '%s·%s' "$TENUE" "$FIN"
    sleep 1
  done
  esperar 8
}

acto12() {
  banner 12 "Lo podés callar" "Click derecho. Se apaga el color y se le paran las animaciones."
  dato "$($ATOM mute 2>&1)"
  esperar 5
  dato "$($ATOM mute 2>&1)"
  esperar 3
}

acto13() {
  banner 13 "La regla que no se negocia" "Solo las poses que lo declaran pueden trasladarse."
  # En una línea sola no entra: se parte para que se lea en cámara.
  $ATOM invariant 2>&1 | tr '·' '\n' | while read -r l; do
    [ -z "$l" ] && continue
    case "$l" in
      *"SE MUEVE"*) printf '%s     %s%s\n' "$NEGRITA$NARANJA" "$l" "$FIN" ;;
      *)            printf '%s     %s%s\n' "$ARENA" "$l" "$FIN" ;;
    esac
  done
  dato "Sentado, echado o dormido, el perro no se desliza. Nunca."
  esperar 7
}

ACTOS=(acto1 acto2 acto3 acto4 acto5 acto6 acto7 acto8 acto9 acto10 acto11 acto12 acto13)

titulos=(
  "Vive en la barra" "Sabe en qué estás" "Conoce los huecos"
  "De punta a punta" "La ronda" "La corrida" "La vuelta al mundo"
  "La cabriola" "El ciclo de ocio" "Le hace pis al reloj"
  "Te habla" "Lo podés callar" "La regla dura"
)

if [ "${1:-}" = "--list" ]; then
  printf '\n'
  for i in "${!titulos[@]}"; do printf '  %2d · %s\n' "$((i + 1))" "${titulos[$i]}"; done
  printf '\n'
  exit 0
fi

vivo

if [ -n "${1:-}" ]; then
  "acto${1}"
  printf '\n'
  exit 0
fi

clear
printf '\n%s%s' "$NEGRITA$ARENA" "$(linea ' ')"
printf '\n\n   %sA T O M%s\n' "$NEGRITA$NARANJA" "$FIN"
printf '   %sun perro que vive en la barra%s\n\n' "$TENUE" "$FIN"
printf '   %sPrendé la cámara. Arranca en...%s ' "$TEAL" "$FIN"
for i in 5 4 3 2 1; do printf '%s%d %s' "$NARANJA" "$i" "$FIN"; sleep 1; done
printf '\n'

for a in "${ACTOS[@]}"; do "$a"; done

printf '\n\n%s%s%s\n' "$NARANJA" "$(linea '━')" "$FIN"
printf '%s  Eso es todo. Ahora se queda ahí, dando vueltas.%s\n' "$NEGRITA$ARENA" "$FIN"
printf '%s  Si molesta:  omarchy plugin disable leono.atom%s\n' "$TENUE" "$FIN"
printf '%s%s%s\n\n' "$NARANJA" "$(linea '━')" "$FIN"

# Que quede como estaba: hablando y parado.
$ATOM pose stand >/dev/null 2>&1
