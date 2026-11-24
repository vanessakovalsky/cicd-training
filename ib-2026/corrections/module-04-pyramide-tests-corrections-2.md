# Module 04 — Corrections, bloc 2

Bloc 2 (séquences S4.3, S4.4). Autre bloc : `module-04-pyramide-tests-corrections-1.md`.

Code de référence : `fil-rouge/solutions/m04/` (`tests/integration/`, `tests/test_numerotation.py`, `src/fretexpress/devis.py`).

## Exercice 04.2 ⭐⭐ — Mesurer la couverture et combler les manques
### Solution
```bash
pytest -p no:randomly --cov=fretexpress --cov-branch --cov-report=term-missing
```
Sortie attendue (après les labs 04.1 et 04.3) :
```
Name                              Stmts   Miss Branch BrPart  Cover   Missing
-----------------------------------------------------------------------------
src/fretexpress/__init__.py           5      2      0      0    60%   7-8
src/fretexpress/api.py               47      4      2      0    92%   33, 38-40
src/fretexpress/carburant.py         22      0      0      0   100%
src/fretexpress/devis.py             36      0      2      0   100%
src/fretexpress/tarification.py      39      0     10      0   100%
-----------------------------------------------------------------------------
TOTAL                               149      6     14      0    96%
```
### Pourquoi
- Manques restants : `get_depot()` et `get_calculateur()` réels (lignes 33, 38-40) = câblage de configuration, vérifié par le test de fumée après déploiement (module 07) ; `__init__.py` lignes 7-8 = repli si le paquet n'est pas installé.
- Couverture avant / après : 80 % → 96 % ; `api.py` 67 % → 92 %, `devis.py` 63 % → 100 %.
### Variantes acceptables
- Test unitaire de `get_calculateur()` avec `monkeypatch.setenv("FRETEXPRESS_CARBURANT_URL", ...)` : acceptable, porte la couverture à ≈ 98 %.
- Exclusion par `# pragma: no cover` des lignes de repli : acceptable si justifiée dans la MR.
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| `Module fretexpress was never imported` | `--cov=src` ou nom de paquet erroné | `--cov=fretexpress` |
| Couverture à 0 % pour `api.py` | Tests lancés depuis un autre dossier | Lancer depuis la racine du dépôt |

## Lab 04.3 ⭐⭐ — Diagnostiquer et stabiliser un test instable
### Solution
Cause : `prochain_numero()` utilise un compteur global (`_numeroteur_global`) qui survit d'un test à l'autre ; le résultat dépend de l'ordre d'exécution.
`tests/test_numerotation.py` corrigé :
```python
import re

import pytest

from fretexpress.devis import Numeroteur


@pytest.fixture
def numeroteur():
    return Numeroteur()  # instance neuve a chaque test : aucun etat partage


def test_premier_devis_numerote_d0001(numeroteur):
    assert numeroteur.prochain_numero() == "D-0001"


def test_deuxieme_devis_numerote_d0002(numeroteur):
    numeroteur.prochain_numero()

    assert numeroteur.prochain_numero() == "D-0002"


def test_format_du_numero(numeroteur):
    assert re.fullmatch(r"D-\d{4}", numeroteur.prochain_numero())
```
Puis suppression de l'API historique globale dans `devis.py` (plus aucun appelant).
### Pourquoi
- Correctif à la source : chaque test crée son état ; l'ordre aléatoire devient sans effet.
- `pytest-randomly` conservé : il détecte les futures dépendances d'ordre.
### Variantes acceptables
- Fixture `autouse` qui réinitialise le compteur global : stabilise, mais conserve un état global dans le code de production (moins bon).
- Assertion sur le format seulement (`D-\d{4}`) : stabilise, mais ne teste plus la séquence.
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| Échec non reproductible | Graine non relevée | Copier la ligne `Using --randomly-seed=...` |
| Correctif par `-p no:randomly` dans `pyproject.toml` | Symptôme masqué | Refusé en revue |

## Défi 04.4 ⭐⭐⭐ — Validité d'un devis sans dépendance au temps
### Solution
```python
from datetime import timedelta

VALIDITE = timedelta(days=7)

# dans la classe Devis
    def est_expire(self, maintenant: datetime) -> bool:
        return maintenant >= self.cree_le + VALIDITE
```
```python
from datetime import UTC, datetime, timedelta
from decimal import Decimal

from fretexpress.devis import Devis

CREATION = datetime(2026, 11, 10, 9, 0, tzinfo=UTC)


def devis():
    return Devis("D-0001", Decimal("1"), "FR", Decimal("5.00"), cree_le=CREATION)


def test_devis_valide_jusqu_a_7_jours_moins_1_seconde():
    assert not devis().est_expire(CREATION + timedelta(days=7, seconds=-1))


def test_devis_expire_a_7_jours():
    assert devis().est_expire(CREATION + timedelta(days=7))
```
### Pourquoi
Un test fondé sur `datetime.now()` dépend de l'instant d'exécution (minuit, changement d'heure, lenteur de la machine) ; l'instant injecté rend le résultat déterministe.

## Bonus
`coverage combine` fusionne les mesures de deux exécutions séparées : base de la parallélisation des tests au module 08.

## QCM — Réponses
1. **C** — Les tests unitaires, rapides et précis, forment la base.
2. **B** — Chaque issue (vrai / faux) de chaque condition.
3. **B** — Couverture = exécution, pas vérification.
4. **B** — `--cov-fail-under=90` fait échouer pytest sous le seuil.
5. **B** — Symptôme typique d'un état partagé entre tests.
6. **C** — Reproduire, isoler, corriger ; la relance masque le problème.
7. **B** — Dépendance externe remplacée par un fake via `dependency_overrides`.
