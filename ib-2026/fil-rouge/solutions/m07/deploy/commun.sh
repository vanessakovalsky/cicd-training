#!/bin/sh
# Variables et fonctions communes aux scripts de deploiement (executes sur l'agent).
set -eu
IMAGE="${IMAGE:-localhost:3000/dev/fretexpress}"
RESEAU="${RESEAU:-cicd}"
TRAEFIK_DYNAMIQUE="${TRAEFIK_DYNAMIQUE:-/srv/traefik-dynamic}"
DOMAINE="${DOMAINE:-fretexpress.localhost}"

journal() { printf '[deploy] %s\n' "$*"; }

# Recupere l'image depuis le registre (promotion : la MEME image que celle testee).
recuperer_image() { # recuperer_image VERSION
  if [ -n "${REGISTRE_USER:-}" ]; then
    printf '%s' "$REGISTRE_TOKEN" | docker login "${IMAGE%%/*}" -u "$REGISTRE_USER" --password-stdin >/dev/null
  fi
  docker pull --quiet "$IMAGE:$1" >/dev/null
  journal "Image $IMAGE:$1 recuperee"
}

# Lance un conteneur expose par Traefik sur un nom d'hote.
lancer() { # lancer NOM_CONTENEUR HOTE VERSION
  docker rm -f "$1" >/dev/null 2>&1 || true
  docker run -d --name "$1" --network "$RESEAU" --restart unless-stopped \
    --label traefik.enable=true \
    --label "traefik.http.routers.$1.rule=Host(\`$2\`)" \
    --label "traefik.http.routers.$1.entrypoints=web" \
    --label "traefik.http.services.$1.loadbalancer.server.port=8000" \
    --label "fretexpress.version=$3" \
    "$IMAGE:$3" >/dev/null
  journal "Conteneur $1 ($3) lance, hote $2"
}
