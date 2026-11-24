#!/usr/bin/env python3
"""Indicateurs DORA de la chaine FretExpress, variante GitLab (defi 10.4).

Source : deploiements de l'environnement GitLab "production" (statut natif, sans convention
de description). Les commits de chaque deploiement sont lus par comparaison avec le deploiement
reussi precedent. Le calcul reutilise dora.py (memes definitions que pour Jenkins).

Usage :
  GITLAB_TOKEN=<jeton read_api> python3 scripts/m10/labs/dora_gitlab.py
Variables : GITLAB_URL (defaut http://localhost:8929), GITLAB_TOKEN, GITLAB_PROJET (dev/fretexpress).
"""

import argparse
import json
import os
import sys
import urllib.parse
import urllib.request
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dora import afficher, calculer  # noqa: E402


def api(args: argparse.Namespace, chemin: str) -> list | dict:
    projet = urllib.parse.quote(args.projet, safe="")
    requete = urllib.request.Request(f"{args.gitlab}/api/v4/projects/{projet}{chemin}")
    requete.add_header("PRIVATE-TOKEN", args.jeton)
    with urllib.request.urlopen(requete, timeout=10) as reponse:
        return json.load(reponse)


def ms(horodatage: str) -> int:
    return int(datetime.fromisoformat(horodatage.replace("Z", "+00:00")).timestamp() * 1000)


def builds_depuis_deploiements(args: argparse.Namespace) -> list[dict]:
    """Convertit les deploiements GitLab au format attendu par dora.calculer()."""
    deploiements = api(
        args,
        f"/deployments?environment={args.environnement}&order_by=id&sort=asc&per_page=100",
    )
    builds, sha_precedent, sha_echec = [], None, None
    for d in deploiements:
        if d["status"] not in ("success", "failed"):
            continue  # en cours, annule, en attente
        sha = d["sha"]
        succes = d["status"] == "success"
        if not succes and sha == sha_echec:
            continue  # tentative relancee (retry) du meme changement : un seul echec
        sha_echec = None if succes else sha
        if not succes:
            commits = []  # commits comptes au deploiement reussi suivant (comparaison)
        elif sha_precedent:
            comparaison = api(args, f"/repository/compare?from={sha_precedent}&to={sha}")
            commits = comparaison.get("commits", [])
        else:
            commits = [api(args, f"/repository/commits/{sha}")]
        builds.append(
            {
                "number": d["id"],
                "result": "SUCCESS" if succes else "FAILURE",
                "timestamp": ms(d.get("finished_at") or d["updated_at"]),
                "duration": 0,
                "description": ("deploy-prod " if succes else "echec-prod ") + d["ref"],
                "changeSets": [
                    {"items": [{"timestamp": ms(c["committed_date"])} for c in commits]}
                ],
            }
        )
        if succes:
            sha_precedent = sha
    return builds


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    p.add_argument("--gitlab", default=os.environ.get("GITLAB_URL", "http://localhost:8929"))
    p.add_argument("--jeton", default=os.environ.get("GITLAB_TOKEN", ""))
    p.add_argument("--projet", default=os.environ.get("GITLAB_PROJET", "dev/fretexpress"))
    p.add_argument("--environnement", default="production")
    p.add_argument("--json", action="store_true", help="sortie JSON")
    args = p.parse_args()
    if not args.jeton:
        print("Definir GITLAB_TOKEN (jeton d'acces personnel, portee read_api)", file=sys.stderr)
        return 2
    mesures = calculer(builds_depuis_deploiements(args))
    if args.json:
        print(json.dumps(mesures, indent=2))
    else:
        afficher(mesures)
    return 0


if __name__ == "__main__":
    sys.exit(main())
