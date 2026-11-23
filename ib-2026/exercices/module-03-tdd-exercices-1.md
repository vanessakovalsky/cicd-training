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

## Exercice 03.2 ⭐⭐ — Kata TDD : règles 4 à 6 (semi-autonome)
**Durée** : 40 min · **Objectif** : terminer le moteur de tarification en TDD strict
**Énoncé** : développer, un test à la fois :
- règle 4 : option `express=True` → + 40 % ;
- règle 5 : poids ≤ 0 ou > 30 kg → `PoidsInvalide` ; zone absente → `ZoneInconnue` (exceptions dérivées de `ValueError`) ;
- règle 6 : `code_remise="FIDELE10"` → − 10 % ; code inconnu → `CodeRemiseInconnu` ; résultat arrondi au centime (`ROUND_HALF_UP`).
Cas de contrôle obligatoire : `calculer_tarif(3.5, "UE", express=True, code_remise="FIDELE10") == Decimal("17.96")`.
**Indices** : `pytest.raises` ; `Decimal.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)` ; la remise s'applique après la majoration express.
**Critères de réussite** :
- [ ] Cas de contrôle `17.96` vérifié par un test
- [ ] 3 exceptions testées par `pytest.raises`
- [ ] Historique Git en cycles red / green / refactor

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
