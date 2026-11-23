# Module 06 — Exercices, bloc 2

Bloc 2 : séquences S6.3. Point de départ : labs du bloc 1 terminés (`module-06-qualite-artefacts-exercices-1.md`).
Toutes les modifications passent par une branche et une MR (`main` protégée, pipeline au vert exigé).

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
