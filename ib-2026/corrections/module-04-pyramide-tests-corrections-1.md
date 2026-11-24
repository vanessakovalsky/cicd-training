# Module 04 — Corrections, bloc 1

Bloc 1 (séquences S4.1, S4.2). Autre bloc : `module-04-pyramide-tests-corrections-2.md`.

Code de référence : `fil-rouge/solutions/m04/` (`tests/integration/`, `tests/test_numerotation.py`, `src/fretexpress/devis.py`).

## Lab 04.1 ⭐ — Tests d'intégration de l'API de devis
### Solution
`tests/integration/test_api_devis.py` (tests de l'étape 5) :
```python
def test_relire_un_devis_cree(client):
    numero = client.post("/devis", json={"poids_kg": 2, "zone": "UE"}).json()["numero"]

    reponse = client.get(f"/devis/{numero}")

    assert reponse.status_code == 200
    assert reponse.json()["montant"] == "10.73"


def test_devis_inconnu_renvoie_404(client):
    assert client.get("/devis/D-9999").status_code == 404


def test_zone_inconnue_renvoie_422(client):
    reponse = client.post("/devis", json={"poids_kg": 1, "zone": "LUNE"})

    assert reponse.status_code == 422
    assert "Zone inconnue" in reponse.json()["detail"]


def test_poids_hors_limites_rejete_par_la_validation(client):
    assert client.post("/devis", json={"poids_kg": 31, "zone": "FR"}).status_code == 422
```
Calcul de contrôle : `2 kg UE = 6,50 × 1,5 = 9,75` ; `× 1,10 (carburant 10 %) = 10,725 → 10,73`.
### Pourquoi
- `tmp_path` : base neuve par test ; les numéros `D-0001` sont prévisibles.
- `dependency_overrides` : mécanisme officiel de FastAPI pour remplacer une dépendance en test ; `clear()` en fin de fixture évite la fuite vers les autres tests.
- Fake carburant à 10 % : montants calculables à la main.
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| `fretexpress.db` apparaît dans le dépôt | Dépendance réelle `get_depot()` utilisée | Fixture `client` qui surcharge `get_depot` |
| Numéro `D-0003` au lieu de `D-0001` | Même base partagée entre tests | `tmp_path` dans la fixture `depot` |
| `assert '10.725' == '10.73'` | Arrondi absent après la surcharge | `CalculateurTarif.tarif_final` arrondit (module 03) |
| `PytestUnknownMarkWarning: integration` | Marqueur non déclaré | Déjà déclaré dans `pyproject.toml` (`markers`) |
