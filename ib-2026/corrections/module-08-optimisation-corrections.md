# Module 08 — Corrections

Fichiers de référence : `fil-rouge/solutions/m08/Jenkinsfile`, bibliothèque `fil-rouge/fretexpress-pipeline-lib/` (tag `v1`).

## Lab 08.1 ⭐⭐ — Paralléliser les contrôles
### Solution
```groovy
stage('Controles') {
    parallel {
        stage('Lint') {
            steps { sh '. .venv/bin/activate && ruff check --output-format=junit --output-file=reports/ruff.xml .' }
        }
        stage('Tests unitaires') {
            steps {
                sh '''
                    . .venv/bin/activate
                    COVERAGE_FILE=.coverage.unit pytest -m "not integration" \
                        --junitxml=reports/junit-unit.xml --cov=fretexpress --cov-branch --cov-report=
                '''
            }
        }
        stage('Tests integration') {
            steps {
                sh '''
                    . .venv/bin/activate
                    COVERAGE_FILE=.coverage.integration pytest -m integration \
                        --junitxml=reports/junit-integration.xml --cov=fretexpress --cov-branch --cov-report=
                '''
            }
        }
        stage('Audit dependances') {
            steps { sh '. .venv/bin/activate && pip-audit --progress-spinner off --skip-editable' }
        }
    }
}
```
Sorties relevées sur le banc : `28 passed, 8 deselected` (unitaires), `8 passed, 28 deselected` (intégration), `No known vulnerabilities found`, `Combined 2 files`.

Mesure du banc (builds de branche, deux builds lancés en même temps sur l'agent de 2 exécuteurs) :

| Build | Pipeline M07 (séquentiel) | Pipeline M08 (parallèle + audit + bibliothèque) |
|---|---|---|
| 1er passage | 59 s | 68 s |
| 2e passage (cache chaud) | 67 s | 70 s |

### Pourquoi
- Aucun gain sur le banc, et c'est la leçon : les tests durent ≈ 2 s ; l'installation (≈ 30 s), le build d'image et SonarQube dominent. Paralléliser des étapes courtes ajoute du coût (démarrage des shells, `pip install --upgrade pip`, audit en plus).
- M08 fait PLUS de contrôles (audit des dépendances) pour une durée comparable : le parallèle absorbe l'ajout.
- Deux builds simultanés sur le même agent se partagent le CPU : mesurer chaque variante seule, plusieurs fois.
- Projet réel avec des tests de plusieurs minutes : le parallèle divise la durée des contrôles par le nombre de branches (dans la limite des exécuteurs et du CPU).
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| Couverture à ≈ 80 % au lieu de 96 % | Un seul `.coverage.*` combiné | Combiner les deux fichiers |
| `pip-audit` signale `pip` | `pip` du venv ancien | `pip install --upgrade pip` dans l'installation |
| `pip-audit` signale `fretexpress` | Paquet local non publié sur PyPI | `--skip-editable` |
| `coverage combine` : `No data to combine` | Branches parallèles en échec ou `COVERAGE_FILE` absent | Vérifier chaque branche |

## Exercice 08.2 ⭐⭐ — Mettre en cache les dépendances
### Solution
```groovy
stage('Installation') {
    steps {
        withEnv(['PIP_CACHE_DIR=/home/jenkins/.cache/pip']) {
            sh '''
                rm -rf dist reports && mkdir -p reports
                python3 -m venv .venv && . .venv/bin/activate
                pip install --quiet --upgrade pip
                pip install --quiet -e ".[dev]"
            '''
        }
    }
}
```
Mesure du banc (installation seule, dans l'agent) : 36 s sans cache (`PIP_NO_CACHE_DIR=1`), 26 s avec cache ; taille du cache : 37 Mo.
### Pourquoi
- Le cache évite le téléchargement, pas l'installation ni la compilation : gain modeste sur un bon réseau, important derrière un proxy ou une connexion lente.
- Volume `agent-cache` : le cache survit à la recréation du conteneur de l'agent ; un agent éphémère sans volume repart de zéro.
- `Dockerfile` : `FROM`, `useradd` (stables) avant `COPY dist/*.whl` (change à chaque build). Copier la wheel en premier invaliderait toutes les couches suivantes à chaque build.
### Variantes acceptables
Venv mis en cache par empreinte de `pyproject.toml` (`/home/jenkins/.cache/venvs/<sha256>`) : gain plus fort (installation évitée), plus complexe (installation éditable liée au workspace).

## Lab 08.3 ⭐⭐ — Factoriser dans une bibliothèque partagée
### Solution
Équivalent JCasC (rattrapage `scripts/m08/catch-up/bibliotheque.yaml`) :
```yaml
unclassified:
  globalLibraries:
    libraries:
      - name: fretexpress-lib
        defaultVersion: v1
        implicit: false
        allowVersionOverride: true
        retriever:
          modernSCM:
            scm:
              git:
                remote: http://gitea:3000/dev/fretexpress-pipeline-lib.git
                credentialsId: gitea-dev
```
Jenkinsfile : `fil-rouge/solutions/m08/Jenkinsfile` (`@Library('fretexpress-lib@v1') _`, `pythonInstall()`, `fretexpressVersion()`, `deployer(...)`, `notifierEquipe(...)`). Console : `Loading library fretexpress-lib@v1`. Build `main` relevé sur le banc : `SUCCESS`, description `deploy-prod 1.0.10`.
Correspondance : `pythonInstall` → étape `Installation` ; `fretexpressVersion` → étape `Version` ; `deployer` → 3 étapes de déploiement (avec `withCredentials` et `retry`) ; `notifierEquipe` → `mail` de `post`.
### Pourquoi
- Bibliothèque « trusted » : code hors bac à sable (accès à `currentBuild`, `env`) ; d'où le dépôt protégé et la revue.
- `retry(2)` dans `deployer` : déploiement idempotent (même version, même couleur cible).
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| `No such library resource` / `Library fretexpress-lib not found` | Nom ou déclaration absente | **Global Trusted Pipeline Libraries**, nom exact |
| `couldn't find remote ref v1` | Tag non poussé | `git push origin v1` |
| `No signature of method: ... pythonInstall()` | `_` oublié après `@Library(...)` | `@Library('fretexpress-lib@v1') _` |
| Changement de bibliothèque sans effet | Tag `v1` figé | Nouveau tag, ou `@Library('fretexpress-lib@main')` pour tester |

## Exercice 08.4 ⭐ — Fiabiliser et mesurer le gain
### Solution
- `retry(2)` : autour de `docker push` (étape `Publication`) et dans `deployer` ; jamais autour de `twine upload` (`409 Conflict` au second essai, version déjà publiée — constaté sur le banc avec `--skip-existing` non supporté par Gitea).
- `timeout` : global (30 min), recette (30 min), quality gate (5 min).
- Tableau (banc) : durée 59-67 s → 68-70 s (contrôles en plus, audit compris) ; Jenkinsfile 162 → 145 lignes (déploiements, version et notifications appelés en une ligne) ; 0 → 4 branches parallèles.

## Défi 08.5 ⭐⭐⭐ — Faire évoluer la bibliothèque
### Solution
```groovy
// vars/notifierEquipe.groovy (branche feat/notif-statut)
def call(String etat, String destinataires = 'equipe@fretexpress.localhost') {
    def sujet = (etat == 'fixed') ? 'REPARE' : 'ECHEC'
    mail to: destinataires,
         subject: "${sujet} ${env.JOB_NAME} #${env.BUILD_NUMBER}",
         body: "${sujet} en ${currentBuild.durationString} : ${env.BUILD_URL}console"
}
```
Test : `@Library('fretexpress-lib@feat/notif-statut') _` sur une branche de `fretexpress` (autorisé par **Allow default version to be overridden**) ; puis `git tag -a v2` ; migration par MR.

## Bonus
Coût : chaque étape sur un nouvel agent reclone le dépôt et réinstalle les dépendances (≈ 30 s) ; gain : exécuteur libéré pendant l'attente d'approbation (jusqu'à 30 min). Rentable dès qu'une attente humaine existe (défi 10.3).

## QCM — Réponses
1. **B** — La durée de l'étape parallèle est celle de la branche la plus longue.
2. **B** — Un fichier de mesure par processus, fusionnés ensuite.
3. **B** — `branch 'main'`.
4. **B** — `vars/deployer.groovy` avec `call()`.
5. **B** — Version figée : reproductibilité et maîtrise des évolutions.
6. **B** — Push d'une version : idempotent, erreurs réseau passagères.
7. **B** — Le cache de `~/.cache` disparaît avec le conteneur.
