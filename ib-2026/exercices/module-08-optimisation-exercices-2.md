# Module 08 — Exercices, bloc 2

Bloc 2 : séquences S8.3, S8.4. Point de départ : labs du bloc 1 terminés (`module-08-optimisation-exercices-1.md`).
Mesures de durée : sur des builds de BRANCHE (pas de déploiement ni d'attente d'approbation).

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
