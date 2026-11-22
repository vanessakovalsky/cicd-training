#!/usr/bin/env bash
# Lab 9.2 : restaure une archive dans un volume temporaire et demarre un Jenkins de test
# sur http://localhost:8081 (sans agent ni reseau cicd). Usage :
#   scripts/m09/labs/restauration-test.sh <ARCHIVE.tgz>     restaurer et demarrer
#   scripts/m09/labs/restauration-test.sh --nettoyer        supprimer conteneur et volume
set -euo pipefail
NOM=jenkins-restauration
if [ "${1:-}" = "--nettoyer" ]; then
  docker rm -f "$NOM" >/dev/null 2>&1 || true
  docker volume rm "$NOM" >/dev/null 2>&1 || true
  echo "Instance de restauration supprimee"; exit 0
fi
ARCHIVE="$(cd "$(dirname "${1:?archive .tgz}")" && pwd)/$(basename "$1")"
docker volume create "$NOM" >/dev/null
docker run --rm -i -v "$NOM:/jenkins_home" alpine:3.20 \
  sh -c 'rm -rf /jenkins_home/* && tar xzf - -C /jenkins_home && chown -R 1000:1000 /jenkins_home' < "$ARCHIVE"
docker rm -f "$NOM" >/dev/null 2>&1 || true
docker run -d --name "$NOM" -p 8081:8080 -v "$NOM:/var/jenkins_home" \
  -e JAVA_OPTS=-Djenkins.install.runSetupWizard=false cicd-formation/jenkins:local >/dev/null
printf 'Demarrage de %s ' "$NOM"
until curl -s -o /dev/null -w '%{http_code}' http://localhost:8081/login | grep -q 200; do printf '.'; sleep 3; done
echo " OK : http://localhost:8081 (memes comptes que l'instance sauvegardee)"
