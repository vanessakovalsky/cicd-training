# Module 01 — Exercices

Poste local : commandes dans un terminal du poste. VM cloud : commandes dans une session SSH sur la VM (`ssh -i stagiaire-<NN> stagiaire@<IP_VM>`), dossier de la formation `/opt/formation`.

## Lab 01.1 ⭐ — Versionner FretExpress et le publier sur Gitea (guidé)
**Durée** : 20 min · **Objectif** : dépôt `dev/fretexpress` sur Gitea, branche `main` suivie
**Contexte** : le code de FretExpress n'est versionné nulle part ; la seule copie est sur le poste de Kevin.
**Prérequis** : lab 00.1 terminé ; mot de passe de `dev` dans `environnement/acces.txt`

### Étapes
1. Configurer l'identité Git (une fois par poste).
   ```bash
   git config --global user.name "Dev FretExpress"
   git config --global user.email "dev@fretexpress.localhost"
   git config --global init.defaultBranch main
   ```
2. Copier le code de départ hors du dossier de la formation.
   Variables : `<FORMATION>` = dossier de la formation (VM : `/opt/formation`).
   ```bash
   cp -r <FORMATION>/fil-rouge/fretexpress ~/fretexpress
   cd ~/fretexpress
   ls -a
   ```
   Résultat attendu : `.gitignore  pyproject.toml  README.md  src  tests`
3. Lire `.gitignore` : `.venv/`, `__pycache__/`, `reports/`, `dist/` sont exclus.
4. Créer le dépôt vide sur Gitea : connexion `dev` › **+** › **Nouveau dépôt** › nom `fretexpress`, visibilité publique, **aucune** initialisation (ni README, ni `.gitignore`) › **Créer le dépôt**.
5. Initialiser, committer, publier.
   ```bash
   git init
   git add .
   git status --short
   git commit -m "chore: import initial de FretExpress"
   git remote add origin http://localhost:3000/dev/fretexpress.git
   git push -u origin main
   ```
   Résultat attendu (fin, après saisie de `dev` et du mot de passe) :
   ```
   branch 'main' set up to track 'origin/main'.
   ```
6. Mémoriser les identifiants pour la journée (poste de formation uniquement).
   ```bash
   git config --global credential.helper 'cache --timeout=36000'
   ```
7. Ajouter le collègue relecteur : dépôt › **Paramètres** › **Collaborateurs** › `reviewer`, droit **Écriture**.
8. Vérifier dans Gitea : 6 fichiers, 1 commit, branche `main`.

### Critères de réussite
- [ ] `git log --oneline` affiche 1 commit au format Conventional Commits
- [ ] `git status` : `rien à valider, la copie de travail est propre` (ou `nothing to commit, working tree clean`)
- [ ] Gitea : dépôt `dev/fretexpress` visible, `reviewer` collaborateur

---

## Exercice 01.2 ⭐⭐ — Choisir et documenter la stratégie de branches (semi-autonome)
**Durée** : 25 min · **Objectif** : règles d'équipe écrites, validées par merge request
**Contexte** : l'équipe FretExpress (3 développeurs, objectif : livrer plusieurs fois par semaine) doit choisir un workflow.
**Énoncé** :
1. Choisir entre Git Flow, GitHub Flow et trunk-based ; justifier en 3 lignes.
2. Rédiger `CONTRIBUTING.md` : stratégie, nommage des branches, format des commits, règles de revue.
3. Le proposer par une branche `docs/contributing` et une merge request ; obtenir l'approbation de `reviewer` (fenêtre de navigation privée) ; fusionner.
**Indices** : `git switch -c`, `git push -u origin <branche>` ; Gitea propose un lien de création de MR après le push.
**Critères de réussite** :
- [ ] `CONTRIBUTING.md` présent sur `main`, avec stratégie, nommage, format de commit, revue
- [ ] MR fusionnée, approuvée par `reviewer`, branche supprimée après fusion

---

## Lab 01.3 ⭐ — Revue, conflit et protection de `main` (guidé)
**Durée** : 60 min · **Objectif** : contribution complète par MR malgré un conflit ; `main` protégée
**Contexte** : description du déploiement cible à ajouter dans le README ; un collègue modifie le même passage en parallèle.

### Étapes
1. Protéger `main` : dépôt › **Paramètres** › **Branches** › **Ajouter une nouvelle règle** :
   - Motif : `main`
   - Push : **Désactiver le push**
   - Approbations requises : `1`
   - Cocher **Rejeter les approbations obsolètes** et **Bloquer la fusion en cas de revue rejetée**
   - **Enregistrer la règle**
2. Vérifier la protection : tenter un push direct.
   ```bash
   cd ~/fretexpress && git switch main && git pull
   echo "test" >> README.md && git commit -am "docs: essai push direct"
   git push
   ```
   Résultat attendu :
   ```
   ! [remote rejected] main -> main (pre-receive hook declined)
   ```
   Annuler l'essai : `git reset --hard origin/main`.
3. Créer la branche de contribution et modifier la section « Deploiement actuel » du README.
   ```bash
   git switch -c docs/deploiement-cible
   ```
   Remplacer la ligne sous `## Deploiement actuel` par :
   `Cible : pipeline Jenkins, de chaque commit sur main jusqu'a la production.`
   ```bash
   git commit -am "docs: decrire le deploiement cible"
   git push -u origin docs/deploiement-cible
   ```
4. Ouvrir la merge request dans Gitea (titre = message du commit).
5. Simuler le collègue : il fusionne une autre version du même paragraphe sur `main` (script lancé par le stagiaire ou le formateur).
   ```bash
   <FORMATION>/scripts/m01/labs/simuler-collegue.sh
   ```
   Résultat attendu : `Merge request #<N> du collegue fusionnee sur main (README modifie)`. La MR du stagiaire affiche alors un conflit.
6. Résoudre le conflit par rebase.
   ```bash
   git pull --rebase origin main
   ```
   Résultat attendu :
   ```
   CONFLICT (content): Merge conflict in README.md
   ```
   Ouvrir `README.md`, garder une version qui combine les deux informations (situation actuelle ET cible), supprimer les marqueurs `<<<<<<<`, `=======`, `>>>>>>>`.
   ```bash
   git add README.md
   git rebase --continue
   git push --force-with-lease
   ```
7. Revue : se connecter en `reviewer` (fenêtre privée), ouvrir la MR › **Fichiers modifiés** › ajouter un commentaire sur une ligne › **Valider la revue** : **Demander des changements**.
8. Côté `dev` : corriger, `git commit -am "docs: ..."`, `git push`. Côté `reviewer` : **Approuver**.
9. Fusionner la MR (bouton **Créer un commit de fusion** ou **Rebaser puis fusionner**) ; supprimer la branche.

### Critères de réussite
- [ ] Push direct sur `main` refusé
- [ ] README de `main` : plus aucun marqueur de conflit (`grep -c '<<<<<<<' README.md` → `0`)
- [ ] MR : un « changement demandé » puis une approbation de `reviewer`, puis fusion
- [ ] `git log --oneline --graph` montre le commit du collègue et le commit du stagiaire

---

## Défi 01.4 ⭐⭐⭐ — Contrôler le format des commits localement (autonome)
**Durée** : 15 min · **Objectif** : refuser un message non conforme AVANT le push
**Contexte** : l'équipe veut une vérification Conventional Commits sans attendre la CI.
**Énoncé** : écrire un hook Git `commit-msg` (script shell ou Python) qui refuse tout message ne respectant pas `<type>(<portée>)?: <résumé>` avec les types de `CONTRIBUTING.md`. Le versionner dans `.githooks/` et l'activer par `git config core.hooksPath .githooks`.
**Critères de réussite** :
- [ ] `git commit -m "update"` refusé avec un message explicite
- [ ] `git commit -m "docs(readme): corriger le lien"` accepté
- [ ] Hook versionné dans le dépôt, mode d'activation documenté dans `CONTRIBUTING.md`

---

## Bonus 🚀
Comparer `git log --oneline --graph` après une fusion « commit de fusion » et après une fusion « rebaser puis fusionner » (deux petites MR) : quel historique facilite `git bisect` ?
