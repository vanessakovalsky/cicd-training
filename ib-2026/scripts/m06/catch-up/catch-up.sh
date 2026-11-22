#!/usr/bin/env bash
# Rattrapage module 06 : SonarQube configure (mot de passe admin, jeton, webhook,
# quality gate FretExpress), credential sonar-token, depot a l'etat fin M06.
# Profil leger : la partie SonarQube est sautee (SONARQUBE_ACTIF=non).
set -euo pipefail
. "$(dirname "$0")/../../lib/commun.sh"
ICI="$(cd "$(dirname "$0")" && pwd)"
SONAR_URL="${SONAR_URL:-http://localhost:9000}"

RATTRAPAGE_IMBRIQUE=1 "$RACINE/scripts/m05/catch-up/catch-up.sh"

if curl -s "$SONAR_URL/api/system/status" | grep -q '"UP"'; then
  if [ -z "${SONAR_ADMIN_PASSWORD:-}" ]; then
    SONAR_ADMIN_PASSWORD="Fx-$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 14 || true)-9"
    curl -sf -u admin:admin -X POST "$SONAR_URL/api/users/change_password" \
      --data-urlencode login=admin --data-urlencode previousPassword=admin \
      --data-urlencode "password=$SONAR_ADMIN_PASSWORD" \
      || erreur "Mot de passe admin SonarQube deja modifie : renseigner SONAR_ADMIN_PASSWORD dans .env"
    echo "SONAR_ADMIN_PASSWORD=$SONAR_ADMIN_PASSWORD" >> "$ENV_DIR/.env"
    info "Mot de passe admin SonarQube enregistre dans .env"
  fi
  sonar() { curl -sS -u "admin:$SONAR_ADMIN_PASSWORD" -X POST "$SONAR_URL/api/$1" "${@:2}"; }

  sonar user_tokens/revoke --data-urlencode name=jenkins >/dev/null
  JETON="$(sonar user_tokens/generate --data-urlencode name=jenkins \
    --data-urlencode type=GLOBAL_ANALYSIS_TOKEN | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"
  [ -n "$JETON" ] || erreur "Jeton SonarQube non genere"
  ( umask 077; printf '%s' "$JETON" > "$ENV_DIR/secrets/sonar_token" )

  if ! curl -s -u "admin:$SONAR_ADMIN_PASSWORD" "$SONAR_URL/api/webhooks/list" | grep -q sonarqube-webhook; then
    sonar webhooks/create --data-urlencode name=jenkins \
      --data-urlencode url=http://jenkins:8080/sonarqube-webhook/ >/dev/null
  fi
  if ! curl -s -u "admin:$SONAR_ADMIN_PASSWORD" "$SONAR_URL/api/qualitygates/list" | grep -q '"FretExpress"'; then
    sonar qualitygates/create --data-urlencode name=FretExpress >/dev/null
    sonar qualitygates/create_condition --data-urlencode gateName=FretExpress \
      --data-urlencode metric=coverage --data-urlencode op=LT --data-urlencode error=80 >/dev/null
    sonar qualitygates/create_condition --data-urlencode gateName=FretExpress \
      --data-urlencode metric=bugs --data-urlencode op=GT --data-urlencode error=0 >/dev/null
    sonar qualitygates/set_as_default --data-urlencode name=FretExpress >/dev/null
  fi
  info "SonarQube configure (jeton, webhook, quality gate FretExpress)"
  jenkins_casc "$ICI/sonar.yaml"
else
  info "SonarQube absent (profil leger) : etapes Sonar desactivees"
fi

ETAT="$(mktemp -d)"
etat_fil_rouge 06 "$ETAT/fretexpress"
gitea_pousser_etat "$ETAT/fretexpress" "ci: rattrapage etat fin module 06"
rm -rf "$ETAT"
info "Module 06 rattrape"
