#!/usr/bin/env bash
# Initialise et demarre la pile de formation (poste local ou VM cloud). Idempotent.
# Usage : scripts/setup/init-env.sh [leger|complet]
set -euo pipefail

PROFIL="${1:-complet}"
case "$PROFIL" in complet|leger) ;; *) echo "Profil inconnu : $PROFIL (complet|leger)" >&2; exit 1;; esac
RACINE="$(cd "$(dirname "$0")/../.." && pwd)"
ENV_DIR="$RACINE/environnement"
SECRETS="$ENV_DIR/secrets"
cd "$ENV_DIR"

mot_de_passe() { tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16 || true; }

mkdir -p "$SECRETS" && chmod 700 "$SECRETS"
if [ ! -f "$SECRETS/agent_ed25519" ]; then
  ssh-keygen -q -t ed25519 -N '' -C 'jenkins-agent' -f "$SECRETS/agent_ed25519"
fi
if [ ! -f .env ]; then
  {
    echo "JENKINS_ADMIN_PASSWORD=$(mot_de_passe)"
    echo "GITEA_DEV_PASSWORD=$(mot_de_passe)"
    echo "GITEA_REVIEWER_PASSWORD=$(mot_de_passe)"
    echo "JENKINS_AGENT_SSH_PUBKEY=\"$(cat "$SECRETS/agent_ed25519.pub")\""
  } > .env
  chmod 600 .env
fi
# shellcheck disable=SC1091
set -a; . ./.env; set +a

# Configuration JCasC de travail (modifiee par les labs et rattrapages, hors Git)
mkdir -p jenkins/casc
[ -f jenkins/casc/jenkins.yaml ] || cp jenkins/casc-initial/jenkins.yaml jenkins/casc/
cp "jenkins/casc-initial/profil-$PROFIL.yaml" jenkins/casc/profil.yaml

if [ "$PROFIL" = "complet" ]; then
  docker compose --profile complet up -d --build
else
  docker compose up -d --build
fi

attendre() { # attendre <nom> <url> <code_http_attendu>
  printf 'Attente de %s ' "$1"
  for _ in $(seq 1 90); do
    code=$(curl -s -o /dev/null -w '%{http_code}' "$2" || true)
    if [ "$code" = "$3" ]; then echo " OK"; return 0; fi
    printf '.'; sleep 5
  done
  echo " KO ($2 -> $code)"; return 1
}
attendre Gitea http://localhost:3000/api/healthz 200
attendre Jenkins http://localhost:8080/login 200

creer_utilisateur_gitea() { # login mot_de_passe [--admin]
  if ! docker compose exec -T -u git gitea gitea admin user list | awk '{print $2}' | grep -qx "$1"; then
    docker compose exec -T -u git gitea gitea admin user create --username "$1" \
      --password "$2" --email "$1@fretexpress.localhost" --must-change-password=false ${3:-}
  fi
}
creer_utilisateur_gitea dev "$GITEA_DEV_PASSWORD" --admin
creer_utilisateur_gitea reviewer "$GITEA_REVIEWER_PASSWORD"

if [ "$PROFIL" = "complet" ]; then
  printf 'Attente de SonarQube '
  for _ in $(seq 1 60); do
    etat=$(curl -s http://localhost:9000/api/system/status | sed -n 's/.*"status":"\([A-Z_]*\)".*/\1/p' || true)
    [ "$etat" = "UP" ] && { echo " OK"; break; }
    printf '.'; sleep 5
  done
fi

cat > "$ENV_DIR/acces.txt" <<ACCES
Jenkins   http://localhost:8080   admin / $JENKINS_ADMIN_PASSWORD
Gitea     http://localhost:3000   dev / $GITEA_DEV_PASSWORD   reviewer / $GITEA_REVIEWER_PASSWORD
SonarQube http://localhost:9000   admin / admin (changement impose a la 1re connexion)
Mailpit   http://localhost:8025
Traefik   http://localhost:8090
Cle privee de l'agent : $SECRETS/agent_ed25519
ACCES
chmod 600 "$ENV_DIR/acces.txt"
echo "Pile demarree. Acces : $ENV_DIR/acces.txt"
