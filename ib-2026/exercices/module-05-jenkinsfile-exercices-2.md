# Module 05 — Exercices, bloc 2

Bloc 2 : séquences S5.3, S5.4. Point de départ : labs du bloc 1 terminés (`module-05-jenkinsfile-exercices-1.md`).

## Lab 05.2 ⭐ — Multibranche, webhook et statut de MR (guidé)
**Durée** : 65 min · **Objectif** : chaque push et chaque MR construits automatiquement, fusion bloquée si rouge
**Contexte** : avec plusieurs branches actives, un job par branche configuré à la main ne tient pas.

### Étapes
1. Jeton Gitea : connexion `dev` › avatar › **Paramètres** › **Applications** › **Générer un nouveau jeton** : nom `jenkins`, permissions **repository : Lecture et écriture**, **package : Lecture et écriture**, **issue : Lecture et écriture**, **user : Lecture**, **organization : Lecture** (sans ce droit, liste des dépôts vide à l'étape 4) › copier le jeton (affiché une seule fois).
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

## Bonus 🚀
Comparer la durée du build `main` déclenché par webhook et celle d'un build déclenché par scrutation (`pollSCM('H/5 * * * *')` temporaire) : délai entre le push et le début du build.
