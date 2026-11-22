#!/usr/bin/env bash
# Lab 9.3 : audit de la configuration de securite de Jenkins (script Groovy, compte admin).
set -euo pipefail
. "$(dirname "$0")/../../lib/commun.sh"
jenkins_groovy "$(dirname "$0")/audit-securite.groovy"
