# Module 04 — Exercices, bloc 1

Bloc 1 : séquences S4.1, S4.2. Bloc 2 : `module-04-pyramide-tests-exercices-2.md`.

Préparation commune (code livré par un collègue, sans tests d'intégration) :
```bash
cd ~/fretexpress && git switch main && git pull
git switch -c test/integration-devis
<FORMATION>/scripts/m04/labs/installer-depart.sh ~/fretexpress
. .venv/bin/activate && pip install --quiet -e ".[dev]"
git add -A && git commit -m "feat(devis): API de devis et depot SQLite (livraison collegue)"
```
Résultat attendu : `Copies : src/fretexpress/api.py, src/fretexpress/devis.py, tests/test_numerotation.py`.
`<FORMATION>` = dossier de la formation (VM : `/opt/formation`).

## Lab 04.1 ⭐ — Tests d'intégration de l'API de devis (guidé)
**Durée** : 50 min · **Objectif** : API `/devis` et dépôt SQLite testés ensemble, sans réseau
**Contexte** : l'API de devis part en recette la semaine prochaine ; aucun test ne couvre l'enchaînement HTTP → calcul → base.

### Étapes
1. Créer `tests/integration/conftest.py` :
   ```python
   from decimal import Decimal

   import pytest
   from fastapi.testclient import TestClient

   from fretexpress.api import app, get_calculateur, get_depot
   from fretexpress.carburant import FournisseurCarburantFixe
   from fretexpress.devis import DepotDevis
   from fretexpress.tarification import CalculateurTarif


   def pytest_collection_modifyitems(items):
       for item in items:
           if "/integration/" in str(item.fspath):
               item.add_marker(pytest.mark.integration)


   @pytest.fixture
   def depot(tmp_path):
       return DepotDevis(str(tmp_path / "test.db"))


   @pytest.fixture
   def client(depot):
       app.dependency_overrides[get_depot] = lambda: depot
       app.dependency_overrides[get_calculateur] = lambda: CalculateurTarif(
           FournisseurCarburantFixe(Decimal("0.10"))
       )
       yield TestClient(app)
       app.dependency_overrides.clear()
   ```
2. Créer `tests/integration/test_depot_devis.py` : enregistrer puis relire un devis ; numéros séquentiels `D-0001`, `D-0002` ; devis inexistant → `None`.
   ```python
   from decimal import Decimal


   def test_enregistrer_puis_trouver_un_devis(depot):
       cree = depot.enregistrer(Decimal("2"), "UE", Decimal("9.75"))

       relu = depot.trouver(cree.numero)

       assert relu is not None
       assert (relu.numero, relu.montant, relu.zone) == ("D-0001", Decimal("9.75"), "UE")
   ```
   Écrire les deux autres tests sur le même modèle.
3. Créer `tests/integration/test_api_devis.py` avec le premier test :
   ```python
   def test_creer_un_devis_renvoie_201_et_le_montant(client):
       reponse = client.post("/devis", json={"poids_kg": 1, "zone": "FR"})

       assert reponse.status_code == 201
       assert reponse.json() == {"numero": "D-0001", "montant": "5.50"}
   ```
4. Lancer uniquement l'intégration.
   ```bash
   pytest -m integration -v -p no:randomly
   ```
   Résultat attendu (fin) : `4 passed, 28 deselected`.
5. Ajouter (⭐⭐, sans modèle) : relecture d'un devis créé (`2 kg UE` → `"10.73"`), devis inconnu → `404`, zone inconnue → `422` avec `Zone inconnue` dans `detail`, poids de 31 kg → `422`.
6. Commit `test(devis): tests d'integration API et depot`.

### Critères de réussite
- [ ] `pytest -m integration` : 8 tests au vert
- [ ] Aucun fichier `fretexpress.db` créé dans le dépôt (`git status` propre)
- [ ] Aucun appel réseau (le fournisseur carburant est un fake)
