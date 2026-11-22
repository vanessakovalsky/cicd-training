#!/usr/bin/env bash
# Lab 9.2 : sauvegarde de JENKINS_HOME (hors workspace, caches, war, plugins) + export JCasC.
# Plugins exclus : reinstalles par l'image (plugins.txt fige) au demarrage.
# Usage : scripts/m09/labs/sauvegarde-jenkins.sh [DOSSIER]   (defaut : sauvegardes/)
set -euo pipefail
. "$(dirname "$0")/../../lib/commun.sh"
if [ -n "${1:-}" ]; then mkdir -p "$1"; CIBLE="$(cd "$1" && pwd)"
else CIBLE="$RACINE/sauvegardes"; mkdir -p "$CIBLE"; fi
HORO="$(date +%Y%m%d-%H%M)"
ARCHIVE="jenkins-home-$HORO.tgz"
# tar dans un conteneur jetable qui monte le volume en lecture seule ; archive transmise par stdout
docker run --rm -v cicd_jenkins-home:/jenkins_home:ro alpine:3.20 \
  tar czf - -C /jenkins_home --exclude=./workspace --exclude=./caches --exclude=./war --exclude=./plugins \
  --exclude='./jobs/*/branches/*/workspace*' --exclude=./.cache . > "$CIBLE/$ARCHIVE"
echo "Sauvegarde : ${CIBLE#$RACINE/}/$ARCHIVE ($(du -h "$CIBLE/$ARCHIVE" | cut -f1))"
jenkins_crumb_curl -X POST "$JENKINS_URL/configuration-as-code/export" > "$CIBLE/jenkins-casc-$HORO.yaml"
echo "Export JCasC : ${CIBLE#$RACINE/}/jenkins-casc-$HORO.yaml"
