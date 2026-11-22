# Module 06 — Corrections

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

## Lab 06.3 ⭐⭐ — Versionner, publier l'artefact, notifier
### Solution
Jenkinsfile complet : `fil-rouge/solutions/m06/Jenkinsfile`. Étape `Version` :
```groovy
stage('Version') {
    steps {
        script {
            def base = sh(returnStdout: true, script: '''python3 -c "import tomllib; \
print(tomllib.load(open('pyproject.toml', 'rb'))['project']['version'])"''').trim()
            def parties = base.tokenize('.')
            env.VERSION = "${parties[0]}.${parties[1]}.${env.BUILD_NUMBER}"
            currentBuild.displayName = "#${env.BUILD_NUMBER} - ${env.VERSION}"
        }
        sh 'sed -i "s/^version = .*/version = \\"${VERSION}\\"/" pyproject.toml'
    }
}
```
Sorties relevées sur le banc (build `main` n° 7) :
```
Uploading distributions to http://gitea:3000/api/packages/dev/pypi
Uploading fretexpress-1.0.7-py3-none-any.whl
```
Mails reçus dans Mailpit : `ECHEC fretexpress/main #6`, puis `REPARE fretexpress/main #7`.
### Pourquoi
- Version dans `pyproject.toml` modifiée DANS le workspace seulement : le dépôt garde `1.0.0` (majeur.mineur), le build fixe le correctif.
- Image taguée `localhost:3000/...` : le démon Docker de l'hôte joint le registre par le port publié ; `localhost` est considéré comme registre non chiffré autorisé.
- Publication réservée à `main` : une MR ne doit jamais produire d'artefact « officiel ».
- `docker logout` en fin d'étape : aucun identifiant ne reste dans la configuration Docker de l'agent.
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| `ERROR: Cannot install fretexpress 1.0.0 ... and fretexpress 1.0.6` au `docker build` | Ancienne wheel dans `dist/` | `rm -rf dist reports` en début de build |
| `HTTPError: 409 Conflict` à l'upload | Version déjà publiée (build rejoué) | Nouveau build (nouveau numéro) ; ne jamais republier une version |
| `unauthorized` au `docker push` | Jeton sans droit `package` | Jeton Gitea avec **package : écriture** |
| `http: server gave HTTP response to HTTPS client` | Registre appelé par un nom autre que `localhost` | Utiliser `localhost:3000` (ou `insecure-registries` du démon) |
| Aucun mail | Notification sur `success` seulement, ou SMTP | `failure` / `fixed` ; SMTP `mailpit:1025` (JCasC) |

## Défi 06.4 ⭐⭐⭐ — Version de release par tag Git
### Solution
- Job multibranche › **Branch Sources** › **Add** › **Discover tags**. Les tags ne sont pas construits automatiquement : **Build Now** sur le job `v1.1.0` (ou stratégie de build des tags).
- Étape `Version` :
  ```groovy
  script {
      if (env.TAG_NAME) {
          env.VERSION = env.TAG_NAME.replaceFirst(/^v/, '')
      } else {
          def parties = sh(returnStdout: true, script: '...').trim().tokenize('.')
          env.VERSION = "${parties[0]}.${parties[1]}.${env.BUILD_NUMBER}"
      }
  }
  ```
- Publication : `when { anyOf { branch 'main'; buildingTag() } }`.
### Pourquoi
Version de release choisie par un humain (tag signé possible), versions de build pour le flux continu ; les deux restent uniques.

## Bonus
Sortie attendue : `1.0.<N>`. Le paquet installé depuis le registre est le même fichier que celui testé par le pipeline (empreinte visible dans **Fingerprints** de Jenkins).

## QCM — Réponses
1. **B** — Verdict `ERROR` + `abortPipeline: true` → build en échec.
2. **B** — Le verdict arrive par le webhook SonarQube → `/sonarqube-webhook/`.
3. **B** — Le rapport est surtout utile quand des tests échouent.
4. **B** — Un artefact unique, promu sans reconstruction.
5. **B** — Majeur et mineur du fichier, correctif = numéro de build.
6. **B** — Échec et retour au vert ; les succès répétés ne sont pas une information.
