# Module 03 — Exercices, bloc 1

Bloc 1 : séquences S3.1, S3.2. Bloc 2 : `module-03-tdd-exercices-2.md`.

Travail sur une branche : `main` est protégée (module 01). Préparation commune :
```bash
cd ~/fretexpress && git switch main && git pull
git switch -c feat/tarification
python3 -m venv .venv && . .venv/bin/activate
pip install --quiet -e ".[dev]"
pytest -q
```
Résultat attendu : `2 passed`.

## Lab 03.1 ⭐ — Kata TDD : les trois premiers cycles (guidé)
**Durée** : 35 min · **Objectif** : règles 1 à 3 du kata développées en red / green / refactor, un commit par étape
**Contexte** : la grille tarifaire de FretExpress n'existe que dans un tableur ; elle doit devenir du code testé.
**Prérequis** : préparation commune ci-dessus

### Étapes
1. **RED (règle 1)** — créer `tests/test_tarification.py` :
   ```python
   from decimal import Decimal

   from fretexpress.tarification import calculer_tarif


   def test_colis_de_1_kg_en_france_coute_le_prix_de_base():
       assert calculer_tarif(1, "FR") == Decimal("5.00")
   ```
   ```bash
   pytest -q
   ```
   Résultat attendu :
   ```
   E   ModuleNotFoundError: No module named 'fretexpress.tarification'
   ```
   ```bash
   git add tests/test_tarification.py && git commit -m "test(tarif): prix de base pour 1 kg en France"
   ```
2. **GREEN** — créer `src/fretexpress/tarification.py` avec le code le plus simple :
   ```python
   from decimal import Decimal


   def calculer_tarif(poids_kg, zone):
       return Decimal("5.00")
   ```
   ```bash
   pytest -q
   git add src/fretexpress/tarification.py && git commit -m "feat(tarif): prix de base"
   ```
   Résultat attendu : `3 passed`.
3. **RED (règle 2)** — ajouter :
   ```python
   def test_kg_entame_au_dela_de_1_kg_coute_1_50():
       assert calculer_tarif(2, "FR") == Decimal("6.50")
   ```
   Résultat attendu :
   ```
   E       AssertionError: assert Decimal('5.00') == Decimal('6.50')
   ```
   Commit `test(tarif): supplement par kg entame`.
4. **GREEN** — implémenter avec `math.ceil` :
   ```python
   from decimal import Decimal
   from math import ceil


   def calculer_tarif(poids_kg, zone):
       poids = Decimal(str(poids_kg))
       kg_supplementaires = max(0, ceil(poids - 1))
       return Decimal("5.00") + Decimal("1.50") * kg_supplementaires
   ```
   `pytest -q` → `4 passed`. Commit `feat(tarif): supplement par kg entame`.
5. **RED** — cas limites en un test paramétré : `0.5 → 5.00`, `1.2 → 6.50`, `2.01 → 8.00`, `30 → 48.50`. Résultat attendu : les 4 cas passent déjà → vérifier qu'ils PEUVENT échouer (remplacer temporairement `6.50` par `6.60`, constater l'échec, rétablir). Commit `test(tarif): cas limites du poids`.
6. **REFACTOR** — extraire les constantes `PRIX_BASE` et `PRIX_KG_SUPPLEMENTAIRE` ; `pytest -q` toujours vert ; commit `refactor(tarif): constantes de la grille`.
7. **Règle 3 (zones)** — même cycle : test paramétré `FR 5.00`, `UE 7.50`, `MONDE 12.50` (RED), dictionnaire `COEFFICIENTS_ZONE` (GREEN), refactorisation si besoin.
8. Vérifier l'historique.
   ```bash
   git log --oneline
   ```
   Résultat attendu : alternance `test(...)` / `feat(...)` / `refactor(...)`.

### Critères de réussite
- [ ] Au moins 6 commits alternant `test` et `feat` (puis `refactor`)
- [ ] Chaque commit `test` a été constaté en échec avant le commit `feat` suivant
- [ ] `pytest -q` : tous les tests au vert, aucun test commenté

---

## Exercice 03.2 ⭐⭐ — Kata TDD : règles 4 à 6 (guidé)
**Durée** : 40 min · **Objectif** : terminer le moteur de tarification en TDD strict, un test à la fois
**Règles à développer** :
- règle 4 : option `express=True` → + 40 % ;
- règle 5 : poids ≤ 0 ou > 30 kg → `PoidsInvalide` ; zone absente → `ZoneInconnue` (exceptions dérivées de `ValueError`) ;
- règle 6 : `code_remise="FIDELE10"` → − 10 % ; code inconnu → `CodeRemiseInconnu` ; résultat arrondi au centime (arrondi commercial).

Cas de contrôle obligatoire : `calculer_tarif(3.5, "UE", express=True, code_remise="FIDELE10") == Decimal("17.96")`.
**Point de départ** : état final du lab 03.1 (`pytest -q` au vert).

### Repères Python
| Syntaxe | Sens |
|---|---|
| `def f(poids, express=False):` | Paramètre optionnel avec valeur par défaut |
| `calculer_tarif(1, "FR", express=True)` | Argument nommé : ordre libre, appel lisible |
| `tarif *= X` | `tarif = tarif * X` |
| `class PoidsInvalide(ValueError):` | Nouvelle exception, héritant de `ValueError` (≈ `extends`) |
| `raise PoidsInvalide("...")` | Lever l'exception (≈ `throw`) |
| `f"Zone inconnue : {zone}"` | Chaîne avec variable insérée (≈ template string) |
| `if x is not None:` | Test « valeur fournie » (`None` ≈ `null`) |
| `if zone not in COEFFICIENTS_ZONE:` | Clé absente du dictionnaire (≈ map) |
| `with pytest.raises(PoidsInvalide):` | Le bloc DOIT lever cette exception, sinon test en échec |

### Étapes
1. **RED (règle 4, express)** — ajouter à la fin de `tests/test_tarification.py` :
   ```python
   def test_option_express_majore_de_40_pourcent():
       assert calculer_tarif(1, "FR", express=True) == Decimal("7.00")
   ```
   ```bash
   pytest -q
   ```
   Résultat attendu :
   ```
   E       TypeError: calculer_tarif() got an unexpected keyword argument 'express'
   ```
   Commit `test(tarif): option express`.
2. **GREEN** — dans `src/fretexpress/tarification.py` : constante sous les autres, nouveau paramètre, majoration après la zone :
   ```python
   MAJORATION_EXPRESS = Decimal("1.40")


   def calculer_tarif(poids_kg, zone, express=False):
       poids = Decimal(str(poids_kg))
       kg_supplementaires = max(0, ceil(poids - 1))
       tarif = PRIX_BASE + PRIX_KG_SUPPLEMENTAIRE * kg_supplementaires
       tarif *= COEFFICIENTS_ZONE[zone]
       if express:
           tarif *= MAJORATION_EXPRESS
       return tarif
   ```
   `pytest -q` → vert. Commit `feat(tarif): option express`.
3. **RED (règle 5, poids)** — remplacer l'import de `fretexpress.tarification` en tête du fichier de test, puis ajouter le test :
   ```python
   from fretexpress.tarification import PoidsInvalide, calculer_tarif
   ```
   ```python
   @pytest.mark.parametrize("poids", [0, -1, 30.01])
   def test_poids_hors_limites_refuse(poids):
       with pytest.raises(PoidsInvalide):
           calculer_tarif(poids, "FR")
   ```
   Résultat attendu (loi 2 : une erreur d'import compte) :
   ```
   E   ImportError: cannot import name 'PoidsInvalide' from 'fretexpress.tarification'
   ```
   Commit `test(tarif): poids hors limites`.
4. **GREEN** — dans `tarification.py`, sous les constantes :
   ```python
   POIDS_MAX_KG = Decimal("30")


   class PoidsInvalide(ValueError):
       """Poids nul, negatif ou superieur a 30 kg."""
   ```
   Étape intermédiaire instructive : `pytest -q` à ce stade → `Failed: DID NOT RAISE PoidsInvalide` (l'exception existe, mais n'est jamais levée). Ajouter le contrôle juste après `poids = Decimal(str(poids_kg))` (clause de garde, en tête de fonction) :
   ```python
       if poids <= 0 or poids > POIDS_MAX_KG:
           raise PoidsInvalide(f"Poids hors limites : {poids} kg (0 < poids <= 30)")
   ```
   `pytest -q` → vert. Commit `feat(tarif): controle du poids`.
5. **RED (règle 5, zone)** — import : `from fretexpress.tarification import PoidsInvalide, ZoneInconnue, calculer_tarif`, puis :
   ```python
   def test_zone_inconnue_refusee():
       with pytest.raises(ZoneInconnue):
           calculer_tarif(1, "LUNE")
   ```
   Résultat attendu :
   ```
   E   ImportError: cannot import name 'ZoneInconnue' from 'fretexpress.tarification'
   ```
   Commit `test(tarif): zone inconnue`.
6. **GREEN** — classe sous `PoidsInvalide`, contrôle sous celui du poids :
   ```python
   class ZoneInconnue(ValueError):
       """Zone absente de la grille tarifaire."""
   ```
   ```python
       if zone not in COEFFICIENTS_ZONE:
           raise ZoneInconnue(f"Zone inconnue : {zone}")
   ```
   (sans ce contrôle : `KeyError: 'LUNE'`, message technique peu parlant)
   `pytest -q` → vert. Commit `feat(tarif): controle de la zone`.
7. **RED (règle 6, remise)** — ajouter :
   ```python
   def test_remise_fidele10_retire_10_pourcent():
       assert calculer_tarif(1, "FR", code_remise="FIDELE10") == Decimal("4.50")
   ```
   Résultat attendu :
   ```
   E       TypeError: calculer_tarif() got an unexpected keyword argument 'code_remise'
   ```
   Commit `test(tarif): remise FIDELE10`.
8. **GREEN** — constante, paramètre `code_remise=None`, remise APRÈS la majoration express :
   ```python
   REMISES = {"FIDELE10": Decimal("0.10")}
   ```
   ```python
   def calculer_tarif(poids_kg, zone, express=False, code_remise=None):
   ```
   ```python
       if express:
           tarif *= MAJORATION_EXPRESS
       if code_remise is not None:
           tarif *= 1 - REMISES[code_remise]
       return tarif
   ```
   `pytest -q` → vert. Commit `feat(tarif): remise FIDELE10`.
9. **RED (règle 6, code inconnu)** — l'import devient trop long : passer à la forme entre parenthèses (une ligne par nom, ordre alphabétique attendu par `ruff`) :
   ```python
   from fretexpress.tarification import (
       CodeRemiseInconnu,
       PoidsInvalide,
       ZoneInconnue,
       calculer_tarif,
   )
   ```
   ```python
   def test_code_remise_inconnu_refuse():
       with pytest.raises(CodeRemiseInconnu):
           calculer_tarif(1, "FR", code_remise="GRATUIT")
   ```
   Résultat attendu :
   ```
   E   ImportError: cannot import name 'CodeRemiseInconnu' from 'fretexpress.tarification'
   ```
   Commit `test(tarif): code de remise inconnu`.
10. **GREEN** — classe sous `ZoneInconnue`, contrôle dans le bloc de la remise :
    ```python
    class CodeRemiseInconnu(ValueError):
        """Code de remise non reconnu."""
    ```
    ```python
        if code_remise is not None:
            if code_remise not in REMISES:
                raise CodeRemiseInconnu(f"Code de remise inconnu : {code_remise}")
            tarif *= 1 - REMISES[code_remise]
    ```
    `pytest -q` → vert. Commit `feat(tarif): code de remise inconnu refuse`.
11. **RED (cas de contrôle, arrondi)** — ajouter :
    ```python
    def test_regles_cumulees_avec_arrondi_au_centime():
        # (5 + 1.5 * 3) * 1.5 * 1.4 * 0.9 = 17.955 -> 17.96 (arrondi commercial)
        assert calculer_tarif(3.5, "UE", express=True, code_remise="FIDELE10") == Decimal("17.96")
    ```
    Résultat attendu (montant exact, non arrondi) :
    ```
    E       AssertionError: assert Decimal('17.9550000') == Decimal('17.96')
    ```
    Commit `test(tarif): regles cumulees et arrondi`.
12. **GREEN** — compléter l'import `decimal` en tête, ajouter la fonction d'arrondi avant `calculer_tarif`, arrondir UNE seule fois, au retour :
    ```python
    from decimal import ROUND_HALF_UP, Decimal
    ```
    ```python
    def _arrondir(montant):
        return montant.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    ```
    ```python
        return _arrondir(tarif)
    ```
    (`quantize` = arrondi à 2 décimales ; `ROUND_HALF_UP` = arrondi commercial : `17.955 → 17.96` ; `round()` arrondirait au pair : `0.125 → 0.12`)
    `pytest -q` → vert. Commit `feat(tarif): arrondi au centime`.
13. **REFACTOR** — annotations de type, docstrings, constantes regroupées ; comportement inchangé. Fichier `src/fretexpress/tarification.py` complet attendu :
    ```python
    """Moteur de tarification FretExpress (developpe en TDD, module 03)."""

    from decimal import ROUND_HALF_UP, Decimal
    from math import ceil

    PRIX_BASE = Decimal("5.00")  # jusqu'a 1 kg inclus
    PRIX_KG_SUPPLEMENTAIRE = Decimal("1.50")  # par kg entame au-dela de 1 kg
    POIDS_MAX_KG = Decimal("30")
    MAJORATION_EXPRESS = Decimal("1.40")
    COEFFICIENTS_ZONE = {
        "FR": Decimal("1.0"),
        "UE": Decimal("1.5"),
        "MONDE": Decimal("2.5"),
    }
    REMISES = {"FIDELE10": Decimal("0.10")}


    class PoidsInvalide(ValueError):
        """Poids nul, negatif ou superieur a 30 kg."""


    class ZoneInconnue(ValueError):
        """Zone absente de la grille tarifaire."""


    class CodeRemiseInconnu(ValueError):
        """Code de remise non reconnu."""


    def _arrondir(montant: Decimal) -> Decimal:
        return montant.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


    def calculer_tarif(
        poids_kg: Decimal | float | int,
        zone: str,
        express: bool = False,
        code_remise: str | None = None,
    ) -> Decimal:
        """Tarif HT d'un colis, hors surcharge carburant."""
        poids = Decimal(str(poids_kg))
        if poids <= 0 or poids > POIDS_MAX_KG:
            raise PoidsInvalide(f"Poids hors limites : {poids} kg (0 < poids <= 30)")
        if zone not in COEFFICIENTS_ZONE:
            raise ZoneInconnue(f"Zone inconnue : {zone}")

        kg_supplementaires = max(0, ceil(poids - 1))
        tarif = PRIX_BASE + PRIX_KG_SUPPLEMENTAIRE * kg_supplementaires
        tarif *= COEFFICIENTS_ZONE[zone]
        if express:
            tarif *= MAJORATION_EXPRESS
        if code_remise is not None:
            if code_remise not in REMISES:
                raise CodeRemiseInconnu(f"Code de remise inconnu : {code_remise}")
            tarif *= 1 - REMISES[code_remise]
        return _arrondir(tarif)
    ```
    ```bash
    pytest -q          # toujours vert
    ruff check .       # All checks passed! (sinon : ruff check --fix .)
    ```
    Commit `refactor(tarif): annotations et docstrings`.

**Critères de réussite** :
- [ ] Cas de contrôle `17.96` vérifié par un test
- [ ] 3 exceptions testées par `pytest.raises`
- [ ] Historique Git en cycles red / green / refactor (`git log --oneline`)

---

## Défi 03.4 ⭐⭐⭐ — Tests de propriétés (autonome)
**Durée** : 20 min · **Objectif** : vérifier des invariants sur des milliers d'entrées générées
**Énoncé** : installer `hypothesis` (dépendance de développement), écrire 2 propriétés :
- le tarif ne diminue jamais quand le poids augmente (zone et options fixées) ;
- le tarif express est toujours supérieur ou égal au tarif standard.
**Critères de réussite** :
- [ ] 2 tests `@given` au vert
- [ ] Dépendance ajoutée et figée dans `pyproject.toml`
- [ ] Explication : différence entre test par exemples et test de propriétés

---

## Bonus 🚀
Introduire volontairement un bug (`>=` au lieu de `>` sur la limite de 30 kg) : combien de tests échouent ? Que révèle un bug qu'aucun test ne détecte ?
