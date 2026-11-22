#!/usr/bin/env bash
# Rattrapage module 02 : depot fretexpress (etat M01), agent SSH connecte,
# executeurs du controleur a 0, job "premier-job" fonctionnel. Relancable.
set -euo pipefail
. "$(dirname "$0")/../../lib/commun.sh"
ICI="$(cd "$(dirname "$0")" && pwd)"

RATTRAPAGE_IMBRIQUE="${RATTRAPAGE_IMBRIQUE:-}" "$RACINE/scripts/m01/catch-up/catch-up.sh"

info "Executeurs du controleur a 0"
sed -i 's/^  numExecutors: [0-9]*/  numExecutors: 0/' "$ENV_DIR/jenkins/casc/jenkins.yaml"
jenkins_casc "$ICI/agent.yaml"
jenkins_attendre_agent agent-python

info "Job premier-job (freestyle, restreint au label python)"
jenkins_groovy "$ICI/premier-job.groovy"
