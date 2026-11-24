#!/usr/bin/env bash
# Variante GitLab CI (defis 3 etoiles, modules 07, 08, 10) : demarre GitLab CE et son runner
# dans la pile de formation, cree l'utilisateur dev et le projet dev/fretexpress, enregistre
# le runner. Idempotent (relancable). Duree : 4 min au premier lancement (poste de la salle), jusqu a 20 min sur une machine lente.
# Prerequis : pile demarree (scripts/setup/init-env.sh), image de l'agent construite.
# Usage : scripts/setup/gitlab/init-gitlab.sh
set -euo pipefail
. "$(dirname "$0")/../../lib/commun.sh"

GITLAB_URL="${GITLAB_URL:-http://localhost:8929}"
SECRETS="$ENV_DIR/secrets"
JETON_FICHIER="$SECRETS/gitlab_root_token"
cd "$ENV_DIR"

# 1. Mot de passe root (lu par GitLab au premier demarrage uniquement)
if ! grep -q '^GITLAB_ROOT_PASSWORD=' .env; then
  echo "GITLAB_ROOT_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20 || true)" >> .env
  info "Mot de passe root GitLab ajoute a environnement/.env"
fi
set -a; . ./.env; set +a

docker image inspect cicd-formation/agent-python:local >/dev/null 2>&1 \
  || erreur "Image cicd-formation/agent-python:local absente : lancer scripts/setup/init-env.sh"

# 2. Demarrage et attente de la page de connexion (le controle "healthy" de l'image
#    passe avant la creation de la base au premier demarrage : insuffisant)
docker compose --profile gitlab up -d gitlab gitlab-runner
info "Attente de GitLab (premier demarrage : 5 a 20 min selon le poste)"
code=000
for _ in $(seq 1 120); do   # 20 min maximum
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$GITLAB_URL/users/sign_in" || true)"
  [ "$code" = 200 ] && break
  sleep 10
done
[ "$code" = 200 ] || erreur "GitLab non pret (HTTP $code) : docker logs cicd-gitlab-1"
info "GitLab pret : $GITLAB_URL"

# 3. Jeton d'administration (API) : cree par gitlab-rails, renouvele a chaque lancement
gl_api() { # gl_api METHODE CHEMIN [ARGS curl...]
  local m="$1" c="$2"; shift 2
  curl -sS -X "$m" -H "PRIVATE-TOKEN: $(cat "$JETON_FICHIER")" "$GITLAB_URL/api/v4$c" "$@"
}
if [ ! -s "$JETON_FICHIER" ] || [ "$(gl_api GET /user -o /dev/null -w '%{http_code}')" != 200 ]; then
  info "Creation du jeton d'administration (gitlab-rails, environ 1 min)"
  docker exec cicd-gitlab-1 gitlab-rails runner "
    u = User.find_by_username('root')
    u.personal_access_tokens.where(name: 'formation-init', revoked: false).each(&:revoke!)
    t = u.personal_access_tokens.create!(name: 'formation-init', scopes: ['api'], expires_at: 30.days.from_now)
    File.write('/tmp/jeton', t.token)
  "
  docker exec cicd-gitlab-1 cat /tmp/jeton > "$JETON_FICHIER"
  docker exec cicd-gitlab-1 rm -f /tmp/jeton
  chmod 600 "$JETON_FICHIER"
fi
[ "$(gl_api GET /user -o /dev/null -w '%{http_code}')" = 200 ] || erreur "Jeton d'administration refuse"
champ() { # champ EXPRESSION_PYTHON : evalue sur le JSON lu en entree (d), vide si absent
  python3 -c "import sys,json
try:
    d=json.load(sys.stdin); v=$1
except Exception:
    v=None
print('' if v is None else v)"
}

# 4. Utilisateur dev (meme mot de passe que dans Gitea) et projet dev/fretexpress
id_dev="$(gl_api GET '/users?username=dev' | champ "d[0]['id'] if d else None")"
if [ -z "$id_dev" ]; then
  id_dev="$(gl_api POST /users -H 'Content-Type: application/json' -d "{
    \"username\": \"dev\", \"name\": \"Developpeur FretExpress\",
    \"email\": \"dev@fretexpress.localhost\", \"password\": \"$GITEA_DEV_PASSWORD\",
    \"skip_confirmation\": true}" | champ "d.get('id')")"
  [ -n "$id_dev" ] || erreur "Creation de l'utilisateur dev refusee"
  info "Utilisateur dev cree"
fi
if [ "$(gl_api GET /projects/dev%2Ffretexpress -o /dev/null -w '%{http_code}')" != 200 ]; then
  gl_api POST "/projects/user/$id_dev" -H 'Content-Type: application/json' \
    -d '{"name": "fretexpress", "visibility": "private", "default_branch": "main"}' >/dev/null
  info "Projet dev/fretexpress cree (vide)"
fi

# 5. Runner d'instance, executeur docker (memes acces que l'agent Jenkins)
if docker exec cicd-gitlab-runner-1 grep -q '^\[\[runners\]\]' /etc/gitlab-runner/config.toml 2>/dev/null; then
  info "Runner deja enregistre"
else
  jeton_runner="$(gl_api POST /user/runners -H 'Content-Type: application/json' \
    -d '{"runner_type": "instance_type", "description": "runner-formation", "run_untagged": true}' \
    | champ "d.get('token')")"
  [ -n "$jeton_runner" ] || erreur "Creation du runner refusee"
  docker exec cicd-gitlab-runner-1 gitlab-runner register --non-interactive \
    --url http://gitlab:8929 --clone-url http://gitlab:8929 --token "$jeton_runner" \
    --name runner-formation --executor docker \
    --docker-image cicd-formation/agent-python:local --docker-pull-policy if-not-present \
    --docker-network-mode cicd \
    --docker-volumes /var/run/docker.sock:/var/run/docker.sock \
    --docker-volumes cicd_traefik-dynamic:/srv/traefik-dynamic \
    --docker-volumes /cache >/dev/null 2>&1
  info "Runner runner-formation enregistre"
fi

etat_runner="$(gl_api GET '/runners/all?type=instance_type' \
  | champ "next((r['status'] for r in d if r['description'] == 'runner-formation'), 'absent')")"
info "Runner : $etat_runner (online attendu sous 1 min)"
info "GitLab : $GITLAB_URL - utilisateur dev, mot de passe GITEA_DEV_PASSWORD (environnement/.env)"
