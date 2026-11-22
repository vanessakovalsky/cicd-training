#!/usr/bin/env python3
"""Indicateurs DORA de la chaine FretExpress, calcules depuis l'API Jenkins.

Conventions du pipeline (Jenkinsfile du module 10) :
  - description "deploy-prod <version>" : deploiement en production reussi ;
  - description "echec-prod <version>"  : deploiement en production en echec.

Usage :
  python3 scripts/m10/labs/dora.py                       # API Jenkins locale
  python3 scripts/m10/labs/dora.py --fichier builds.json # jeu de donnees (plan B)
Variables : JENKINS_URL (defaut http://localhost:8080), JENKINS_USER, JENKINS_TOKEN.
"""

import argparse
import base64
import json
import os
import statistics
import sys
import urllib.request
from datetime import datetime, timezone

ARBRE = (
    "builds[number,result,timestamp,duration,description,"
    "changeSets[items[commitId,timestamp,msg]]]"
)


def lire_builds(args: argparse.Namespace) -> list[dict]:
    if args.fichier:
        with open(args.fichier, encoding="utf-8") as f:
            return json.load(f)["builds"]
    url = f"{args.jenkins}/job/{args.job}/job/{args.branche}/api/json?tree={ARBRE}"
    requete = urllib.request.Request(url)
    jeton = base64.b64encode(f"{args.utilisateur}:{args.jeton}".encode()).decode()
    requete.add_header("Authorization", f"Basic {jeton}")
    with urllib.request.urlopen(requete, timeout=10) as reponse:
        return json.load(reponse)["builds"]


def heures(ms: float) -> float:
    return ms / 3_600_000


def calculer(builds: list[dict]) -> dict:
    builds = sorted((b for b in builds if b.get("result")), key=lambda b: b["number"])
    deploiements, echecs, delais, restaurations = [], [], [], []
    commits_en_attente: list[int] = []
    debut_incident = None

    for b in builds:
        fin = b["timestamp"] + b["duration"]
        for cs in b.get("changeSets", []):
            commits_en_attente += [item["timestamp"] for item in cs.get("items", [])]
        description = b.get("description") or ""
        if description.startswith("deploy-prod"):
            deploiements.append(fin)
            delais += [fin - t for t in commits_en_attente]
            commits_en_attente = []
            if debut_incident is not None:
                restaurations.append(fin - debut_incident)
                debut_incident = None
        elif description.startswith("echec-prod"):
            echecs.append(fin)
            debut_incident = debut_incident or fin

    tentatives = len(deploiements) + len(echecs)
    jours = 1.0
    if tentatives >= 2:
        toutes = sorted(deploiements + echecs)
        jours = max((toutes[-1] - toutes[0]) / 86_400_000, 1 / 24)
    return {
        "deploiements": len(deploiements),
        "frequence_par_jour": len(deploiements) / jours,
        "delai_median_h": heures(statistics.median(delais)) if delais else None,
        "taux_echec_pct": 100 * len(echecs) / tentatives if tentatives else None,
        "restauration_mediane_h": heures(statistics.median(restaurations))
        if restaurations
        else None,
    }


def niveau(m: dict) -> str:
    """Repere indicatif (seuils des rapports DORA, a rapprocher du rapport en vigueur)."""
    if m["deploiements"] == 0:
        return "aucun deploiement"
    if (
        m["frequence_par_jour"] >= 1
        and (m["delai_median_h"] or 0) < 24
        and (m["taux_echec_pct"] or 0) <= 15
    ):
        return "elite / haute performance"
    if m["frequence_par_jour"] >= 1 / 7:
        return "performance moyenne"
    return "performance faible"


def afficher(m: dict) -> None:
    def f(valeur, unite):
        return "n/a" if valeur is None else f"{valeur:.2f} {unite}"

    print("Indicateurs DORA - FretExpress (branche main)")
    print(f"  Deploiements en production   : {m['deploiements']}")
    print(f"  Frequence de deploiement     : {f(m['frequence_par_jour'], 'par jour')}")
    print(f"  Delai de mise en production  : {f(m['delai_median_h'], 'h (mediane)')}")
    print(f"  Taux d'echec des changements : {f(m['taux_echec_pct'], '%')}")
    print(f"  Temps de restauration        : {f(m['restauration_mediane_h'], 'h (mediane)')}")
    print(f"  Repere                       : {niveau(m)}")
    print(f"  Calcule le {datetime.now(timezone.utc):%Y-%m-%d %H:%M} UTC")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    p.add_argument("--jenkins", default=os.environ.get("JENKINS_URL", "http://localhost:8080"))
    p.add_argument("--utilisateur", default=os.environ.get("JENKINS_USER", "admin"))
    p.add_argument("--jeton", default=os.environ.get("JENKINS_TOKEN", ""))
    p.add_argument("--job", default="fretexpress")
    p.add_argument("--branche", default="main")
    p.add_argument("--fichier", help="jeu de donnees JSON au format de l'API Jenkins")
    p.add_argument("--json", action="store_true", help="sortie JSON")
    args = p.parse_args()
    if not args.fichier and not args.jeton:
        print("Definir JENKINS_TOKEN (jeton d'API ou mot de passe) ou --fichier", file=sys.stderr)
        return 2
    mesures = calculer(lire_builds(args))
    if args.json:
        print(json.dumps(mesures, indent=2))
    else:
        afficher(mesures)
    return 0


if __name__ == "__main__":
    sys.exit(main())
