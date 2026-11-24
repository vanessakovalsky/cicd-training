# Module 03 — Corrections, bloc 1

Bloc 1 (séquences S3.1, S3.2). Autre bloc : `module-03-tdd-corrections-2.md`.

Code de référence complet : `fil-rouge/solutions/m03/` (`src/fretexpress/tarification.py`, `src/fretexpress/carburant.py`, `tests/test_tarification.py`, `tests/test_carburant.py`).

## Lab 03.1 ⭐ — Kata TDD : les trois premiers cycles
### Solution
État après la règle 3 :
```python
from decimal import Decimal
from math import ceil

PRIX_BASE = Decimal("5.00")
PRIX_KG_SUPPLEMENTAIRE = Decimal("1.50")
COEFFICIENTS_ZONE = {"FR": Decimal("1.0"), "UE": Decimal("1.5"), "MONDE": Decimal("2.5")}


def calculer_tarif(poids_kg, zone):
    poids = Decimal(str(poids_kg))
    kg_supplementaires = max(0, ceil(poids - 1))
    tarif = PRIX_BASE + PRIX_KG_SUPPLEMENTAIRE * kg_supplementaires
    return tarif * COEFFICIENTS_ZONE[zone]
```
### Pourquoi
- `Decimal(str(poids_kg))` : `Decimal(1.2)` donnerait `1.1999999999999999555910790149937…`.
- `ceil(poids - 1)` : « kg entamé » ; `max(0, …)` couvre les poids inférieurs à 1 kg.
- Étape GREEN de la règle 1 (`return Decimal("5.00")`) volontairement naïve : le test suivant force la généralisation (« triangulation »).
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| `ModuleNotFoundError: No module named 'fretexpress'` | Paquet non installé dans le venv actif | `. .venv/bin/activate && pip install -e ".[dev]"` |
| `assert Decimal('5.0') == Decimal('5.00')` échoue ? | Non : `Decimal('5.0') == Decimal('5.00')` est vrai | Comparaison numérique ; seul l'affichage diffère |
| Test vert dès l'écriture | Comportement déjà implémenté ou test mal écrit | Le casser volontairement pour vérifier qu'il peut échouer |
| Tests dans un ordre différent à chaque lancement | `pytest-randomly` installé (voulu) | Normal ; module 04 |

## Exercice 03.2 ⭐⭐ — Kata TDD : règles 4 à 6
### Solution
Voir `fil-rouge/solutions/m03/src/fretexpress/tarification.py`, fonction `calculer_tarif` : contrôles (poids, zone) en tête, base, zone, express, remise, arrondi `_arrondir()`.
Calcul du cas de contrôle : `(5 + 1,5 × 3) × 1,5 × 1,4 × 0,9 = 17,955 → 17,96`.
### Pourquoi
- Contrôles en tête (clauses de garde) : lisibilité, une erreur explicite par cas.
- Arrondi unique en fin de calcul : arrondir à chaque étape cumule les écarts.
### Variantes acceptables
- Arrondi par `round(x, 2)` sur `Decimal` : `round` utilise l'arrondi bancaire (`ROUND_HALF_EVEN`) → `17.955` donne `17.96` ici, mais `0.125` donnerait `0.12` ; `quantize` + `ROUND_HALF_UP` explicite la règle commerciale.
- Remise exprimée par un dictionnaire `REMISES` : facilite l'ajout d'un code.
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| `17.95` au lieu de `17.96` | Arrondi bancaire ou arrondi intermédiaire | `quantize(..., ROUND_HALF_UP)` une seule fois |
| `KeyError: 'LUNE'` | Zone non contrôlée avant l'accès au dictionnaire | Lever `ZoneInconnue` avant le calcul |
| `30.01` accepté | Condition `>=` / `>` inversée | Test paramétré sur `30` et `30.01` |

## Défi 03.4 ⭐⭐⭐ — Tests de propriétés
### Solution
`pyproject.toml` : ajouter `"hypothesis==<VERSION>"` aux dépendances `dev` (version courante relevée par `pip index versions hypothesis`).
```python
from decimal import Decimal

from hypothesis import given
from hypothesis import strategies as st

from fretexpress.tarification import calculer_tarif

poids = st.decimals(min_value=Decimal("0.01"), max_value=Decimal("30"), places=2)


@given(a=poids, b=poids)
def test_tarif_croissant_avec_le_poids(a, b):
    petit, grand = sorted((a, b))
    assert calculer_tarif(petit, "UE") <= calculer_tarif(grand, "UE")


@given(p=poids)
def test_express_jamais_moins_cher(p):
    assert calculer_tarif(p, "FR", express=True) >= calculer_tarif(p, "FR")
```
### Pourquoi
Test par exemples : quelques cas choisis. Test de propriétés : un invariant vérifié sur des centaines d'entrées générées, avec réduction automatique du contre-exemple en cas d'échec.

## Bonus
Avec `>=` : seul le test `30 → 48.50` (cas limite) échoue. Sans ce test, le bug passe : les cas limites sont les tests les plus rentables.
