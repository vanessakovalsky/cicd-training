#!/usr/bin/env bash
# Lab 1.3 : simule un collegue (compte reviewer) qui fusionne une modification du README
# sur main pendant que la branche du stagiaire modifie les memes lignes -> conflit.
# Usage : scripts/m01/labs/simuler-collegue.sh
set -euo pipefail
. "$(dirname "$0")/../../lib/commun.sh"

TRAVAIL="$(mktemp -d)"
git clone -q "http://reviewer:$GITEA_REVIEWER_PASSWORD@localhost:3000/dev/$DEPOT.git" "$TRAVAIL/d"
cd "$TRAVAIL/d"
git checkout -q -b docs/deploiement-collegue
python3 - <<'PY'
import re
p = "README.md"
s = open(p, encoding="utf-8").read()
s = re.sub(r"## Deploiement actuel\n\n.*\n",
           "## Deploiement actuel\n\nManuel via un script scp lance par l'equipe exploitation (ticket OPS-112).\n",
           s)
open(p, "w", encoding="utf-8").write(s)
PY
git -c user.name="Collegue (reviewer)" -c user.email=reviewer@fretexpress.localhost \
  commit -q -am "docs: preciser le deploiement actuel"
git push -q origin docs/deploiement-collegue 2>/dev/null
cd - >/dev/null
NUMERO="$(curl -s -u "reviewer:$GITEA_REVIEWER_PASSWORD" -X POST -H 'Content-Type: application/json' \
  "$GITEA_URL/api/v1/repos/dev/$DEPOT/pulls" \
  -d '{"head":"docs/deploiement-collegue","base":"main","title":"docs: preciser le deploiement actuel"}' \
  | sed -n 's/^{"id":[0-9]*,"url":"[^"]*","number":\([0-9]*\).*/\1/p')"
# Approbation par dev (proprietaire) puis fusion : main change sous les pieds du stagiaire
gitea_api POST "/repos/dev/$DEPOT/pulls/$NUMERO/reviews" '{"event":"APPROVED","body":"OK"}' >/dev/null
curl -s -o /dev/null -u "reviewer:$GITEA_REVIEWER_PASSWORD" -X POST -H 'Content-Type: application/json' \
  "$GITEA_URL/api/v1/repos/dev/$DEPOT/pulls/$NUMERO/merge" -d '{"Do":"merge","delete_branch_after_merge":true}'
rm -rf "$TRAVAIL"
info "Merge request #$NUMERO du collegue fusionnee sur main (README modifie)"
