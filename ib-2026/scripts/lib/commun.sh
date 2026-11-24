#!/usr/bin/env bash
# Fonctions communes aux scripts labs / catch-up / cleanup.
# Mode local (defaut) : agit sur la pile du poste.
# Mode cloud : scripts/setup/vm.sh <NN> <script> execute le script sur la VM du stagiaire NN.
set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_DIR="$RACINE/environnement"
FIL_ROUGE="$RACINE/fil-rouge"
JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
GITEA_URL="${GITEA_URL:-http://localhost:3000}"
GITEA_URL_INTERNE="http://gitea:3000"
DEPOT="${DEPOT:-fretexpress}"

# shellcheck disable=SC1091
set -a; . "$ENV_DIR/.env"; set +a

info() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
erreur() { printf '[ERREUR] %s\n' "$*" >&2; exit 1; }

# --- Gitea ---------------------------------------------------------------
gitea_api() { # gitea_api METHODE CHEMIN [JSON]
  curl -sS -u "dev:$GITEA_DEV_PASSWORD" -X "$1" -H 'Content-Type: application/json' \
    "$GITEA_URL/api/v1$2" ${3:+-d "$3"}
}

gitea_code() { # gitea_code METHODE CHEMIN [JSON] -> code HTTP
  curl -s -o /dev/null -w '%{http_code}' -u "dev:$GITEA_DEV_PASSWORD" -X "$1" \
    -H 'Content-Type: application/json' "$GITEA_URL/api/v1$2" ${3:+-d "$3"}
}

gitea_creer_depot() { # gitea_creer_depot NOM
  if [ "$(gitea_code GET "/repos/dev/$1")" != "200" ]; then
    gitea_api POST /user/repos "{\"name\":\"$1\",\"default_branch\":\"main\"}" >/dev/null
    info "Depot dev/$1 cree"
  fi
}

# Pousse le contenu d'un dossier sur main, protection de branche levee le temps du push.
gitea_pousser_etat() { # gitea_pousser_etat DOSSIER_SOURCE MESSAGE [DEPOT]
  local source="$1" message="$2" depot="${3:-$DEPOT}" travail protection
  if [ -n "${RATTRAPAGE_IMBRIQUE:-}" ]; then   # rattrapage appele par un module suivant
    gitea_creer_depot "$depot"; return 0
  fi
  travail="$(mktemp -d)"
  gitea_creer_depot "$depot"
  protection="$(gitea_api GET "/repos/dev/$depot/branch_protections/main" || true)"
  gitea_code DELETE "/repos/dev/$depot/branch_protections/main" >/dev/null || true
  git clone -q "http://dev:$GITEA_DEV_PASSWORD@localhost:3000/dev/$depot.git" "$travail/d" 2>/dev/null \
    || { mkdir -p "$travail/d" && git -C "$travail/d" init -q -b main \
         && git -C "$travail/d" remote add origin "http://dev:$GITEA_DEV_PASSWORD@localhost:3000/dev/$depot.git"; }
  ( cd "$travail/d"
    git checkout -q main 2>/dev/null || git checkout -q -b main
    find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
    cp -r "$source"/. .
    git add -A
    if git -c user.name="Rattrapage" -c user.email="rattrapage@fretexpress.localhost" \
         commit -q -m "$message" >/dev/null; then
      git push -q origin main
      info "Etat pousse sur dev/$depot (main) : $message"
    else
      info "dev/$depot deja a jour"
    fi )
  if printf '%s' "$protection" | grep -q '"branch_name"\|"rule_name"'; then
    gitea_api POST "/repos/dev/$depot/branch_protections" "$protection" >/dev/null
    info "Protection de main restauree"
  fi
  rm -rf "$travail"
}

# Construit l'etat du fil rouge a la fin du module donne (base + correctifs cumules).
etat_fil_rouge() { # etat_fil_rouge NUMERO_MODULE DOSSIER_CIBLE
  local fin="$1" cible="$2" m pub="$FIL_ROUGE/solutions/.publication"
  # Paquet stagiaire : solutions publiees seulement avec les corrections du module
  if [ -f "$pub" ]; then
    for m in 01 02 03 04 05 06 07 08 09 10; do
      if grep -q "^attendues=.*\b$m\b" "$pub" && ! grep -q "^publiees=.*\b$m\b" "$pub"; then
        erreur "Solutions du module $m non publiees : etat fin module $fin impossible. Formateur : publier les corrections du module $m (CORRECTIONS_PUBLIEES), puis git pull dans $RACINE"
      fi
      [ "$m" = "$fin" ] && break
    done
  fi
  rm -rf "$cible" && mkdir -p "$cible"
  cp -r "$FIL_ROUGE/fretexpress"/. "$cible"/
  for m in 01 02 03 04 05 06 07 08 09 10; do
    [ -d "$FIL_ROUGE/solutions/m$m" ] && cp -r "$FIL_ROUGE/solutions/m$m"/. "$cible"/
    [ "$m" = "$fin" ] && break
  done
  return 0
}

# --- Jenkins -------------------------------------------------------------
jenkins_crumb_curl() { # appel authentifie (jeton CSRF gere par la session)
  local cookies; cookies="$(mktemp)"
  local crumb
  crumb="$(curl -s -c "$cookies" -u "admin:$JENKINS_ADMIN_PASSWORD" \
    "$JENKINS_URL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)")"
  curl -sS -b "$cookies" -u "admin:$JENKINS_ADMIN_PASSWORD" -H "$crumb" "$@"
  rm -f "$cookies"
}

jenkins_groovy() { # jenkins_groovy FICHIER_GROOVY : execute dans la console de scripts
  jenkins_crumb_curl --data-urlencode "script@$1" "$JENKINS_URL/scriptText"
}

jenkins_casc() { # jenkins_casc [FICHIER.yaml...] : ajoute des fragments JCasC puis recharge
  local f
  for f in "$@"; do cp "$f" "$ENV_DIR/jenkins/casc/"; done
  jenkins_credentials_yaml
  local depuis; depuis="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jenkins_crumb_curl -X POST -o /dev/null -w '%{http_code}\n' \
    "$JENKINS_URL/configuration-as-code/reload" | grep -qE '^(200|302)$' \
    || erreur "Rechargement JCasC refuse (voir Manage Jenkins > Configuration as Code)"
  # Une erreur de configuration ne change pas le code HTTP : lecture du journal du controleur
  if docker logs --since "$depuis" cicd-jenkins-1 2>&1 | grep -E 'casc\.[A-Za-z]*Exception' >&2; then
    erreur "JCasC invalide (voir ci-dessus) : configuration precedente conservee"
  fi
  info "JCasC recharge ${*:-(credentials)}"
}

# Ecrit casc/credentials.yaml a partir des secrets presents dans environnement/secrets.
# Un rechargement JCasC remplace TOUS les credentials "system" : la liste est donc
# toujours complete (agent, Gitea, SonarQube, registre).
jenkins_credentials_yaml() {
  local s=/run/secrets/formation f="$ENV_DIR/jenkins/casc/credentials.yaml"
  {
    echo "# Genere par scripts/lib/commun.sh (jenkins_credentials_yaml) - ne pas modifier"
    echo "credentials:"
    echo "  system:"
    echo "    domainCredentials:"
    echo "      - credentials:"
    echo "          - basicSSHUserPrivateKey:"
    echo "              scope: SYSTEM"
    echo "              id: agent-ssh"
    echo "              username: jenkins"
    echo "              description: \"Cle SSH de l'agent Python\""
    echo "              privateKeySource:"
    echo "                directEntry:"
    echo "                  privateKey: \"\${readFile:$s/agent_ed25519}\""
    if [ -f "$ENV_DIR/secrets/gitea_token" ]; then
      echo "          - usernamePassword:"
      echo "              scope: GLOBAL"
      echo "              id: gitea-dev"
      echo "              username: dev"
      echo "              password: \"\${readFile:$s/gitea_token}\""
      echo "              description: \"Gitea - utilisateur dev (jeton d'acces)\""
    fi
    if [ -f "$ENV_DIR/secrets/sonar_token" ]; then
      echo "          - string:"
      echo "              scope: GLOBAL"
      echo "              id: sonar-token"
      echo "              secret: \"\${readFile:$s/sonar_token}\""
      echo "              description: \"SonarQube - jeton d'analyse\""
    fi
    if [ -f "$ENV_DIR/secrets/registre_token" ]; then
      echo "          - usernamePassword:"
      echo "              scope: GLOBAL"
      echo "              id: registre-lecture"
      echo "              username: dev"
      echo "              password: \"\${readFile:$s/registre_token}\""
      echo "              description: \"Registre Gitea - lecture seule (deploiement)\""
    fi
  } > "$f"
}

jenkins_attendre_agent() { # jenkins_attendre_agent NOM
  local _
  for _ in $(seq 1 30); do
    if curl -s -u "admin:$JENKINS_ADMIN_PASSWORD" "$JENKINS_URL/computer/$1/api/json?tree=offline" \
         | grep -q '"offline":false'; then
      info "Agent $1 en ligne"; return 0
    fi
    sleep 4
  done
  erreur "Agent $1 hors ligne (journal : $JENKINS_URL/computer/$1/log)"
}
