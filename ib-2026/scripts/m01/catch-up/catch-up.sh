#!/usr/bin/env bash
# Rattrapage module 01 : depot dev/fretexpress a l'etat final du module 01
# (code de depart + CONTRIBUTING.md), branche main protegee. Relancable.
set -euo pipefail
. "$(dirname "$0")/../../lib/commun.sh"

ETAT="$(mktemp -d)"
etat_fil_rouge 01 "$ETAT/fretexpress"
gitea_pousser_etat "$ETAT/fretexpress" "chore: rattrapage etat fin module 01"
rm -rf "$ETAT"

info "Protection de main (merge request + 1 approbation)"
if [ "$(gitea_code GET "/repos/dev/$DEPOT/branch_protections/main")" != "200" ]; then
  gitea_api POST "/repos/dev/$DEPOT/branch_protections" '{
    "rule_name": "main",
    "enable_push": false,
    "required_approvals": 1,
    "block_on_rejected_reviews": true,
    "dismiss_stale_approvals": true
  }' >/dev/null
fi
info "Collaborateur reviewer (ecriture)"
gitea_code PUT "/repos/dev/$DEPOT/collaborators/reviewer" '{"permission":"write"}' >/dev/null
info "Module 01 rattrape"
