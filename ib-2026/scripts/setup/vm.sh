#!/usr/bin/env bash
# Pilote les VM des stagiaires.
#   scripts/setup/vm.sh <NN|tous> <script relatif> [args]   execute un script sur la VM
#   scripts/setup/vm.sh <NN> --tunnel                        affiche la commande de tunnel SSH
#   scripts/setup/vm.sh <NN|tous> --acces                    affiche environnement/acces.txt
#   scripts/setup/vm.sh tous --demarrer | --arreter | --etat
# Exemple : scripts/setup/vm.sh 03 scripts/m05/catch-up/catch-up.sh
set -euo pipefail
ICI="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$ICI/gcp.env"
G=(gcloud --project "$GCP_PROJET" --quiet)
CIBLE="${1:?NN ou tous}"; ACTION="${2:?script ou option}"; shift 2
if [ "$CIBLE" = tous ]; then mapfile -t COMPTES < <(grep -Ev '^\s*(#|$)' "$ICI/comptes.txt"); else COMPTES=("$CIBLE"); fi
NOMS=(); for NN in "${COMPTES[@]}"; do NOMS+=("$GCP_PREFIXE-$NN"); done

case "$ACTION" in
  --demarrer) "${G[@]}" compute instances start "${NOMS[@]}" --zone "$GCP_ZONE" ;;
  --arreter)  "${G[@]}" compute instances stop "${NOMS[@]}" --zone "$GCP_ZONE" ;;
  --etat)     "${G[@]}" compute instances list --filter "labels.formation=cicd-jenkins" \
                --format 'table(name,status,networkInterfaces[0].accessConfigs[0].natIP)' ;;
  --tunnel)
    IP="$("${G[@]}" compute instances describe "${NOMS[0]}" --zone "$GCP_ZONE" \
      --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')"
    echo "ssh -i stagiaire-${COMPTES[0]} -N -L 8080:localhost:8080 -L 3000:localhost:3000 \\"
    echo "    -L 9000:localhost:9000 -L 8025:localhost:8025 -L 8090:localhost:8090 \\"
    echo "    -L 8000:localhost:80 stagiaire@$IP" ;;
  --acces)
    for VM in "${NOMS[@]}"; do
      echo "== $VM"; "${G[@]}" compute ssh "$VM" --zone "$GCP_ZONE" \
        --command 'sudo cat /opt/formation/environnement/acces.txt'
    done ;;
  *)
    for VM in "${NOMS[@]}"; do
      echo "== $VM : $ACTION $*"
      "${G[@]}" compute ssh "$VM" --zone "$GCP_ZONE" \
        --command "sudo -iu stagiaire bash -c 'cd /opt/formation && $ACTION $*'"
    done ;;
esac
