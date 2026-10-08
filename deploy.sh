#!/usr/bin/env bash
#
# Instala Atom en la barra. Dos modos:
#
#   ./deploy.sh v0.1.0    instala ese tag como copia fija: la barra corre una
#                         versión conocida y lo que edites en el repo no la toca
#   ./deploy.sh dev       symlink al repo, para trabajar sobre el código vivo
#   ./deploy.sh           dice qué está instalado
#
# Volver atrás es instalar el tag anterior. El estado del perro (relojes, etc.)
# vive en ~/.local/state/atom/, afuera del plugin: cambiar de versión no lo
# pierde.
#
# Al terminar reinicia el shell, porque es lo único que recoge código nuevo:
# ver docs/EXTENDER.md, "El ciclo de trabajo".

set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
PLUGINS="$HOME/.config/omarchy/plugins"
DEST="$PLUGINS/leono.atom"
MARCA=".deployed"   # dentro de la copia: qué tag y qué commit son

muere() { echo "deploy: $*" >&2; exit 1; }

estado() {
  if [ -L "$DEST" ]; then
    echo "dev → $(readlink "$DEST")"
  elif [ -f "$DEST/$MARCA" ]; then
    cat "$DEST/$MARCA"
  elif [ -e "$DEST" ]; then
    echo "hay algo en $DEST que no instaló este script"
  else
    echo "no instalado"
  fi
}

# Solo se borra lo que es nuestro: un symlink o una copia con la marca.
sacar_actual() {
  if [ -L "$DEST" ]; then
    rm "$DEST"
  elif [ -f "$DEST/$MARCA" ]; then
    rm -rf "$DEST"
  elif [ -e "$DEST" ]; then
    muere "$DEST existe y no lo instaló este script; no lo toco"
  fi
}

reiniciar() {
  if command -v omarchy >/dev/null 2>&1; then
    omarchy restart shell
  else
    echo "deploy: falta \`omarchy\`; reiniciá el shell a mano" >&2
  fi
}

instalar_tag() {
  local tag="$1" commit version
  commit=$(git -C "$REPO" rev-parse --verify --quiet "$tag^{commit}") \
    || muere "no existe el tag $tag (git tag -l para ver los que hay)"

  # El tag y el manifest tienen que decir lo mismo, o el número no significa nada.
  version=$(git -C "$REPO" show "$tag:plugin/manifest.json" \
    | sed -n 's/.*"version": *"\([^"]*\)".*/\1/p')
  [ "v$version" = "$tag" ] \
    || muere "el tag es $tag pero plugin/manifest.json dice $version"

  mkdir -p "$PLUGINS"
  # Se arma al lado y se cambia de un saque, así la barra nunca ve una copia
  # a medias. Con punto adelante el shell no la toma por un plugin.
  local tmp
  tmp=$(mktemp -d "$PLUGINS/.leono.atom.XXXXXX")
  chmod 755 "$tmp"   # mktemp la crea 700; los demás plugins son 755
  trap 'rm -rf "$tmp"' EXIT
  git -C "$REPO" archive "$tag" plugin | tar -x -C "$tmp" --strip-components=1
  printf '%s · %s · instalado %s\n' "$tag" "${commit:0:7}" "$(date '+%F %R')" \
    > "$tmp/$MARCA"

  sacar_actual
  mv "$tmp" "$DEST"
  trap - EXIT
  echo "instalado $tag en $DEST"
}

instalar_dev() {
  mkdir -p "$PLUGINS"
  sacar_actual
  ln -s "$REPO/plugin" "$DEST"
  echo "dev: $DEST → $REPO/plugin"
}

case "${1:-}" in
  "")      estado; exit 0 ;;
  dev)     instalar_dev ;;
  v*)      instalar_tag "$1" ;;
  -h|--help) sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *)       muere "no entiendo \"$1\"; probá dev, un tag como v0.1.0, o --help" ;;
esac

reiniciar
