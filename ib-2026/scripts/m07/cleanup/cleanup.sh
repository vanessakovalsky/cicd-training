#!/usr/bin/env bash
# Nettoyage module 07 : conteneurs deployes par le pipeline (int, recette, prod blue/green,
# demonstration rolling) et configuration Traefik generee. Cible par nom exact.
set -euo pipefail
for c in fretexpress-int fretexpress-recette fretexpress-prod-blue fretexpress-prod-green \
         $(docker ps -a --format '{{.Names}}' --filter name=fretexpress-demo-); do
  if docker inspect "$c" >/dev/null 2>&1; then docker rm -f "$c" >/dev/null && echo "Supprime : $c"; fi
done
docker exec cicd-traefik-1 sh -c 'rm -f /etc/traefik/dynamic/prod.yml /etc/traefik/dynamic/canary.etat' \
  && echo "Configuration Traefik de production supprimee"
