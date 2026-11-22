#!/usr/bin/env bash
# Genere un historique de deploiements pour la mesure DORA (module 10) :
# N petits commits sur main, chacun suivi du pipeline complet (recette approuvee
# automatiquement par recette1), dont un incident de production simule puis corrige.
# Duree : environ 2 min par commit. Usage : scripts/setup/generate-dora-history.sh [N]
set -euo pipefail
. "$(dirname "$0")/../lib/commun.sh"

N="${1:-6}"
INCIDENT=$(( N / 2 ))
J="$JENKINS_URL/job/fretexpress/job/main"
MDP_RECETTE="$(cat "$ENV_DIR/secrets/utilisateurs_password" 2>/dev/null || true)"
[ -n "$MDP_RECETTE" ] || erreur "Module 09 non rattrape (secrets/utilisateurs_password absent)"

dernier_build() { curl -s -u "admin:$JENKINS_ADMIN_PASSWORD" "$J/lastBuild/api/json?tree=number" \
  | sed -n 's/.*"number":\([0-9]*\).*/\1/p'; }

approuver_et_attendre() { # approuver_et_attendre NUMERO
  local n="$1" _
  for _ in $(seq 1 120); do
    if curl -s -u "admin:$JENKINS_ADMIN_PASSWORD" "$J/$n/consoleText" | grep -q 'Deployer en recette or Abort'; then
      local cookies crumb; cookies="$(mktemp)"
      crumb="$(curl -s -c "$cookies" -u "recette1:$MDP_RECETTE" \
        "$JENKINS_URL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)")"
      curl -s -o /dev/null -b "$cookies" -u "recette1:$MDP_RECETTE" -H "$crumb" -X POST \
        "$J/$n/input/Recette/proceedEmpty"
      rm -f "$cookies"
      info "Build #$n : recette approuvee par recette1"
      break
    fi
    curl -s -u "admin:$JENKINS_ADMIN_PASSWORD" "$J/$n/api/json?tree=building" | grep -q '"building":false' && break
    sleep 5
  done
  until curl -s -u "admin:$JENKINS_ADMIN_PASSWORD" "$J/$n/api/json?tree=building" | grep -q '"building":false'; do
    sleep 5
  done
  info "Build #$n : $(curl -s -u "admin:$JENKINS_ADMIN_PASSWORD" "$J/$n/api/json?tree=result,description" \
    | sed 's/.*"description":"\{0,1\}\([^",]*\)"\{0,1\},.*"result":"\([A-Z]*\)".*/\2 (\1)/')"
}

TRAVAIL="$(mktemp -d)"
git clone -q "http://dev:$GITEA_DEV_PASSWORD@localhost:3000/dev/$DEPOT.git" "$TRAVAIL/d"
for i in $(seq 1 "$N"); do
  avant="$(dernier_build)"
  (
    cd "$TRAVAIL/d"
    git pull -q
    echo "- $(date -u +%Y-%m-%dT%H:%M:%SZ) : changement $i (historique DORA)" >> CHANGELOG.md
    message="docs: changement $i"
    if [ "$i" -eq "$INCIDENT" ]; then
      touch deploy/.simuler-echec-prod; message="feat: changement $i (incident simule)"
    elif [ -f deploy/.simuler-echec-prod ]; then
      git rm -q deploy/.simuler-echec-prod; message="fix: correction de l'incident"
    fi
    git add -A
    git -c user.name=dev -c user.email=dev@fretexpress.localhost commit -q -m "$message"
  )
  protection="$(gitea_api GET "/repos/dev/$DEPOT/branch_protections/main" || true)"
  gitea_code DELETE "/repos/dev/$DEPOT/branch_protections/main" >/dev/null || true
  git -C "$TRAVAIL/d" push -q origin main 2>/dev/null
  printf '%s' "$protection" | grep -q '"rule_name"' \
    && gitea_api POST "/repos/dev/$DEPOT/branch_protections" "$protection" >/dev/null
  info "Commit $i/$N pousse"
  for _ in $(seq 1 30); do [ "$(dernier_build)" != "$avant" ] && break; sleep 3; done
  approuver_et_attendre "$(dernier_build)"
done
rm -rf "$TRAVAIL"
info "Historique genere : python3 scripts/m10/labs/dora.py (JENKINS_TOKEN requis)"
