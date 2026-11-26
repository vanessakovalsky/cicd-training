# Module 06 — Corrections, bloc 2

Bloc 2 (séquences S6.3). Autre bloc : `module-06-qualite-artefacts-corrections-1.md`.

Jenkinsfile de référence : `fil-rouge/solutions/m06/Jenkinsfile` ; fichiers associés : `sonar-project.properties`, `Dockerfile`, `.dockerignore`.

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
| `401` à l'upload ou au `docker push` après un rattrapage (`scripts/m0[5-7]/catch-up/catch-up.sh`) | Rattrapage = jeton Gitea `jenkins` supprimé puis régénéré ; ancien jeton recollé dans `gitea-dev` (ou build lancé avant la fin du rattrapage) | Jeton valide = `environnement/secrets/gitea_token` ; `gitea-dev` › **Update** › **Change Password** › coller ce jeton › **Save** ; ou relancer le rattrapage sans toucher au credential |
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
