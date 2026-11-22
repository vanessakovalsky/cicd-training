#!/bin/sh
# Deploiement blue/green en production via Traefik (fournisseur de fichiers).
#  1. deploie la nouvelle version sur la couleur inactive (hote <couleur>.prod.<domaine>)
#  2. test de fumee sur la couleur inactive
#  3. bascule du routeur de production vers cette couleur
#  4. test de fumee sur l'hote de production ; l'ancienne couleur reste disponible (retour arriere)
# Usage : deploy/blue-green.sh VERSION | deploy/blue-green.sh --retour-arriere
set -eu
. "$(dirname "$0")/commun.sh"
FICHIER="$TRAEFIK_DYNAMIQUE/prod.yml"

couleur_active() {
  if [ -f "$FICHIER" ]; then sed -n 's/.*service: fretexpress-prod-\([a-z]*\)@docker.*/\1/p' "$FICHIER"; fi
}

basculer() { # basculer COULEUR : ecriture atomique (fichier temporaire puis renommage)
  cat > "$FICHIER.tmp" <<YAML
# Genere par deploy/blue-green.sh - couleur active : $1
http:
  routers:
    fretexpress-prod:
      rule: "Host(\`$DOMAINE\`)"
      entryPoints: [web]
      service: fretexpress-prod-$1@docker
YAML
  mv "$FICHIER.tmp" "$FICHIER"
  journal "Production basculee sur $1"
}

ACTIVE="$(couleur_active)"
if [ "${1:-}" = "--retour-arriere" ]; then
  [ -n "$ACTIVE" ] || { echo "Aucune production active" >&2; exit 1; }
  CIBLE=$([ "$ACTIVE" = blue ] && echo green || echo blue)
  docker inspect "fretexpress-prod-$CIBLE" >/dev/null 2>&1 || { echo "Couleur $CIBLE absente" >&2; exit 1; }
  basculer "$CIBLE"
  exit 0
fi

VERSION="$1"
CIBLE=$([ "$ACTIVE" = blue ] && echo green || echo blue)
journal "Couleur active : ${ACTIVE:-aucune} -> deploiement sur $CIBLE"
recuperer_image "$VERSION"
lancer "fretexpress-prod-$CIBLE" "$CIBLE.prod.$DOMAINE" "$VERSION"
"$(dirname "$0")/test-fumee.sh" "$CIBLE.prod.$DOMAINE" "$VERSION"
if [ -f "$(dirname "$0")/.simuler-echec-prod" ]; then   # formation : incident simule (module 10)
  journal "Incident simule : bascule annulee, production inchangee sur ${ACTIVE:-aucune}"
  exit 1
fi
basculer "$CIBLE"
"$(dirname "$0")/test-fumee.sh" "$DOMAINE" "$VERSION"
