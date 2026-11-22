#!/usr/bin/env bash
# Demonstration formateur (module 07) : rolling update de 3 repliques derriere Traefik.
# Les repliques partagent le service Traefik "fretexpress-demo". Pour chacune :
# nouvelle replique demarree et saine (surplus de 1) -> ancienne arretee.
# Une boucle curl montre la bascule progressive des versions.
# Usage : scripts/m07/labs/demo-rolling.sh <VERSION_DEPART> <VERSION_CIBLE>
#         scripts/m07/labs/demo-rolling.sh --nettoyer
set -euo pipefail
IMAGE="localhost:3000/dev/fretexpress"
HOTE="demo.fretexpress.localhost"
PORT="${TRAEFIK_PORT:-80}"

replique() { # replique NUMERO VERSION
  docker rm -f "fretexpress-demo-$1-$2" >/dev/null 2>&1 || true
  docker run -d --name "fretexpress-demo-$1-$2" --network cicd \
    --label traefik.enable=true \
    --label "traefik.http.routers.fretexpress-demo.rule=Host(\`$HOTE\`)" \
    --label traefik.http.routers.fretexpress-demo.entrypoints=web \
    --label traefik.http.services.fretexpress-demo.loadbalancer.server.port=8000 \
    "$IMAGE:$2" >/dev/null
  until [ "$(docker inspect -f '{{.State.Health.Status}}' "fretexpress-demo-$1-$2")" = healthy ]; do
    sleep 1
  done
}

if [ "${1:-}" = "--nettoyer" ]; then
  docker ps -aq --filter name=fretexpress-demo- | xargs -r docker rm -f >/dev/null
  echo "Repliques de demonstration supprimees"; exit 0
fi
DEPART="${1:?version de depart}"; CIBLE="${2:?version cible}"

echo "== 3 repliques en $DEPART"
for n in 1 2 3; do replique "$n" "$DEPART"; done
( for _ in $(seq 1 400); do
    curl -s -o /dev/null -w '%{http_code} ' --max-time 1 -H "Host: $HOTE" "http://localhost:$PORT/version"
    curl -s --max-time 1 -H "Host: $HOTE" "http://localhost:$PORT/version"; echo
    sleep 0.5
  done ) > /tmp/demo-rolling.log &
SONDE=$!
sleep 3
for n in 1 2 3; do
  echo "== Replique $n : demarrage en $CIBLE (surplus), puis arret de l'ancienne"
  replique "$n" "$CIBLE"
  sleep 3                                   # prise en compte par Traefik
  docker stop -t 10 "fretexpress-demo-$n-$DEPART" >/dev/null
  docker rm "fretexpress-demo-$n-$DEPART" >/dev/null
done
sleep 3; kill "$SONDE" 2>/dev/null || true
echo "== Bilan des reponses pendant la mise a jour (code HTTP, version)"
sort /tmp/demo-rolling.log | uniq -c
