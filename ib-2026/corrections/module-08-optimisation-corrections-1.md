# Module 08 — Corrections, bloc 1

Bloc 1 (séquences S8.1, S8.2). Autre bloc : `module-08-optimisation-corrections-2.md`.

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
