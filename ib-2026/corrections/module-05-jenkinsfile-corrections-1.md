# Module 05 — Corrections, bloc 1

Bloc 1 (séquences S5.1, S5.2). Autre bloc : `module-05-jenkinsfile-corrections-2.md`.

Jenkinsfile de référence : `fil-rouge/solutions/m05/Jenkinsfile`.

## Lab 05.1 ⭐ — Écrire un pipeline de build et de tests
### Solution
```groovy
pipeline {
    agent { label 'python' }

    options {
        timestamps()
        timeout(time: 20, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
    }

    stages {
        stage('Installation') {
            steps {
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install --quiet -e ".[dev]"
                '''
            }
        }
        stage('Tests') {
            steps {
                sh '. .venv/bin/activate && pytest --junitxml=reports/junit.xml'
            }
        }
        stage('Build') {
            steps {
                sh '. .venv/bin/activate && pip wheel --quiet --no-deps -w dist .'
            }
        }
    }

    post {
        always {
            junit allowEmptyResults: true, testResults: 'reports/junit.xml'
        }
        success {
            archiveArtifacts artifacts: 'dist/*.whl', fingerprint: true
        }
    }
}
```
### Pourquoi
- `junit` dans `post { always }` : rapport publié même si les tests échouent (c'est là qu'il est utile).
- `allowEmptyResults: true` : un échec à l'installation (aucun rapport) ne masque pas l'erreur d'origine.
- `disableConcurrentBuilds()` : deux builds de la même branche ne se marchent pas dessus (workspace, déploiement au module 07).
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| `pytest: not found` | venv non activé dans le `sh` | `. .venv/bin/activate &&` dans chaque `sh` |
| `No test report files were found` | `--junitxml` absent | Ajouter `--junitxml=reports/junit.xml` |
| `ERROR: Could not find a version that satisfies the requirement` | Réseau / proxy de l'agent | Proxy dans l'agent ; cache pip (module 08) |
| `There are no nodes with the label 'python'` | Agent hors ligne | Relancer l'agent (module 02) |
| `Scripts not permitted to use method ...` | Code Groovy hors bac à sable | Rester en déclaratif ; logique dans une bibliothèque de confiance (module 08) |

## Défi 05.4 ⭐⭐⭐ — Pipeline plus robuste
### Solution
```groovy
stage('Installation') {
    options { timeout(time: 5, unit: 'MINUTES') }
    steps {
        script { currentBuild.displayName = "#${env.BUILD_NUMBER} - ${env.GIT_COMMIT.take(7)}" }
        sh 'python3 -m venv .venv && . .venv/bin/activate && pip install --quiet -e ".[dev]"'
    }
}
stage('Tests') {
    steps { sh '. .venv/bin/activate && pytest --junitxml=reports/junit.xml' }
    post {
        failure { echo 'Tests en echec : relancer localement avec pytest --randomly-seed=<graine affichee>' }
    }
}
// post global
post {
    always  { junit allowEmptyResults: true, testResults: 'reports/junit.xml' }
    success { archiveArtifacts artifacts: 'dist/*.whl', fingerprint: true }
    cleanup { script { if (currentBuild.currentResult == 'SUCCESS') { cleanWs() } } }
}
```
### Pourquoi
`cleanup` s'exécute en dernier ; `cleanWs()` (plugin Workspace Cleanup) seulement en succès : en échec, le workspace reste disponible pour le diagnostic.
