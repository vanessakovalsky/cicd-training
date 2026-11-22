#!/usr/bin/env bash
# Lab 8.2 / 8.4 : duree des derniers builds de fretexpress/main (gain avant / apres).
# Usage : scripts/m08/labs/mesurer-durees.sh [NOMBRE]
set -euo pipefail
. "$(dirname "$0")/../../lib/commun.sh"
NB="${1:-10}"
curl -s -u "admin:$JENKINS_ADMIN_PASSWORD" \
  "$JENKINS_URL/job/fretexpress/job/main/api/json?tree=builds%5Bnumber,result,duration,displayName%5D%7B0,$NB%7D" \
| python3 -c '
import json, sys
print("%-20s %-10s %8s" % ("Build", "Resultat", "Duree"))
for b in json.load(sys.stdin)["builds"]:
    print("%-20s %-10s %7.0fs" % (b["displayName"], b["result"], b["duration"] / 1000))'
