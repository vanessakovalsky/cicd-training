#!/usr/bin/env bash
# Rattrapage module 07 : jeton de registre en lecture seule, credential registre-lecture,
# depot a l'etat fin M07 (approbation de la recette par admin).
set -euo pipefail
. "$(dirname "$0")/../../lib/commun.sh"
ICI="$(cd "$(dirname "$0")" && pwd)"

RATTRAPAGE_IMBRIQUE=1 "$RACINE/scripts/m06/catch-up/catch-up.sh"

info "Jeton Gitea 'deploiement' (read:package uniquement)"
gitea_code DELETE /users/dev/tokens/deploiement >/dev/null || true
JETON="$(gitea_api POST /users/dev/tokens '{"name":"deploiement","scopes":["read:package"]}' \
  | sed -n 's/.*"sha1":"\([0-9a-f]*\)".*/\1/p')"
[ -n "$JETON" ] || erreur "Creation du jeton de deploiement impossible"
( umask 077; printf '%s' "$JETON" > "$ENV_DIR/secrets/registre_token" )

jenkins_casc

ETAT="$(mktemp -d)"
etat_fil_rouge 07 "$ETAT/fretexpress"
gitea_pousser_etat "$ETAT/fretexpress" "ci: rattrapage etat fin module 07"
rm -rf "$ETAT"
info "Module 07 rattrape : approuver la recette dans Jenkins (fretexpress > main)"
