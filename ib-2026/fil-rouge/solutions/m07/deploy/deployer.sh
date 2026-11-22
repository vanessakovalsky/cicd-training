#!/bin/sh
# Deploiement simple (remplacement) dans un environnement hors production.
# Usage : deploy/deployer.sh int|recette VERSION
set -eu
. "$(dirname "$0")/commun.sh"
ENV_CIBLE="$1"; VERSION="$2"
case "$ENV_CIBLE" in int|recette) ;; *) echo "Environnement inconnu : $ENV_CIBLE" >&2; exit 2;; esac

recuperer_image "$VERSION"
lancer "fretexpress-$ENV_CIBLE" "$ENV_CIBLE.$DOMAINE" "$VERSION"
"$(dirname "$0")/test-fumee.sh" "$ENV_CIBLE.$DOMAINE" "$VERSION"
