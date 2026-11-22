# Module 05 — Corrections

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

## Lab 05.2 ⭐ — Multibranche, webhook et statut de MR
### Solution
Équivalent automatisé : `scripts/m05/catch-up/catch-up.sh` (jeton, credential, serveur Gitea en JCasC, job multibranche par script Groovy, webhook par l'API Gitea). Extrait JCasC :
```yaml
unclassified:
  giteaServers:
    servers:
      - displayName: gitea
        serverUrl: http://gitea:3000
        aliasUrl: http://localhost:3000
        manageHooks: false
```
Statuts publiés (relevés sur le banc) : `fretexpress/pipeline/head` (branches), `fretexpress/pipeline/pr-main` (MR vers `main`).
### Pourquoi
- `manageHooks: false` : Jenkins créerait un webhook vers son URL publique `http://localhost:8080`, injoignable depuis le conteneur Gitea ; webhook créé à la main vers `http://jenkins:8080`.
- Comportement « Discover branches » par défaut : une branche ayant une MR n'est construite qu'une fois (job `PR-<N>`), pas deux.
- Motif `fretexpress/pipeline/pr-*` : couvre toute MR, quelle que soit la branche cible.
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| Webhook `200` mais aucun build | Alias URL absente | Étape 3 |
| Webhook en erreur `dial tcp ... connection refused` | URL `localhost:8080` dans le webhook | `http://jenkins:8080/gitea-webhook/post` |
| Webhook refusé `webhook can only call allowed HTTP servers` | Liste d'hôtes autorisés de Gitea | Déjà ouvert sur le banc (`GITEA__webhook__ALLOWED_HOST_LIST`) |
| Statut absent sur la MR, console `HTTP 401/Unauthorized` | Jeton sans droit d'écriture sur le dépôt | Nouveau jeton (repository : écriture) |
| Scan : `Does not meet criteria` pour `main` | Pas encore de Jenkinsfile sur `main` | Normal avant la fusion de la MR |

## Exercice 05.3 ⭐⭐ — Déclencheurs complémentaires
### Solution
```groovy
pipeline {
    agent { label 'python' }
    triggers {
        cron(env.BRANCH_NAME == 'main' ? 'H 2 * * *' : '')
    }
    // options, stages, post inchangés
}
```
### Pourquoi
- Les déclencheurs d'un job multibranche sont lus dans le Jenkinsfile de la branche, après un premier build.
- `pollSCM` en plus du webhook : requêtes inutiles toutes les N minutes ; la scrutation périodique du multibranche (1 h) suffit comme filet.
### Variantes acceptables
`triggers { cron('H 2 * * *') }` dans un Jenkinsfile spécifique à `main` : refusé (divergence de Jenkinsfile entre branches).

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

## Bonus
Webhook : build lancé en 1 à 3 s. Scrutation `H/5` : jusqu'à 5 min d'attente, et une requête Git toutes les 5 min même sans changement.

## QCM — Réponses
1. **B** — `pipeline { }` ; `node { }` est la racine du pipeline scripté.
2. **C** — `fixed` : build réussi après un build en échec ou instable.
3. **B** — Chaque étape `sh` démarre un shell neuf.
4. **C** — Le webhook pousse l'événement immédiatement, sans requête répétée.
5. **B** — Un job `PR-<N>` par merge request découverte.
6. **B** — URL annoncée ≠ URL du serveur : déclarer l'Alias URL.
