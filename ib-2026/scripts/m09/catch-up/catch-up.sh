#!/usr/bin/env bash
# Rattrapage module 09 : utilisateurs dev1 / recette1 / ops1, roles, journal d'audit,
# sauvegarde de la configuration JCasC exportee. Relancable.
set -euo pipefail
. "$(dirname "$0")/../../lib/commun.sh"
ICI="$(cd "$(dirname "$0")" && pwd)"

RATTRAPAGE_IMBRIQUE=1 "$RACINE/scripts/m08/catch-up/catch-up.sh"

if [ ! -f "$ENV_DIR/secrets/utilisateurs_password" ]; then
  ( umask 077; tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16 > "$ENV_DIR/secrets/utilisateurs_password" || true )
fi
info "Mot de passe de dev1 / recette1 / ops1 : $ENV_DIR/secrets/utilisateurs_password"
cp "$ICI/jenkins.yaml" "$ENV_DIR/jenkins/casc/jenkins.yaml"
jenkins_casc
info "Module 09 rattrape (roles actifs, controleur sans executeur, audit)"
