#!/usr/bin/env bash
# Supprime les VM des stagiaires (noms exacts issus de comptes.txt), leurs disques
# et la regle de pare-feu de la formation. Suppression DEFINITIVE (aucune corbeille).
# Usage : scripts/setup/deprovision-vm.sh [NN...]   (sans argument : tous + pare-feu)
set -euo pipefail
ICI="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$ICI/gcp.env"
G=(gcloud --project "$GCP_PROJET" --quiet)
TOUS=0; COMPTES=("$@")
if [ ${#COMPTES[@]} -eq 0 ]; then TOUS=1; mapfile -t COMPTES < <(grep -Ev '^\s*(#|$)' "$ICI/comptes.txt"); fi

for NN in "${COMPTES[@]}"; do
  VM="$GCP_PREFIXE-$NN"
  if "${G[@]}" compute instances describe "$VM" --zone "$GCP_ZONE" >/dev/null 2>&1; then
    "${G[@]}" compute instances delete "$VM" --zone "$GCP_ZONE" --delete-disks all
    echo "[$NN] $VM supprimee (disque compris)"
  else
    echo "[$NN] $VM absente"
  fi
done
if [ "$TOUS" = 1 ] && "${G[@]}" compute firewall-rules describe cicd-formation-ssh >/dev/null 2>&1; then
  "${G[@]}" compute firewall-rules delete cicd-formation-ssh
  echo "Regle de pare-feu cicd-formation-ssh supprimee"
fi
echo "Ressources restantes avec le label formation :"
"${G[@]}" compute instances list --filter "labels.formation=cicd-jenkins" --format 'value(name)'
"${G[@]}" compute disks list --filter "labels.formation=cicd-jenkins" --format 'value(name)'
