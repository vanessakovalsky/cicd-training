#!/usr/bin/env bash
# Supprime la variante GitLab (conteneurs, volumes, jeton) sans toucher au reste de la pile.
# Usage : scripts/setup/gitlab/nettoyer-gitlab.sh [--images]   (--images : supprime aussi les images)
set -euo pipefail
. "$(dirname "$0")/../../lib/commun.sh"
cd "$ENV_DIR"

docker compose --profile gitlab rm -sf gitlab gitlab-runner
for v in gitlab-config gitlab-logs gitlab-data gitlab-runner-config; do
  docker volume rm "cicd_$v" >/dev/null 2>&1 && info "Volume cicd_$v supprime" || true
done
rm -f "$ENV_DIR/secrets/gitlab_root_token"
# Conteneurs de jobs ou de services laisses par l'executeur docker
docker ps -aq --filter 'label=com.gitlab.gitlab-runner.managed=true' | xargs -r docker rm -f >/dev/null
if [ "${1:-}" = "--images" ]; then
  docker image rm gitlab/gitlab-ce:19.6.1-ce.0 gitlab/gitlab-runner:alpine-v19.6.1 >/dev/null 2>&1 || true
  docker images -q 'registry.gitlab.com/gitlab-org/gitlab-runner/gitlab-runner-helper' | xargs -r docker image rm >/dev/null 2>&1 || true
  info "Images GitLab supprimees"
fi
info "Variante GitLab supprimee (GITLAB_ROOT_PASSWORD conserve dans .env)"
