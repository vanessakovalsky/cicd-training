#!/usr/bin/env bash
# Controles avant session (J-7 puis J-1). Sortie OK / KO par contrainte.
# Usage : scripts/setup/preflight.sh            poste local (ou VM)
#         scripts/setup/preflight.sh --cloud    projet Google Cloud (poste formateur)
#         PROFIL=leger scripts/setup/preflight.sh
set -uo pipefail
ICI="$(cd "$(dirname "$0")" && pwd)"
PROFIL="${PROFIL:-complet}"
KO=0
ok() { printf '  OK  %s\n' "$1"; }
ko() { printf '  KO  %s -> %s\n' "$1" "$2"; KO=$((KO + 1)); }
verifier() { # verifier LIBELLE CORRECTIF COMMANDE...
  local libelle="$1" correctif="$2"; shift 2
  if "$@" >/dev/null 2>&1; then ok "$libelle"; else ko "$libelle" "$correctif"; fi
}
version_min() { # version_min ACTUELLE MINIMUM
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]
}

if [ "${1:-}" = "--cloud" ]; then
  # shellcheck disable=SC1091
  . "$ICI/gcp.env"
  NB=$(grep -Evc '^\s*(#|$)' "$ICI/comptes.txt")
  REGION="${GCP_ZONE%-*}"
  echo "Google Cloud : projet $GCP_PROJET, zone $GCP_ZONE, $NB VM $GCP_TYPE"
  verifier "gcloud installe et authentifie" "gcloud auth login" \
    gcloud auth print-access-token
  verifier "API Compute Engine activee" "gcloud services enable compute.googleapis.com" \
    gcloud --project "$GCP_PROJET" services list --enabled --filter=name:compute.googleapis.com --format='value(name)'
  verifier "Type $GCP_TYPE disponible dans $GCP_ZONE" "changer GCP_ZONE ou GCP_TYPE" \
    gcloud --project "$GCP_PROJET" compute machine-types describe "$GCP_TYPE" --zone "$GCP_ZONE"
  QUOTA=$(gcloud --project "$GCP_PROJET" compute regions describe "$REGION" --format=json 2>/dev/null \
    | python3 -c 'import json,sys
q=[x for x in json.load(sys.stdin)["quotas"] if x["metric"]=="CPUS"][0]
print(int(q["limit"]-q["usage"]))' 2>/dev/null || echo 0)
  BESOIN=$((NB * 4))
  if [ "$QUOTA" -ge "$BESOIN" ]; then ok "Quota CPUS $REGION : $QUOTA libres >= $BESOIN"
  else ko "Quota CPUS $REGION : $QUOTA libres < $BESOIN" "demander une augmentation (IAM > Quotas)"; fi
  verifier "Reseau default present" "creer un reseau ou adapter provision-vm.sh" \
    gcloud --project "$GCP_PROJET" compute networks describe default
  echo "Resultat : $KO KO"; exit "$KO"
fi

echo "Poste : profil $PROFIL"
verifier "Docker repond" "demarrer Docker" docker info
V=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 0)
if version_min "$V" 25.0; then ok "Docker Engine $V >= 25.0"; else ko "Docker Engine $V" "mettre a jour Docker (>= 25)"; fi
V=$(docker compose version --short 2>/dev/null | sed 's/^v//; s/-.*//' || echo 0)
if version_min "$V" 2.24; then ok "Docker Compose $V >= 2.24"; else ko "Docker Compose $V" "installer Compose v2 >= 2.24"; fi
MEM=$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0); MEM_GO=$((MEM / 1024 / 1024 / 1024))
MIN=$([ "$PROFIL" = leger ] && echo 5 || echo 8)    # banc : pile complete = 4 Go environ
if [ "$MEM_GO" -ge 12 ]; then ok "Memoire disponible pour Docker : $MEM_GO Go"
elif [ "$MEM_GO" -ge "$MIN" ]; then ok "Memoire disponible pour Docker : $MEM_GO Go (juste : fermer les autres conteneurs)"
else ko "Memoire Docker : $MEM_GO Go < $MIN" "profil leger, ou augmenter la memoire de Docker Desktop"; fi
LIBRE=$(df -Pk "$ICI" | awk 'NR==2 {print int($4/1024/1024)}')
if [ "$LIBRE" -ge 30 ]; then ok "Disque libre : $LIBRE Go >= 30"; else ko "Disque libre : $LIBRE Go < 30" "liberer de l'espace"; fi
if [ "$PROFIL" = complet ]; then
  MMC=$(docker run --rm alpine:3.20 sysctl -n vm.max_map_count 2>/dev/null || echo 0)
  if [ "$MMC" -ge 524288 ]; then ok "vm.max_map_count = $MMC (SonarQube)"
  elif [ "$MMC" -ge 262144 ]; then ok "vm.max_map_count = $MMC (suffisant au banc ; 524288 recommande)"
  else ko "vm.max_map_count = $MMC < 262144" "sudo sysctl -w vm.max_map_count=524288"; fi
fi
for P in ${TRAEFIK_PORT:-80} 3000 8080 8025 8090 9000; do
  if docker ps --format '{{.Names}} {{.Ports}}' | grep -q "cicd-.*:$P->"; then ok "Port $P utilise par la pile"
  elif (exec 3<>"/dev/tcp/127.0.0.1/$P") 2>/dev/null; then ko "Port $P deja pris" "liberer le port (ou TRAEFIK_PORT pour 80)"
  else ok "Port $P libre"; fi
done
verifier "Acces au registre Docker Hub (proxy)" "configurer le proxy de Docker" docker pull -q alpine:3.20
verifier "Acces a PyPI" "configurer HTTPS_PROXY" curl -fsS -o /dev/null --max-time 10 https://pypi.org/simple/pip/
# *.localhost : resolu par le systeme (getent) ou directement par curl >= 7.78 (WSL, Ubuntu sans
# nss-myhostname) ; les navigateurs le resolvent eux-memes.
localhost_resolu() {
  getent hosts int.fretexpress.localhost >/dev/null 2>&1 && return 0
  version_min "$(curl --version | awk 'NR==1{print $2}')" 7.78.0
}
verifier "Resolution de *.localhost (systeme ou curl)" "utiliser curl -H 'Host: ...' ou ajouter les hotes dans /etc/hosts" \
  localhost_resolu
echo "Resultat : $KO KO"
exit "$KO"
