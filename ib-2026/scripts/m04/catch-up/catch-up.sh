#!/usr/bin/env bash
# Rattrapage module 04 : depot dev/fretexpress a l'etat final du module 04. Relancable.
set -euo pipefail
. "$(dirname "$0")/../../lib/commun.sh"

RATTRAPAGE_IMBRIQUE=1 "$RACINE/scripts/m02/catch-up/catch-up.sh"

ETAT="$(mktemp -d)"
etat_fil_rouge 04 "$ETAT/fretexpress"
gitea_pousser_etat "$ETAT/fretexpress" "test: rattrapage etat fin module 04"
rm -rf "$ETAT"
info "Module 04 rattrape"
