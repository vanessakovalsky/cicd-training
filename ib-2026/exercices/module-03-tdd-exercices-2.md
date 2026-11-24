# Module 03 — Exercices, bloc 2

Bloc 2 : séquences S3.3, S3.4. Point de départ : labs du bloc 1 terminés (`module-03-tdd-exercices-1.md`).

## Lab 03.3 ⭐⭐ — Surcharge carburant avec doublures (guidé)
**Durée** : 50 min · **Objectif** : `CalculateurTarif` testé sans réseau, avec stub, fake, mock et transport HTTP simulé
**Contexte** : la surcharge carburant change chaque semaine ; elle est publiée par un service HTTP du transporteur partenaire.

### Liste de tests (une ligne = un cycle red / green)
| # | Comportement | Doublure |
|---|---|---|
| 1 | Taux 10 % : 1 kg FR → `5.50` | Stub (`StubCarburant("0.10")`) |
| 2 | Taux 35 % plafonné à 20 % : 1 kg FR → `6.00` | Stub |
| 3 | Fake `FournisseurCarburantFixe()` (15 % par défaut) : 1 kg FR → `5.75` | Fake |
| 4 | `taux_actuel()` appelé exactement une fois par calcul | Mock |
| 5 | `FournisseurCarburantHttp` lit `{"taux": "0.12"}` → `Decimal("0.12")` | `httpx.MockTransport` |
| 6 | Service en erreur `503` → taux par défaut `0.15` | `httpx.MockTransport` |

### Repères Python
| Syntaxe | Sens |
|---|---|
| `class StubCarburant:` | Définition d'une classe (≈ classe Java / C#) |
| `def __init__(self, taux):` | Constructeur ; `self` = l'instance courante (≈ `this`) |
| `self._taux = taux` | Attribut ; `_` en préfixe = usage interne (convention) |
| `taux: str`, `-> Decimal` | Annotations de type : documentation, non vérifiées à l'exécution |
| `client or httpx.Client()` | `client` s'il est fourni, sinon un nouveau client |
| `lambda requete: ...` | Fonction anonyme d'une ligne (≈ `requete => ...`) |
| `try: ... except (A, B):` | ≈ `try / catch` |

Point de départ : branche `feat/tarification`, environnement virtuel actif (`. .venv/bin/activate`), `pytest -q` au vert.

### Étapes
1. **RED (test 1, stub)** — créer `tests/test_carburant.py` :
   ```python
   from decimal import Decimal

   from fretexpress.tarification import CalculateurTarif


   class StubCarburant:
       """Stub : reponse preprogrammee, aucune verification d'appel."""

       def __init__(self, taux: str) -> None:
           self.taux = Decimal(taux)

       def taux_actuel(self) -> Decimal:
           return self.taux


   def test_surcharge_carburant_appliquee_au_tarif_de_base():
       calculateur = CalculateurTarif(StubCarburant("0.10"))

       assert calculateur.tarif_final(1, "FR") == Decimal("5.50")
   ```
   ```bash
   pytest -q
   ```
   Résultat attendu :
   ```
   E   ImportError: cannot import name 'CalculateurTarif' from 'fretexpress.tarification'
   ```
   Commit `test(carburant): surcharge appliquee au tarif de base`.
2. **GREEN** — ajouter à la fin de `src/fretexpress/tarification.py` (`_arrondir` existe déjà depuis l'exercice 03.2 ; sinon, la copier depuis la correction) :
   ```python
   from typing import Protocol   # à placer avec les autres imports, en tête de fichier


   class FournisseurCarburant(Protocol):
       """Dependance externe : taux de surcharge carburant (ex. Decimal("0.12"))."""

       def taux_actuel(self) -> Decimal: ...


   class CalculateurTarif:
       """Tarif final = tarif de base + surcharge carburant."""

       def __init__(self, fournisseur_carburant: FournisseurCarburant) -> None:
           self._fournisseur = fournisseur_carburant   # dépendance reçue, pas créée

       def tarif_final(
           self,
           poids_kg: Decimal | float | int,
           zone: str,
           express: bool = False,
           code_remise: str | None = None,
       ) -> Decimal:
           base = calculer_tarif(poids_kg, zone, express, code_remise)
           taux = self._fournisseur.taux_actuel()
           return _arrondir(base * (1 + taux))
   ```
   (`Protocol` = contrat « tout objet qui a une méthode `taux_actuel()` » ; ≈ interface)
   `pytest -q` → tous les tests au vert. Commit `feat(carburant): calculateur avec surcharge injectee`.
3. **RED (test 2, plafond)** — ajouter à `tests/test_carburant.py` :
   ```python
   def test_taux_carburant_plafonne_a_20_pourcent():
       calculateur = CalculateurTarif(StubCarburant("0.35"))

       assert calculateur.tarif_final(1, "FR") == Decimal("6.00")
   ```
   Résultat attendu :
   ```
   E       AssertionError: assert Decimal('6.75') == Decimal('6.00')
   ```
   Commit `test(carburant): taux plafonne a 20 %`.
4. **GREEN** — dans `tarification.py` : constante avec les autres, puis plafond dans `tarif_final` :
   ```python
   TAUX_CARBURANT_MAX = Decimal("0.20")
   ```
   ```python
           taux = min(self._fournisseur.taux_actuel(), TAUX_CARBURANT_MAX)
   ```
   `pytest -q` → vert. Commit `feat(carburant): plafond du taux`.
5. **RED (test 3, fake)** — dans `tests/test_carburant.py`, ajouter l'import en tête puis le test :
   ```python
   from fretexpress.carburant import FournisseurCarburantFixe
   ```
   ```python
   def test_fake_taux_fixe_par_defaut():
       calculateur = CalculateurTarif(FournisseurCarburantFixe())

       assert calculateur.tarif_final(1, "FR") == Decimal("5.75")
   ```
   Résultat attendu :
   ```
   E   ModuleNotFoundError: No module named 'fretexpress.carburant'
   ```
   Commit `test(carburant): fake a taux fixe`.
6. **GREEN** — créer `src/fretexpress/carburant.py` :
   ```python
   """Fournisseurs du taux de surcharge carburant."""

   from decimal import Decimal

   TAUX_PAR_DEFAUT = Decimal("0.15")


   class FournisseurCarburantFixe:
       """Fake : taux constant, utilisable en test et en environnement sans service carburant."""

       def __init__(self, taux: Decimal = TAUX_PAR_DEFAUT) -> None:
           self._taux = taux

       def taux_actuel(self) -> Decimal:
           return self._taux
   ```
   `pytest -q` → vert. Commit `feat(carburant): fournisseur a taux fixe`.
7. **Test 4 (mock)** — ajouter l'import `from unittest.mock import Mock` en tête, puis :
   ```python
   def test_le_fournisseur_est_interroge_une_seule_fois_par_calcul():
       mock = Mock()
       mock.taux_actuel.return_value = Decimal("0")   # le mock répond 0

       CalculateurTarif(mock).tarif_final(1, "FR")

       mock.taux_actuel.assert_called_once_with()     # vérifie l'INTERACTION
   ```
   Résultat attendu : le test passe déjà → vérifier qu'il PEUT échouer : ajouter temporairement la ligne `self._fournisseur.taux_actuel()` au début de `tarif_final`, constater l'échec, retirer la ligne.
   ```
   E           AssertionError: Expected 'taux_actuel' to be called once. Called 2 times.
   ```
   Commit `test(carburant): un seul appel au fournisseur`.
8. **RED (test 5, HTTP simulé)** — remplacer le bloc d'imports en tête de `tests/test_carburant.py` par :
   ```python
   from decimal import Decimal
   from unittest.mock import Mock

   import httpx

   from fretexpress.carburant import FournisseurCarburantFixe, FournisseurCarburantHttp
   from fretexpress.tarification import CalculateurTarif
   ```
   puis ajouter à la fin :
   ```python
   def _client_http(gestionnaire) -> httpx.Client:
       """Client HTTP dont les réponses viennent de `gestionnaire` : aucun réseau."""
       return httpx.Client(transport=httpx.MockTransport(gestionnaire))


   def test_fournisseur_http_lit_le_taux_du_service():
       client = _client_http(lambda requete: httpx.Response(200, json={"taux": "0.12"}))

       fournisseur = FournisseurCarburantHttp("http://carburant", client=client)

       assert fournisseur.taux_actuel() == Decimal("0.12")
   ```
   Résultat attendu :
   ```
   E   ImportError: cannot import name 'FournisseurCarburantHttp' from 'fretexpress.carburant'
   ```
   Commit `test(carburant): lecture du taux par HTTP`.
9. **GREEN** — dans `carburant.py`, ajouter `import httpx` sous `from decimal import Decimal` (ligne vide entre les deux), puis la classe (avant `FournisseurCarburantFixe`) :
   ```python
   class FournisseurCarburantHttp:
       """Implementation reelle : interroge le service carburant (GET <url>/taux)."""

       def __init__(self, url: str, client: httpx.Client | None = None, timeout: float = 2.0) -> None:
           self._url = url.rstrip("/")
           self._client = client or httpx.Client(timeout=timeout)   # client injecté en test

       def taux_actuel(self) -> Decimal:
           reponse = self._client.get(f"{self._url}/taux")
           reponse.raise_for_status()                    # erreur si code HTTP 4xx / 5xx
           return Decimal(str(reponse.json()["taux"]))
   ```
   `pytest -q` → vert. Commit `feat(carburant): fournisseur HTTP`.
10. **RED (test 6, service en panne)** — remplacer l'import de `fretexpress.carburant` par :
    ```python
    from fretexpress.carburant import (
        TAUX_PAR_DEFAUT,
        FournisseurCarburantFixe,
        FournisseurCarburantHttp,
    )
    ```
    puis ajouter :
    ```python
    def test_fournisseur_http_bascule_sur_le_taux_par_defaut_si_service_en_erreur():
        client = _client_http(lambda requete: httpx.Response(503))

        fournisseur = FournisseurCarburantHttp("http://carburant", client=client)

        assert fournisseur.taux_actuel() == TAUX_PAR_DEFAUT
    ```
    Résultat attendu :
    ```
    E       httpx.HTTPStatusError: Server error '503 Service Unavailable' for url 'http://carburant/taux'
    ```
    Commit `test(carburant): repli si service en erreur`.
11. **GREEN** — dans `carburant.py` : `import logging` en tête (avant `from decimal ...`), le journal sous `TAUX_PAR_DEFAUT`, puis `taux_actuel` protégée :
    ```python
    journal = logging.getLogger(__name__)
    ```
    ```python
        def taux_actuel(self) -> Decimal:
            try:
                reponse = self._client.get(f"{self._url}/taux")
                reponse.raise_for_status()
                return Decimal(str(reponse.json()["taux"]))
            except (httpx.HTTPError, KeyError, ValueError) as erreur:
                journal.warning("Service carburant indisponible (%s) : taux par defaut", erreur)
                return TAUX_PAR_DEFAUT
    ```
    (`HTTPError` = panne ou code d'erreur ; `KeyError` = clé `taux` absente ; `ValueError` = JSON illisible)
    `pytest -q` → vert. Commit `feat(carburant): taux par defaut si service indisponible`.
12. **Fin** — contrôles, puis livraison :
    ```bash
    pytest -q
    ruff check .          # imports mal ordonnés : ruff check --fix .
    git push -u origin feat/tarification
    ```
    Merge request `feat/tarification` → `main`, revue par `reviewer`, fusion.

### Critères de réussite
- [ ] Les 6 tests de la liste passent sans aucun accès réseau
- [ ] `CalculateurTarif` reçoit son fournisseur par le constructeur
- [ ] `ruff check .` : `All checks passed!`
- [ ] MR `feat/tarification` fusionnée dans `main` après revue
