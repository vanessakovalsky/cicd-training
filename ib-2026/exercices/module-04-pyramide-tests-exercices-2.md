# Module 04 — Exercices, bloc 2

Bloc 2 : séquences S4.3, S4.4. Point de départ : labs du bloc 1 terminés (`module-04-pyramide-tests-exercices-1.md`).

## Exercice 04.2 ⭐⭐ — Mesurer la couverture et combler les manques (semi-autonome)
**Durée** : 35 min · **Objectif** : couverture de branches ≥ 90 %, manques restants justifiés
**Énoncé** :
1. Mesurer AVANT le lab 04.1 (`git stash` ou branche précédente) puis APRÈS ; noter les deux valeurs.
2. Lire la colonne `Missing` ; produire le rapport HTML et l'ouvrir.
3. Ajouter les tests manquants pertinents ; justifier par écrit (dans la MR) les lignes laissées non couvertes.
4. Imposer le seuil : `pytest --cov=fretexpress --cov-branch --cov-fail-under=90`.
**Indices** : `--cov-report=term-missing`, `--cov-report=html` (dossier `htmlcov/`, à ajouter au `.gitignore`).
**Critères de réussite** :
- [ ] Couverture de branches ≥ 90 % (référence : 96 %)
- [ ] Manques restants listés et justifiés (ex. `get_depot()` réel : configuration, testé en bout en bout)
- [ ] `htmlcov/` absent du dépôt

---

## Lab 04.3 ⭐⭐ — Diagnostiquer et stabiliser un test instable (semi-guidé)
**Durée** : 35 min · **Objectif** : test de numérotation déterministe quel que soit l'ordre d'exécution
**Contexte** : « le build est rouge un jour sur deux, il suffit de relancer » — signalement de l'équipe.

### Étapes
1. Constater l'instabilité.
   ```bash
   for i in $(seq 1 6); do pytest -q | tail -1; done
   ```
   Résultat attendu : alternance de `36 passed` et `1 failed, 35 passed` (ou `2 failed`).
2. Reproduire : relever la graine d'un lancement en échec (ligne `Using --randomly-seed=...` en tête de sortie) puis la rejouer.
   ```bash
   pytest -q --randomly-seed=<GRAINE>
   pytest -q -p no:randomly tests/test_numerotation.py
   ```
   Résultat attendu : échec systématique avec la graine ; succès dans l'ordre du fichier.
3. Isoler la cause : lire `tests/test_numerotation.py` et `prochain_numero()` dans `devis.py`. Question : quel état survit d'un test à l'autre ?
4. Corriger à la source (sans relance automatique, sans `sleep`, sans désactiver l'ordre aléatoire).
5. Vérifier sur 10 lancements consécutifs.
   ```bash
   for i in $(seq 1 10); do pytest -q | tail -1; done | sort | uniq -c
   ```
   Résultat attendu : `10 36 passed in ...` (une seule ligne de résultat, répétée).
6. Commit `test(devis): numerotation isolee par test`, push, MR, revue, fusion.

### Critères de réussite
- [ ] 10 lancements consécutifs au vert, ordre aléatoire actif
- [ ] Cause expliquée en une phrase dans la description de la MR
- [ ] Aucun `pytest-rerunfailures`, `skip` ni `sleep` ajouté

---

## Défi 04.4 ⭐⭐⭐ — Validité d'un devis sans dépendance au temps (autonome)
**Durée** : 20 min · **Objectif** : tester une règle temporelle de façon déterministe
**Énoncé** : en TDD, ajouter `Devis.est_expire(maintenant: datetime) -> bool` : un devis est valable 7 jours (168 h) après `cree_le`. Les tests ne doivent jamais appeler `datetime.now()` ni dépendre de l'heure d'exécution.
**Critères de réussite** :
- [ ] Cas limites testés : 7 jours moins 1 seconde (valide), 7 jours exactement (expiré)
- [ ] Aucun appel à `datetime.now()` dans les tests
- [ ] Explication : pourquoi un test « créé maintenant, expiré dans 7 jours » est instable

---

## Bonus 🚀
Lancer uniquement les tests unitaires (`pytest -m "not integration"`), puis uniquement l'intégration, en mesurant la couverture de chacun (`COVERAGE_FILE=.coverage.unit` et `.coverage.integration`), puis fusionner : `coverage combine .coverage.unit .coverage.integration && coverage report`. Préparation du module 08 (tests en parallèle).
