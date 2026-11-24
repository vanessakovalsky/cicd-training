#!/usr/bin/env bash
# Module 04 : copie dans le depot local du stagiaire le code livre "sans tests"
# (API devis, depot SQLite) et le test instable tests/test_numerotation.py.
# Usage : scripts/m04/labs/installer-depart.sh <CHEMIN_DEPOT_LOCAL>
set -euo pipefail
RACINE="$(cd "$(dirname "$0")/../../.." && pwd)"
CIBLE="${1:?chemin du clone local de fretexpress}"
[ -d "$CIBLE/.git" ] || { echo "Pas un depot Git : $CIBLE" >&2; exit 1; }
if [ ! -f "$CIBLE/src/fretexpress/tarification.py" ]; then
  echo "Module 03 absent de $CIBLE (branche $(git -C "$CIBLE" branch --show-current)) :" >&2
  echo "  - travail du module 03 sur une autre branche : la fusionner dans main (merge request), puis git pull ;" >&2
  echo "  - sinon : $RACINE/scripts/m03/catch-up/catch-up.sh, puis git pull dans $CIBLE." >&2
  exit 1
fi
cp -r "$RACINE/fil-rouge/depart/m04/." "$CIBLE/"
echo "Copies : src/fretexpress/api.py, src/fretexpress/devis.py, tests/test_numerotation.py"
