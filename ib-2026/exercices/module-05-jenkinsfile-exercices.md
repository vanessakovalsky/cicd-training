# Module 05 — Exercices

Point de départ : `main` à l'état fin M04 (36 tests). Retard : `scripts/m04/catch-up/catch-up.sh`.

## Lab 05.1 ⭐ — Écrire un pipeline de build et de tests (guidé)
**Durée** : 55 min · **Objectif** : Jenkinsfile déclaratif versionné, exécuté par un job Pipeline
**Contexte** : la configuration de `premier-job` n'est ni versionnée ni relue ; l'équipe veut la chaîne dans le dépôt.
**Prérequis** : agent `agent-python` en ligne

### Étapes
1. Créer la branche.
   ```bash
   cd ~/fretexpress && git switch main && git pull
   git switch -c ci/jenkinsfile
   ```
2. Créer `Jenkinsfile` à la racine (contenu des slides « Le Jenkinsfile FretExpress (1/3) à (3/3) »).
3. Valider la syntaxe avant tout commit.
   Variables : `<MOT_DE_PASSE_ADMIN>` = mot de passe Jenkins de `admin`.
   ```bash
   curl -s -u admin:<MOT_DE_PASSE_ADMIN> -X POST -F "jenkinsfile=<Jenkinsfile" \
        http://localhost:8080/pipeline-model-converter/validate
   ```
   Résultat attendu : `Jenkinsfile successfully validated.`
4. Commit et push.
   ```bash
   git add Jenkinsfile
   git commit -m "ci: pipeline declaratif de build et de tests"
   git push -u origin ci/jenkinsfile
   ```
5. Jenkins › **New Item** › `fretexpress-pipeline` › **Pipeline** › **OK** :
   - **Pipeline** › Definition : **Pipeline script from SCM** › SCM : **Git**
   - Repository URL : `http://localhost:3000/dev/fretexpress.git` · Branch Specifier : `*/ci/jenkinsfile`
   - Script Path : `Jenkinsfile` › **Save**
6. **Build Now**, puis **Pipeline Overview** (vue graphique) et **Console Output**.
   Résultat attendu (fin de console) :
   ```
   [Pipeline] junit
   Recording test results
   [Pipeline] archiveArtifacts
   Archiving artifacts
   Recording fingerprints
   Finished: SUCCESS
   ```
7. Ouvrir **Test Result** (36 tests) et **Build Artifacts** (`fretexpress-1.0.0-py3-none-any.whl`).
8. Introduire une erreur de syntaxe (`step` au lieu de `steps`), relancer le validateur, lire le message, corriger.
   Résultat attendu (validateur) :
   ```
   WorkflowScript: 4: Unknown stage section "step". Starting with version 0.5, steps in a stage must be in a ‘steps’ block.
   ```

### Critères de réussite
- [ ] `Jenkinsfile` sur la branche `ci/jenkinsfile`, validé
- [ ] Build au vert : 3 étapes visibles, rapport de 36 tests, wheel archivé
- [ ] Aucune configuration de build saisie dans l'interface (hors source du Jenkinsfile)

---

## Lab 05.2 ⭐ — Multibranche, webhook et statut de MR (guidé)
**Durée** : 65 min · **Objectif** : chaque push et chaque MR construits automatiquement, fusion bloquée si rouge
**Contexte** : avec plusieurs branches actives, un job par branche configuré à la main ne tient pas.

### Étapes
1. Jeton Gitea : connexion `dev` › avatar › **Paramètres** › **Applications** › **Générer un nouveau jeton** : nom `jenkins`, permissions **repository : Lecture et écriture**, **package : Lecture et écriture**, **issue : Lecture et écriture**, **user : Lecture** › copier le jeton (affiché une seule fois).
2. Credential Jenkins : **Manage Jenkins** › **Credentials** › **System** › **Global credentials** › **Add Credentials** : **Username with password**, Username `dev`, Password = jeton, ID `gitea-dev`, Scope **Global**.
3. Serveur Gitea : **Manage Jenkins** › **System** › **Gitea Servers** › **Add** : Display Name `gitea`, Server URL `http://gitea:3000`, Alias URL `http://localhost:3000`, **Manage hooks** décoché › **Save**.
4. Job multibranche : **New Item** › `fretexpress` › **Multibranch Pipeline** :
   - **Branch Sources** › **Add source** › **Gitea** : Server `gitea`, Credentials `gitea-dev`, Owner `dev`, Repository `fretexpress`
   - Behaviours (par défaut) : **Discover branches**, **Discover pull requests from origin**
   - **Scan Multibranch Pipeline Triggers** › **Periodically if not otherwise run** : `1 hour`
   - **Save** → scan automatique.
   Résultat attendu (journal du scan) : `Checking branch ci/jenkinsfile` … `Met criteria` ; `main` sans Jenkinsfile → `Does not meet criteria`.
5. Webhook : Gitea › dépôt `fretexpress` › **Paramètres** › **Webhooks** › **Ajouter un webhook** › **Gitea** : URL `http://jenkins:8080/gitea-webhook/post`, méthode POST, type `application/json`, déclencheurs **Push**, **Création**, **Suppression**, **Pull request** › **Ajouter**. Bouton **Tester la livraison** : réponse `200`.
6. Ouvrir la MR `ci/jenkinsfile` → `main`. Constater, sans aucun clic dans Jenkins : job `PR-<N>` créé et construit ; statut `fretexpress/pipeline/pr-main` sur la MR.
7. Exiger le vert : Gitea › **Paramètres** › **Branches** › règle `main` › **Activer la vérification du statut** › motif `fretexpress/pipeline/pr-*` › **Enregistrer**.
8. Preuve du blocage : sur la branche, casser un test, pousser → statut `failure`, bouton de fusion bloqué. Corriger, pousser → `success`.
9. Approbation par `reviewer`, fusion. Le job `main` est construit automatiquement (webhook push).
10. Supprimer `fretexpress-pipeline` (remplacé par le multibranche).

### Critères de réussite
- [ ] Job `fretexpress` avec `main` et `PR-<N>`, construits sans clic
- [ ] Statut Jenkins visible sur la MR ; fusion refusée tant que le statut est `failure`
- [ ] Webhook : livraisons récentes en `200`

---

## Exercice 05.3 ⭐⭐ — Déclencheurs complémentaires (semi-autonome)
**Durée** : 15 min · **Objectif** : choisir le bon déclencheur selon le besoin
**Énoncé** : ajouter au Jenkinsfile un build de nuit de `main` uniquement (tests complets avec ordre aléatoire différent chaque nuit). Les branches de fonctionnalité ne doivent PAS être construites la nuit.
**Indices** : directive `triggers`, variable `env.BRANCH_NAME`, expression ternaire Groovy.
**Critères de réussite** :
- [ ] Après un build de `main` : **View Configuration** du job `main` montre le déclencheur périodique ; celui d'une autre branche, non
- [ ] Justification : pourquoi pas `pollSCM` en plus du webhook

---

## Défi 05.4 ⭐⭐⭐ — Pipeline plus robuste (autonome)
**Durée** : 20 min · **Objectif** : pipeline qui échoue vite et proprement
**Énoncé** : enrichir le Jenkinsfile : `timeout` par étape (installation : 5 min), message d'aide en cas d'échec des tests (`post` d'étape), nettoyage du workspace en fin de build sauf en échec (diagnostic), nom de build lisible (`#<N> - <commit court>`).
**Critères de réussite** :
- [ ] Échec volontaire : message d'aide affiché, workspace conservé
- [ ] Succès : workspace vidé
- [ ] Nom des builds au format demandé

---

## Bonus 🚀
Comparer la durée du build `main` déclenché par webhook et celle d'un build déclenché par scrutation (`pollSCM('H/5 * * * *')` temporaire) : délai entre le push et le début du build.
