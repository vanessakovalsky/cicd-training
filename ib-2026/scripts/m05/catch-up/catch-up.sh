#!/usr/bin/env bash
# Rattrapage module 05 : depot a l'etat fin M05 (code M04 + Jenkinsfile), jeton Gitea,
# credential gitea-dev, serveur Gitea, job multibranche, webhook Gitea -> Jenkins.
set -euo pipefail
. "$(dirname "$0")/../../lib/commun.sh"
ICI="$(cd "$(dirname "$0")" && pwd)"

RATTRAPAGE_IMBRIQUE=1 "$RACINE/scripts/m02/catch-up/catch-up.sh"

ETAT="$(mktemp -d)"
etat_fil_rouge 05 "$ETAT/fretexpress"
gitea_pousser_etat "$ETAT/fretexpress" "ci: rattrapage etat fin module 05"
rm -rf "$ETAT"

info "Jeton Gitea 'jenkins' pour l'utilisateur dev"
gitea_code DELETE /users/dev/tokens/jenkins >/dev/null || true
JETON="$(gitea_api POST /users/dev/tokens \
  '{"name":"jenkins","scopes":["write:repository","write:package","write:issue","read:user","read:organization"]}' \
  | sed -n 's/.*"sha1":"\([0-9a-f]*\)".*/\1/p')"
[ -n "$JETON" ] || erreur "Creation du jeton Gitea impossible"

( umask 077; printf '%s' "$JETON" > "$ENV_DIR/secrets/gitea_token" )
jenkins_casc "$ICI/gitea.yaml"
jenkins_groovy "$ICI/multibranche.groovy"

info "Webhook Gitea -> Jenkins"
if ! gitea_api GET "/repos/dev/$DEPOT/hooks" | grep -q 'gitea-webhook/post'; then
  gitea_api POST "/repos/dev/$DEPOT/hooks" '{
    "type": "gitea", "active": true,
    "events": ["push", "pull_request", "create", "delete"],
    "config": {"url": "http://jenkins:8080/gitea-webhook/post", "content_type": "json"}
  }' >/dev/null
fi
info "Module 05 rattrape"
