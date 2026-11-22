#!/usr/bin/env bash
# Rattrapage module 10 : chaine complete (Jenkinsfile final avec marquage echec-prod).
set -euo pipefail
. "$(dirname "$0")/../../lib/commun.sh"

RATTRAPAGE_IMBRIQUE=1 "$RACINE/scripts/m09/catch-up/catch-up.sh"
ETAT="$(mktemp -d)"
etat_fil_rouge 10 "$ETAT/fretexpress"
gitea_pousser_etat "$ETAT/fretexpress" "ci: chaine complete (module 10)"
rm -rf "$ETAT"
info "Module 10 rattrape : approuver la recette du build lance (recette1 ou admin)"
