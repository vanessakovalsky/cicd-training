#!/usr/bin/env bash
# Rattrapage module 08 : depot fretexpress-pipeline-lib (etiquette v1), bibliotheque
# declaree dans Jenkins, depot fretexpress a l'etat fin M08 (parallele, cache, @Library).
set -euo pipefail
. "$(dirname "$0")/../../lib/commun.sh"
ICI="$(cd "$(dirname "$0")" && pwd)"

RATTRAPAGE_IMBRIQUE=1 "$RACINE/scripts/m07/catch-up/catch-up.sh"

LIB=fretexpress-pipeline-lib
RATTRAPAGE_IMBRIQUE="" gitea_pousser_etat "$FIL_ROUGE/$LIB" "feat: bibliotheque partagee v1" "$LIB"
info "Etiquette v1 sur $LIB"
gitea_code DELETE "/repos/dev/$LIB/tags/v1" >/dev/null || true
gitea_api POST "/repos/dev/$LIB/tags" '{"tag_name":"v1","target":"main","message":"v1"}' >/dev/null
jenkins_casc "$ICI/bibliotheque.yaml"

ETAT="$(mktemp -d)"
etat_fil_rouge 08 "$ETAT/fretexpress"
gitea_pousser_etat "$ETAT/fretexpress" "ci: rattrapage etat fin module 08"
rm -rf "$ETAT"
info "Module 08 rattrape"
