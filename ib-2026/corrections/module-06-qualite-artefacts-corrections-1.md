# Module 06 — Corrections, bloc 1

Bloc 1 (séquences S6.1, S6.2). Autre bloc : `module-06-qualite-artefacts-corrections-2.md`.

Jenkinsfile de référence : `fil-rouge/solutions/m06/Jenkinsfile` ; fichiers associés : `sonar-project.properties`, `Dockerfile`, `.dockerignore`.

## Lab 06.1 ⭐ — Analyse statique et quality gate bloquant
### Solution
Étapes ajoutées (extrait du Jenkinsfile de référence) :
```groovy
stage('Analyse statique') {
    steps {
        sh '. .venv/bin/activate && ruff check --output-format=junit --output-file=reports/ruff.xml .'
    }
}
stage('Tests') {
    steps {
        sh '''
            . .venv/bin/activate
            pytest --junitxml=reports/junit.xml \
                   --cov=fretexpress --cov-branch --cov-report=xml:reports/coverage.xml
        '''
    }
}
stage('SonarQube') {
    when { environment name: 'SONARQUBE_ACTIF', value: 'oui' }
    steps {
        withSonarQubeEnv('sonarqube') {
            sh 'sonar-scanner -Dsonar.projectVersion=$VERSION'
        }
    }
}
stage('Quality gate') {
    when { environment name: 'SONARQUBE_ACTIF', value: 'oui' }
    steps {
        timeout(time: 5, unit: 'MINUTES') {
            waitForQualityGate abortPipeline: true
        }
    }
}
```
Sortie relevée sur le banc avec `export.py` non testé :
```
SonarQube task 'ca51a3b4-e216-4fac-b94f-6546495d25cc' completed. Quality gate is 'ERROR'
ERROR: Pipeline aborted due to quality gate failure: ERROR
Finished: FAILURE
```
(couverture SonarQube mesurée : 75,8 % < 80 %)
Équivalent automatisé de la configuration SonarQube (jeton, webhook, quality gate) : `scripts/m06/catch-up/catch-up.sh`.
### Pourquoi
- `SONARQUBE_ACTIF` : variable globale posée par JCasC selon le profil (`casc/profil.yaml`) ; le même Jenkinsfile fonctionne en profil `complet` et `leger`.
- `rm -rf dist reports` en tête : aucun reste d'un build précédent (une ancienne wheel dans `dist/` casse l'image au lab 06.3).
- `sonar-scanner` installé dans l'image de l'agent (version 7.1) : aucune dépendance au téléchargement pendant le build.
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| `waitForQualityGate` jusqu'au timeout | Webhook SonarQube absent ou URL `localhost:8080` | Webhook `http://jenkins:8080/sonarqube-webhook/` |
| `No SonarQube installation named sonarqube` | Nom du serveur différent | Name `sonarqube` dans **System** |
| `Not authorized. Analyzing this project requires authentication` | Jeton absent ou mauvais type | Jeton **Global Analysis Token**, credential `sonar-token` |
| Couverture à 0 % dans SonarQube | `coverage.xml` absent ou chemin erroné | `--cov-report=xml:reports/coverage.xml` + `sonar.python.coverage.reportPaths` |
| Étapes Sonar ignorées (`skipped due to when conditional`) | Profil `leger` (`SONARQUBE_ACTIF=non`) | Normal ; quality gate par `recordCoverage` |
| `InvalidPathException: Malformed input or input contains unmappable characters: junit.xml??` dans l'étape `SonarQube` (après un `sonar-scanner` réussi) | Espace insécable (U+00A0, frappe AZERTY via Guacamole ou copier-coller) après `junit.xml` dans le Jenkinsfile → fichier `junit.xml` + caractère invisible dans le workspace → plugin SonarQube en échec au parcours du workspace (agent en locale ASCII) ; erreur persistante après correction du Jenkinsfile (fichier toujours présent) | Détection : `grep -nP '[^\x00-\x7F]' Jenkinsfile \| cat -A` (insécable = `M-BM-`) ; remplacer par une espace normale ; purge : `rm -rf dist reports` en tête de pipeline ou, depuis `environnement/`, `docker compose exec agent sh -c 'rm -rf /home/jenkins/agent/workspace/*<branche>/reports'` |
| Version vide dans SonarQube (`sonar.projectVersion` sans valeur) | `$VERSION` utilisé avant le lab 06.3 (variable non définie) | `-Dsonar.projectVersion=$BUILD_NUMBER` en attendant le lab 06.3 |
| Aucun build planifié sur `main` (pas d'erreur affichée) | Faute de frappe `env.BRANCH__NAME` (deux tirets bas) → `null` → expression `cron` vide | `env.BRANCH_NAME` |
| Mesures de `main` écrasées par une MR | Édition Community : une seule branche par projet | Limite connue ; analyse des branches = éditions commerciales `[À VÉRIFIER]` |

## Exercice 06.2 ⭐⭐ — Rapports de tests et de couverture
### Solution
```groovy
post {
    always {
        junit allowEmptyResults: true, testResults: 'reports/junit.xml, reports/ruff.xml'
        recordCoverage(tools: [[parser: 'COBERTURA', pattern: 'reports/coverage.xml']],
                       sourceDirectories: [[path: 'src']],
                       qualityGates: [[metric: 'BRANCH', threshold: 80.0,
                                       baseline: 'PROJECT', criticality: 'UNSTABLE']])
    }
}
```
Console attendue :
```
[Coverage] Recording coverage results
[Coverage] Creating parser for Cobertura Coverage Reports
```
### Pourquoi
- `criticality: 'UNSTABLE'` : signal visible (jaune) sans bloquer ; `FAILURE` possible pour un blocage strict.
- `sourceDirectories` : affichage du code source coloré dans le rapport.
- Avec `export.py` : couverture de branches du projet 50 % (14 / 28 branches) → `UNSTABLE` en profil `leger` ; en profil `complet`, le quality gate SonarQube échoue avant (build `FAILURE`).
### Variantes acceptables
`pytest --cov-fail-under=80` dans l'étape `Tests` : blocage immédiat, sans rapport graphique ni tendance.
