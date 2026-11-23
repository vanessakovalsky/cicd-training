# Module 03 — Exercices, bloc 2

Bloc 2 : séquences S3.3, S3.4. Point de départ : labs du bloc 1 terminés (`module-03-tdd-exercices-1.md`).

## Lab 03.3 ⭐⭐ — Surcharge carburant avec doublures (semi-guidé)
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

### Étapes clés
1. Fichier `tests/test_carburant.py`. Stub minimal :
   ```python
   class StubCarburant:
       def __init__(self, taux: str) -> None:
           self.taux = Decimal(taux)

       def taux_actuel(self) -> Decimal:
           return self.taux
   ```
2. Tests 1 et 2 → classe `CalculateurTarif(fournisseur_carburant)` dans `tarification.py` (injection par le constructeur).
3. Test 3 → module `src/fretexpress/carburant.py`, classe `FournisseurCarburantFixe`.
4. Test 4 → `unittest.mock.Mock` et `assert_called_once_with()`.
5. Tests 5 et 6 → client HTTP injecté :
   ```python
   def _client_http(gestionnaire) -> httpx.Client:
       return httpx.Client(transport=httpx.MockTransport(gestionnaire))

   client = _client_http(lambda requete: httpx.Response(200, json={"taux": "0.12"}))
   fournisseur = FournisseurCarburantHttp("http://carburant", client=client)
   ```
6. Fin : `pytest -q`, `ruff check .`, push de la branche, merge request, revue par `reviewer`, fusion.

### Critères de réussite
- [ ] Les 6 tests de la liste passent sans aucun accès réseau
- [ ] `CalculateurTarif` reçoit son fournisseur par le constructeur
- [ ] `ruff check .` : `All checks passed!`
- [ ] MR `feat/tarification` fusionnée dans `main` après revue
