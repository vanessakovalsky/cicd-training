# Module 06 — Exercices

Point de départ : état fin M05 (Jenkinsfile multibranche, webhook). Retard : `scripts/m05/catch-up/catch-up.sh`.
Toutes les modifications passent par une branche et une MR (`main` protégée, pipeline au vert exigé).

## Lab 06.1 ⭐ — Analyse statique et quality gate bloquant (guidé)
**Durée** : 55 min · **Objectif** : `ruff` et SonarQube dans le pipeline ; build en échec si le quality gate échoue
**Contexte** : la revue de code de FretExpress passe son temps sur le style ; aucune mesure de qualité n'est suivie.
**Prérequis** : profil `complet` (profil `leger` : étapes 1 à 3 et 9 seulement, puis exercice 06.2)

### Étapes
1. Branche `ci/qualite`. Ajouter l'étape d'analyse statique après `Installation` :
   ```groovy
   stage('Analyse statique') {
       steps {
           sh '. .venv/bin/activate && ruff check --output-format=junit --output-file=reports/ruff.xml .'
       }
   }
   ```
   et remplacer, dans `Installation`, la création du venv par une ligne qui nettoie aussi les restes du build précédent :
   `rm -rf dist reports && mkdir -p reports` (en tête du `sh`).
2. Vérifier en local que `ruff check .` affiche `All checks passed!`.
3. Publier aussi le rapport ruff : dans `post { always }`, `testResults: 'reports/junit.xml, reports/ruff.xml'`.
4. SonarQube (http://localhost:9000, `admin`) : avatar › **My Account** › **Security** › **Generate Tokens** : nom `jenkins`, type **Global Analysis Token** › **Generate** › copier.
5. Jenkins : credential **Secret text**, ID `sonar-token`, secret = jeton. Puis **Manage Jenkins** › **System** › **SonarQube servers** : cocher **Environment variables**, **Add SonarQube** : Name `sonarqube`, Server URL `http://sonarqube:9000`, Server authentication token `sonar-token` › **Save**.
6. SonarQube › **Administration** › **Configuration** › **Webhooks** › **Create** : nom `jenkins`, URL `http://jenkins:8080/sonarqube-webhook/`.
7. SonarQube › **Quality Gates** › **Create** `FretExpress` : conditions sur le code global (**Overall Code**) : **Coverage** inférieure à `80` ; **Bugs** supérieur à `0` › **Set as Default**.
8. Ajouter `sonar-project.properties` (contenu de la slide « Configurer l'analyse »), les étapes `SonarQube` et `Quality gate` (slide « Le quality gate en code »), et la couverture dans l'étape `Tests` :
   ```groovy
   sh '''
       . .venv/bin/activate
       pytest --junitxml=reports/junit.xml \
              --cov=fretexpress --cov-branch --cov-report=xml:reports/coverage.xml
   '''
   ```
   L'étape `SonarQube` utilise `$VERSION` : en attendant le lab 06.3, remplacer par `-Dsonar.projectVersion=$BUILD_NUMBER`.
9. Commit, push, MR. Résultat attendu (console du build `PR-<N>`) :
   ```
   INFO  ANALYSIS SUCCESSFUL, you can find the results at: http://sonarqube:9000/dashboard?id=fretexpress
   SonarQube task '<ID>' completed. Quality gate is 'OK'
   ```
10. Preuve du blocage : sur la même branche, ajouter `src/fretexpress/export.py` (code non testé) :
    ```python
    """Export CSV des devis (non teste : demonstration du quality gate)."""

    import csv
    import io


    def exporter_csv(devis_liste):
        tampon = io.StringIO()
        ecrivain = csv.writer(tampon, delimiter=";")
        ecrivain.writerow(["numero", "zone", "poids_kg", "montant"])
        for devis in devis_liste:
            if devis.montant <= 0:
                continue
            ecrivain.writerow([devis.numero, devis.zone, devis.poids_kg, devis.montant])
        return tampon.getvalue()


    def resume(devis_liste):
        total = sum(d.montant for d in devis_liste)
        par_zone = {}
        for devis in devis_liste:
            par_zone[devis.zone] = par_zone.get(devis.zone, 0) + devis.montant
        moyenne = total / len(devis_liste) if devis_liste else 0
        return {"total": total, "moyenne": moyenne, "par_zone": par_zone}


    def plus_gros_devis(devis_liste, nombre=3, zone=None):
        candidats = []
        for devis in devis_liste:
            if zone is not None and devis.zone != zone:
                continue
            if devis.montant <= 0:
                continue
            candidats.append(devis)
        candidats.sort(key=lambda d: d.montant, reverse=True)
        if nombre <= 0:
            return []
        return candidats[:nombre]
    ```
    Push. Résultat attendu : `Quality gate is 'ERROR'`, build `FAILURE`, MR bloquée. Supprimer le fichier (ou le tester), push → vert.
11. Approbation, fusion.

### Critères de réussite
- [ ] Projet `fretexpress` visible dans SonarQube avec la couverture (≈ 96 %)
- [ ] Un build `FAILURE` causé par le quality gate, puis le retour au vert
- [ ] Étapes `Analyse statique`, `SonarQube`, `Quality gate` dans le Jenkinsfile de `main`

---

## Exercice 06.2 ⭐⭐ — Rapports de tests et de couverture (semi-autonome)
**Durée** : 25 min · **Objectif** : couverture visible dans Jenkins, seuil appliqué même sans SonarQube
**Énoncé** : publier `reports/coverage.xml` avec l'étape `recordCoverage` (plugin Coverage) : seuil de 80 % sur la couverture de branches du projet, build `UNSTABLE` en dessous. Vérifier : page **Coverage Report** d'un build, tendance après 2 builds ; build instable avec le fichier `export.py` du lab 06.1 (profil `leger` : ce seuil EST le quality gate).
**Indices** : générateur **Pipeline Syntax** › `recordCoverage` ; parser `COBERTURA` ; `sourceDirectories`.
**Critères de réussite** :
- [ ] Page **Coverage Report** : couverture par fichier, code source coloré
- [ ] Un build `UNSTABLE` sous le seuil (profil `leger`), ou explication du verdict obtenu (profil `complet`)

---

## Lab 06.3 ⭐⭐ — Versionner, publier l'artefact, notifier (semi-guidé)
**Durée** : 45 min · **Objectif** : paquet et image `1.0.<build>` publiés dans le registre Gitea depuis `main` ; mail sur échec et retour au vert
**Contexte** : le paquet est aujourd'hui copié à la main sur le serveur ; personne ne sait quelle version tourne.

### Étapes
1. Branche `ci/artefacts`. Ajouter `Dockerfile` et `.dockerignore` (fichiers de `fil-rouge/solutions/m06/`) ; lire le `Dockerfile` : image `python:3.12-slim`, utilisateur non root, `HEALTHCHECK` sur `/health`.
2. Ajouter dans le Jenkinsfile le bloc `environment` (`REGISTRE = 'localhost:3000'`, `IMAGE`, `PYPI_URL = 'http://gitea:3000/api/packages/dev/pypi'`) et l'étape `Version` (slide « Versionner ») après `Installation` ; remettre `$VERSION` dans l'étape `SonarQube`.
3. Étape `Build` : wheel puis image.
   ```groovy
   sh '''
       . .venv/bin/activate
       pip wheel --quiet --no-deps -w dist .
       docker build --quiet -t "$IMAGE:$VERSION" \
           --label org.opencontainers.image.version="$VERSION" \
           --label org.opencontainers.image.revision="$GIT_COMMIT" .
   '''
   ```
4. Étape `Publication` limitée à `main` (slide « Publier depuis le pipeline »).
5. Notifications : `post { failure { mail ... } fixed { mail ... } }` vers `equipe@fretexpress.localhost`.
6. MR, revue, fusion. Build `main` : résultat attendu (console) :
   ```
   Uploading distributions to http://gitea:3000/api/packages/dev/pypi
   Uploading fretexpress-1.0.<N>-py3-none-any.whl
   ```
7. Vérifier le registre : Gitea › `dev` › **Paquets** : `fretexpress` (PyPI) et `fretexpress` (conteneur), version `1.0.<N>`.
8. Vérifier l'image et sa traçabilité.
   ```bash
   docker image inspect localhost:3000/dev/fretexpress:1.0.<N> \
     --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}'
   ```
   Résultat attendu : SHA complet du commit de fusion (comparer avec `git log -1 --format=%H origin/main`).
9. Notification : casser un test sur une branche → mail `ECHEC fretexpress/PR-<N> #<n>` dans Mailpit ; corriger → mail `REPARE ...`.

### Critères de réussite
- [ ] Paquet PyPI et image `1.0.<N>` dans Gitea, publiés par le build `main` (aucun push d'image depuis une MR)
- [ ] Label de révision de l'image = SHA du commit
- [ ] Mails `ECHEC` puis `REPARE` reçus dans Mailpit

---

## Défi 06.4 ⭐⭐⭐ — Version de release par tag Git (autonome)
**Durée** : 20 min · **Objectif** : un tag `v1.1.0` produit la version `1.1.0` (et non `1.0.<build>`)
**Énoncé** : faire découvrir les tags au job multibranche ; dans l'étape `Version`, utiliser le nom du tag quand le build porte sur un tag ; autoriser la publication pour `main` ET pour les tags.
**Critères de réussite** :
- [ ] Tag `v1.1.0` poussé → job `v1.1.0` construit (déclenchement manuel accepté), version `1.1.0` publiée
- [ ] Les builds de `main` continuent de produire `1.0.<build>`

---

## Bonus 🚀
Installer le paquet publié depuis le registre dans un venv neuf :
`pip install --index-url http://localhost:3000/api/packages/dev/pypi/simple --extra-index-url https://pypi.org/simple fretexpress==1.0.<N>` puis `python -c "import fretexpress; print(fretexpress.__version__)"`.
