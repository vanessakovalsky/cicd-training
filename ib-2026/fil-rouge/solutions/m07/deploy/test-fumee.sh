#!/bin/sh
# Test de fumee : /health repond et /version renvoie la version attendue.
# Usage : deploy/test-fumee.sh HOTE VERSION_ATTENDUE
set -eu
HOTE="$1"; ATTENDUE="$2"
for i in $(seq 1 20); do
  if version=$(curl -fsS --max-time 2 -H "Host: $HOTE" http://traefik/version 2>/dev/null); then
    if printf '%s' "$version" | grep -q "\"$ATTENDUE\""; then
      curl -fsS --max-time 2 -H "Host: $HOTE" http://traefik/health >/dev/null
      echo "[fumee] $HOTE OK (version $ATTENDUE)"
      exit 0
    fi
  fi
  sleep 2
done
echo "[fumee] $HOTE KO : version attendue $ATTENDUE, obtenue ${version:-aucune reponse}" >&2
exit 1
