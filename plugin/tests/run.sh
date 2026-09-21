#!/usr/bin/env bash
# Corre toda la logica pura del cerebro con node pelado. Sin dependencias, sin
# npm install, sin levantar el shell: ese es el punto de que la logica viva en
# JS puro y no adentro de QML.
#
#   ./run.sh            todo
#   ./run.sh geometry   uno solo
#
# Devuelve 0 si pasa todo. Ningun test llama a `claude` ni toca el escritorio.
set -uo pipefail

cd "$(dirname "$0")" || exit 2

if ! command -v node >/dev/null 2>&1; then
  echo "run.sh: falta node" >&2
  exit 2
fi

if [ $# -gt 0 ]; then
  archivos=()
  for name in "$@"; do archivos+=("${name%.test.js}.test.js"); done
else
  # Descubre solos los .test.js: agregar un modulo no deberia obligar a
  # tocar el runner (y si no, un test nuevo se corre en silencio).
  mapfile -t archivos < <(ls -1 *.test.js | sort)
fi

fallaron=()
for archivo in "${archivos[@]}"; do
  echo ""
  echo "=============================================================== $archivo"
  if ! node "$archivo"; then
    fallaron+=("$archivo")
  fi
done

echo ""
echo "==============================================================="
if [ ${#fallaron[@]} -eq 0 ]; then
  echo "TODO VERDE (${#archivos[@]} archivos)"
  exit 0
fi
echo "FALLARON: ${fallaron[*]}"
exit 1
