# Module 08 — Exercices

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

---

## Lab 08.3 ⭐⭐ — Factoriser dans une bibliothèque partagée (semi-guidé)
**Durée** : 40 min · **Objectif** : Jenkinsfile réduit, étapes communes dans `fretexpress-pipeline-lib@v1`
### Étapes
1. Gitea (`dev`) : nouveau dépôt `fretexpress-pipeline-lib` (vide). Publier la bibliothèque fournie et l'étiqueter.
   ```bash
   cp -r <FORMATION>/fil-rouge/fretexpress-pipeline-lib ~/fretexpress-pipeline-lib
   cd ~/fretexpress-pipeline-lib
   git init && git add . && git commit -m "feat: bibliotheque partagee v1"
   git remote add origin http://localhost:3000/dev/fretexpress-pipeline-lib.git
   git push -u origin main
   git tag -a v1 -m "v1" && git push origin v1
   ```
2. Lire `vars/pythonInstall.groovy`, `vars/fretexpressVersion.groovy`, `vars/deployer.groovy`, `vars/notifierEquipe.groovy` : quelle étape du Jenkinsfile chacune remplace-t-elle ?
3. Jenkins › **Manage Jenkins** › **System** › **Global Trusted Pipeline Libraries** › **Add** :
   - Name `fretexpress-lib` · Default version `v1` · **Allow default version to be overridden** coché · **Load implicitly** décoché
   - Retrieval method **Modern SCM** › **Git** : `http://gitea:3000/dev/fretexpress-pipeline-lib.git`, credentials `gitea-dev`
   - **Save**
4. Branche `ci/bibliotheque` du dépôt `fretexpress` : première ligne du Jenkinsfile `@Library('fretexpress-lib@v1') _` ; remplacer :
   - le contenu de `Installation` par `pythonInstall()` puis `fretexpressVersion()` (supprimer l'étape `Version`) ;
   - les blocs de déploiement par `deployer('int', env.VERSION)`, `deployer('recette', env.VERSION)`, `deployer('prod', env.VERSION)` ;
   - les `mail` de `post` par `notifierEquipe('failure')` et `notifierEquipe('fixed')`.
5. Pousser ; console : `Loading library fretexpress-lib@v1`. MR, revue, fusion ; chaîne complète au vert jusqu'à la production.
6. Compter les lignes avant / après : `git show main~1:Jenkinsfile | wc -l` puis `wc -l Jenkinsfile`.

### Critères de réussite
- [ ] Jenkinsfile de `main` chargé avec `fretexpress-lib@v1`, chaîne au vert jusqu'à la production
- [ ] Plus aucun `withCredentials` de déploiement ni calcul de version dans le Jenkinsfile
- [ ] Réduction du nombre de lignes mesurée

---

## Exercice 08.4 ⭐ — Fiabiliser et mesurer le gain (guidé)
**Durée** : 10 min · **Objectif** : `retry` et `timeout` au bon endroit ; bilan chiffré
**Énoncé** : vérifier que `retry(2)` n'entoure QUE des actions idempotentes (`docker push`, déploiement) et jamais `twine upload` ; vérifier un `timeout` global et sur la recette. Remplir le tableau :

| Mesure | Avant (M07) | Après (M08) |
|---|---|---|
| Durée d'un build de branche (cache chaud) | | |
| Lignes du Jenkinsfile | | |
| Étapes en parallèle | 0 | |

**Critères de réussite** : tableau rempli à partir de mesures réelles.

---

## Défi 08.5 ⭐⭐⭐ — Faire évoluer la bibliothèque sans casser les pipelines (autonome)
**Durée** : 20 min · **Objectif** : tester une version `v2` sur une branche avant de la publier
**Énoncé** : dans la bibliothèque, branche `feat/notif-statut` : `notifierEquipe` accepte un paramètre `destinataires` et ajoute la durée du build dans le corps du mail. Tester depuis une branche de `fretexpress` avec `@Library('fretexpress-lib@feat/notif-statut') _` ; puis tag `v2` ; `main` reste en `v1` jusqu'à une MR dédiée.
**Critères de réussite** :
- [ ] Builds de `main` inchangés pendant le test
- [ ] Tag `v2` créé ; migration de `fretexpress` par MR

---

## Bonus 🚀
Remplacer l'agent global par des agents par étape et `stash` / `unstash` (préparation du défi 10.3) : quel coût supplémentaire (clonage, installation) pour quel gain (exécuteur libéré pendant l'approbation) ?
