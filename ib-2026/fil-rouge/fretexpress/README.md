# FretExpress

API de calcul de tarifs d'expedition (Python 3.12, FastAPI).

## Demarrage

```bash
python3.12 -m venv .venv
. .venv/bin/activate
pip install -e ".[dev]"
pytest
uvicorn fretexpress.api:app --reload
```

## Deploiement actuel

Manuel, depuis le poste de Kevin (a remplacer par une chaine CI/CD).
