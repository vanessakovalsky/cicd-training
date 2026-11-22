#!/bin/sh
# Canary : repartit le trafic de production entre la couleur active (stable) et la
# nouvelle couleur (canary) selon un poids, via un service pondere Traefik.
# Usage : deploy/canary.sh VERSION POIDS_CANARY   (ex. 10 -> 10 % du trafic)
#         deploy/canary.sh --valider             (canary a 100 % : equivalent bascule)
#         deploy/canary.sh --annuler             (stable a 100 %)
set -eu
. "$(dirname "$0")/commun.sh"
FICHIER="$TRAEFIK_DYNAMIQUE/prod.yml"
ETAT="$TRAEFIK_DYNAMIQUE/canary.etat"

ecrire() { # ecrire STABLE CANARY POIDS_CANARY
  cat > "$FICHIER.tmp" <<YAML
# Genere par deploy/canary.sh - stable : $1, canary : $2 ($3 %)
http:
  routers:
    fretexpress-prod:
      rule: "Host(\`$DOMAINE\`)"
      entryPoints: [web]
      service: fretexpress-prod-pondere
  services:
    fretexpress-prod-pondere:
      weighted:
        services:
          - name: fretexpress-prod-$1@docker
            weight: $((100 - $3))
          - name: fretexpress-prod-$2@docker
            weight: $3
YAML
  mv "$FICHIER.tmp" "$FICHIER"
  printf '%s %s %s\n' "$1" "$2" "$3" > "$ETAT"
  journal "Trafic : $1 $((100 - $3)) % / $2 $3 %"
}

case "${1:-}" in
  --valider|--annuler)
    read -r STABLE CANARY _ < "$ETAT"
    GAGNANT=$([ "$1" = --valider ] && echo "$CANARY" || echo "$STABLE")
    cat > "$FICHIER" <<YAML
# Genere par deploy/canary.sh $1 - couleur active : $GAGNANT
http:
  routers:
    fretexpress-prod:
      rule: "Host(\`$DOMAINE\`)"
      entryPoints: [web]
      service: fretexpress-prod-$GAGNANT@docker
YAML
    rm -f "$ETAT"
    journal "Canary termine ($1) : production sur $GAGNANT"
    ;;
  *)
    VERSION="$1"; POIDS="${2:-10}"
    STABLE="$(sed -n 's/.*service: fretexpress-prod-\([a-z]*\)@docker.*/\1/p' "$FICHIER")"
    [ -n "$STABLE" ] || { echo "Production blue/green requise avant un canary" >&2; exit 1; }
    CANARY=$([ "$STABLE" = blue ] && echo green || echo blue)
    recuperer_image "$VERSION"
    lancer "fretexpress-prod-$CANARY" "$CANARY.prod.$DOMAINE" "$VERSION"
    "$(dirname "$0")/test-fumee.sh" "$CANARY.prod.$DOMAINE" "$VERSION"
    ecrire "$STABLE" "$CANARY" "$POIDS"
    ;;
esac
