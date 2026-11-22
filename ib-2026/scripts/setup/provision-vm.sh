#!/usr/bin/env bash
# Provisionne une VM Compute Engine par stagiaire (liste comptes.txt) et y demarre la pile.
# Idempotent : une VM existante n'est pas recreee, la copie des fichiers est rejouee.
# Usage : scripts/setup/provision-vm.sh [NN...]   (sans argument : tous les comptes)
# Prerequis : gcloud authentifie, gcp.env renseigne. Cree des ressources PAYANTES.
set -euo pipefail
ICI="$(cd "$(dirname "$0")" && pwd)"; RACINE="$(cd "$ICI/../.." && pwd)"
# shellcheck disable=SC1091
. "$ICI/gcp.env"
[ "$GCP_PROJET" != "<PROJET_GCP>" ] || { echo "Renseigner GCP_PROJET dans gcp.env" >&2; exit 1; }
COMPTES=("$@"); [ ${#COMPTES[@]} -gt 0 ] || mapfile -t COMPTES < <(grep -Ev '^\s*(#|$)' "$ICI/comptes.txt")
G=(gcloud --project "$GCP_PROJET" --quiet)
mkdir -p "$ICI/keys" && chmod 700 "$ICI/keys"

if ! "${G[@]}" compute firewall-rules describe cicd-formation-ssh >/dev/null 2>&1; then
  "${G[@]}" compute firewall-rules create cicd-formation-ssh --network default \
    --allow tcp:22 --source-ranges "$GCP_SOURCES_SSH" --target-tags cicd-formation \
    --description "SSH des VM de formation CI/CD (supprimee par deprovision-vm.sh)"
fi

ARCHIVE="$(mktemp --suffix .tgz)"
tar czf "$ARCHIVE" -C "$RACINE" --exclude 'environnement/.env' --exclude 'environnement/secrets' \
  --exclude 'environnement/acces.txt' --exclude 'environnement/jenkins/casc' \
  environnement scripts/lib scripts/setup/init-env.sh scripts/m0* scripts/m10 fil-rouge

for NN in "${COMPTES[@]}"; do
  VM="$GCP_PREFIXE-$NN"
  [ -f "$ICI/keys/stagiaire-$NN" ] || ssh-keygen -q -t ed25519 -N '' -C "stagiaire-$NN" -f "$ICI/keys/stagiaire-$NN"
  if ! "${G[@]}" compute instances describe "$VM" --zone "$GCP_ZONE" >/dev/null 2>&1; then
    "${G[@]}" compute instances create "$VM" --zone "$GCP_ZONE" --machine-type "$GCP_TYPE" \
      --image-family ubuntu-2404-lts-amd64 --image-project ubuntu-os-cloud \
      --boot-disk-size "${GCP_DISQUE_GO}GB" --boot-disk-type pd-balanced \
      --tags cicd-formation --labels "$GCP_LABEL,stagiaire=$NN" \
      --metadata-from-file startup-script="$ICI/startup-script.sh" \
      --metadata "ssh-keys=stagiaire:$(cat "$ICI/keys/stagiaire-$NN.pub")"
    echo "[$NN] VM $VM creee"
  fi
  echo "[$NN] Attente de la fin du script de demarrage"
  until "${G[@]}" compute ssh "$VM" --zone "$GCP_ZONE" --command 'test -f /var/run/formation-pret' 2>/dev/null; do
    sleep 10
  done
  "${G[@]}" compute scp "$ARCHIVE" "$VM:/tmp/formation.tgz" --zone "$GCP_ZONE"
  "${G[@]}" compute ssh "$VM" --zone "$GCP_ZONE" --command \
    'sudo tar xzf /tmp/formation.tgz -C /opt/formation && sudo chown -R stagiaire:stagiaire /opt/formation \
     && sudo -iu stagiaire /opt/formation/scripts/setup/init-env.sh complet'
  IP="$("${G[@]}" compute instances describe "$VM" --zone "$GCP_ZONE" \
    --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')"
  echo "[$NN] Pret : ssh -i scripts/setup/keys/stagiaire-$NN stagiaire@$IP (tunnels : scripts/setup/vm.sh $NN --tunnel)"
done
rm -f "$ARCHIVE"
