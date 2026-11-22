#!/usr/bin/env bash
# Nettoyage complet d'un poste local (ou d'une VM) en fin de formation :
# conteneurs deployes, pile, volumes, images de la formation, secrets generes.
# Usage : scripts/setup/nettoyer-poste.sh [--garder-images]
set -euo pipefail
RACINE="$(cd "$(dirname "$0")/../.." && pwd)"
"$RACINE/scripts/m07/cleanup/cleanup.sh" || true
cd "$RACINE/environnement"
JENKINS_ADMIN_PASSWORD=x JENKINS_AGENT_SSH_PUBKEY=x docker compose --profile complet down -v --remove-orphans
if [ "${1:-}" != "--garder-images" ]; then
  grep -Ev '^\s*(#|$)' "$RACINE/scripts/setup/images.txt" | xargs -r docker image rm 2>/dev/null || true
  docker images --format '{{.Repository}}:{{.Tag}}' | grep '^localhost:3000/dev/fretexpress' \
    | xargs -r docker image rm || true
fi
rm -rf "$RACINE/environnement/secrets" "$RACINE/environnement/.env" \
       "$RACINE/environnement/acces.txt" "$RACINE/environnement/jenkins/casc"
echo "Poste nettoye."
