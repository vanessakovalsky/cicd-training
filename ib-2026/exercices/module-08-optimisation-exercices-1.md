# Module 08 — Exercices, bloc 1

Bloc 1 : séquences S8.1, S8.2. Bloc 2 : `module-08-optimisation-exercices-2.md`.

Point de départ : état fin M07 (pipeline séquentiel jusqu'à la production). Retard : `scripts/m07/catch-up/catch-up.sh`.
Mesures de durée : sur des builds de BRANCHE (pas de déploiement ni d'attente d'approbation).

## Lab 08.1 ⭐⭐ — Paralléliser les contrôles (semi-guidé)
**Durée** : 40 min · **Objectif** : lint, tests unitaires, tests d'intégration et audit des dépendances en parallèle ; couverture fusionnée
**Contexte** : les développeurs de FretExpress attendent le résultat de leur MR trop longtemps et regroupent leurs commits.

### Étapes
1. Mesure de référence : branche `perf/reference` (aucun changement), pousser, puis relancer une fois ; relever les deux durées.
   ```bash
   <FORMATION>/scripts/m08/labs/mesurer-durees.sh 5
   ```
   (affiche `main` ; pour une branche : **Pipeline Overview** du build, durée totale et par étape)
2. Branche `perf/parallele`. Remplacer les étapes `Analyse statique` et `Tests` par une étape `Controles` avec 4 branches parallèles :
   - `Lint` : `ruff check --output-format=junit --output-file=reports/ruff.xml .`
   - `Tests unitaires` : `COVERAGE_FILE=.coverage.unit pytest -m "not integration" --junitxml=reports/junit-unit.xml --cov=fretexpress --cov-branch --cov-report=`
   - `Tests integration` : idem avec `-m integration`, `.coverage.integration`, `junit-integration.xml`
   - `Audit dependances` : `pip-audit --progress-spinner off --skip-editable`
3. Ajouter une étape `Couverture` après `Controles` :
   ```groovy
   stage('Couverture') {
       steps {
           sh '''
               . .venv/bin/activate
               coverage combine .coverage.unit .coverage.integration
               coverage xml -o reports/coverage.xml
           '''
       }
   }
   ```
4. Adapter les rapports : `junit ... testResults: 'reports/junit-*.xml, reports/ruff.xml'` ; SonarQube : `-Dsonar.python.xunit.reportPath=reports/junit-unit.xml,reports/junit-integration.xml`.
5. Installation : ajouter `pip install --quiet --upgrade pip` avant l'installation du projet (sinon `pip-audit` signale les vulnérabilités du `pip` du venv).
6. Pousser ; **Pipeline Overview** : 4 branches parallèles ; console de l'audit : `No known vulnerabilities found`.
7. Relancer une fois ; comparer avec la référence.

### Critères de réussite
- [ ] 4 branches parallèles visibles, couverture fusionnée identique (≈ 96 %)
- [ ] `pip-audit` au vert
- [ ] Gain (ou absence de gain) mesuré et EXPLIQUÉ à partir des durées par étape

---

## Exercice 08.2 ⭐⭐ — Mettre en cache les dépendances (semi-autonome)
**Durée** : 30 min · **Objectif** : mesurer l'effet du cache pip et l'expliciter dans le pipeline
**Énoncé** :
1. Simuler un agent éphémère : build avec `PIP_NO_CACHE_DIR=1` (bloc `withEnv`) ; relever la durée de l'étape `Installation`.
2. Cache explicite sur le volume persistant : `withEnv(['PIP_CACHE_DIR=/home/jenkins/.cache/pip'])` ; relancer deux fois ; relever.
3. Vérifier le contenu du cache : `docker exec cicd-agent-1 du -sh /home/jenkins/.cache/pip`.
4. Lire le `Dockerfile` : l'ordre des instructions favorise-t-il le cache des couches ? Que se passe-t-il si `COPY dist/*.whl` passe en premier ?
**Indices** : volume `agent-cache` dans `environnement/compose.yaml` ; le cache survit à la recréation du conteneur agent (`docker compose up -d --force-recreate agent`).
**Critères de réussite** :
- [ ] Durées d'installation sans cache / avec cache relevées (banc : 36 s / 26 s)
- [ ] Explication : pourquoi le gain est modeste ici et fort derrière un proxy lent
