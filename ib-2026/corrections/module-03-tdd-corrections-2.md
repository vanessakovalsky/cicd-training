# Module 03 — Corrections, bloc 2

Bloc 2 (séquences S3.3, S3.4). Autre bloc : `module-03-tdd-corrections-1.md`.

Code de référence complet : `fil-rouge/solutions/m03/` (`src/fretexpress/tarification.py`, `src/fretexpress/carburant.py`, `tests/test_tarification.py`, `tests/test_carburant.py`).

## Lab 03.3 ⭐⭐ — Surcharge carburant avec doublures
### Solution
Voir `fil-rouge/solutions/m03/tests/test_carburant.py` et `src/fretexpress/carburant.py`. Extrait du repli en erreur :
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
Contrôle final :
```bash
pytest -q
ruff check .
```
Sortie attendue :
```
25 passed in 0.45s
All checks passed!
```
(solution de référence : 17 tests de tarification, 6 de carburant, 2 d'API ; le nombre varie selon les cas paramétrés écrits)
### Pourquoi
- Stub pour un état, mock pour une interaction : le test 4 est le seul qui exige un mock.
- `httpx.MockTransport` : le vrai code HTTP (URL, `raise_for_status`, lecture JSON) est exercé, seul le réseau est simulé.
- `min(taux, 20 %)` dans `CalculateurTarif` : règle métier, testée indépendamment du fournisseur.
### Variantes acceptables
- `monkeypatch.setattr(httpx, "get", ...)` : fonctionne mais couple le test au détail d'implémentation (appel de module).
- Bibliothèque `respx` : routes HTTP simulées plus expressives, dépendance supplémentaire.
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| `httpx.ConnectError` en test | Client réel créé (pas d'injection) | Passer `client=` au constructeur |
| `assert_called_once_with` échoue (2 appels) | Taux lu deux fois (plafond + calcul) | Lire une seule fois dans une variable |
| `Decimal('0.12') != 0.12` | JSON numérique lu en `float` | `Decimal(str(...))` |

## QCM — Réponses
1. **B** — Le cycle commence toujours par un test en échec (RED).
2. **B** — Code minimal ; la généralisation viendra des tests suivants.
3. **B** — Stub : réponse préprogrammée, aucune vérification.
4. **C** — Mock : vérifie les interactions (`assert_called_once_with`).
5. **B** — `Decimal` représente exactement `0.1` et maîtrise l'arrondi ; `float` non.
6. **B** — Refactoriser = améliorer la structure sans changer le comportement.
7. **B** — Injection par le constructeur : le test fournit sa doublure.
