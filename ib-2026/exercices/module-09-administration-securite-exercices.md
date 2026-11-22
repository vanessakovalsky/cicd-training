# Module 09 — Exercices

Point de départ : état fin M08 (chaîne complète, compte `admin` unique). Retard : `scripts/m08/catch-up/catch-up.sh`.

## Lab 09.1 ⭐ — Utilisateurs, rôles et permissions (guidé)
**Durée** : 40 min · **Objectif** : un compte par personne, droits par métier, politique exportée en JCasC
**Contexte** : audit interne FretExpress : « compte administrateur partagé par 6 personnes, aucune traçabilité ».

### Étapes
1. Créer les comptes : **Manage Jenkins** › **Users** › **Create User** : `dev1`, `recette1`, `ops1` (mot de passe noté, adresse `<id>@fretexpress.localhost`).
2. Activer les rôles : **Manage Jenkins** › **Security** › **Authorization** : **Role-Based Strategy** › **Save**.
   ⚠️ Ne pas fermer la session `admin` avant l'étape 4 : vérifier dans **Assign Roles** que `admin` porte le rôle `admin` (attribution automatique à l'activation `[À VÉRIFIER]`).
3. **Manage Jenkins** › **Manage and Assign Roles** › **Manage Roles** :
   - Rôles globaux : `admin` (**Overall/Administer**) ; `lecteur` (**Overall/Read**) ; `exploitant` (**Overall/Read**, **Agent/Configure**, **Agent/Connect**, **Agent/Disconnect**)
   - Rôles d'items : `fretexpress-dev`, motif `fretexpress.*`, **Job/Read**, **Job/Build**, **Job/Cancel**, **Job/Workspace** ; `fretexpress-recette`, motif `fretexpress.*`, **Job/Read**, **Job/Build**
   - **Save**
4. **Assign Roles** : `admin` → `admin` ; groupe **Authenticated Users** → `lecteur` ; `ops1` → `exploitant` ; `dev1` → `fretexpress-dev` ; `recette1` → `fretexpress-recette` › **Save**.
5. Vérifier par l'API (variables : `<MDP>` = mot de passe de l'utilisateur testé).
   ```bash
   for u in dev1 ops1 recette1; do
     echo "$u job=$(curl -s -o /dev/null -w '%{http_code}' -u $u:<MDP> \
       http://localhost:8080/job/fretexpress/api/json) manage=$(curl -s -o /dev/null \
       -w '%{http_code}' -u $u:<MDP> http://localhost:8080/manage/)"
   done
   ```
   Résultat attendu :
   ```
   dev1 job=200 manage=403
   ops1 job=404 manage=403
   recette1 job=200 manage=403
   ```
6. Approbation : lancer un build `main` ; tenter d'approuver avec `dev1` (fenêtre privée) puis avec `recette1`.
   Résultat attendu : `dev1` n'a pas de bouton d'approbation ; `recette1` approuve, console `Approved by <nom complet de recette1>`.
7. Configuration as Code : **Manage Jenkins** › **Configuration as Code** › **View Configuration** : retrouver `roleBased` et les utilisateurs. Comparer avec `scripts/m09/catch-up/jenkins.yaml`.
8. Rendre la politique durable : copier la section `authorizationStrategy` exportée dans `environnement/jenkins/casc/jenkins.yaml` (sinon un prochain rechargement JCasC rétablit « Logged-in users can do anything »).

### Critères de réussite
- [ ] Matrice de l'étape 5 obtenue
- [ ] Approbation refusée à `dev1`, acceptée pour `recette1`
- [ ] `jenkins.yaml` de travail contient la stratégie `roleBased`

---

## Exercice 09.2 ⭐ — Dimensionner les agents (semi-autonome)
**Durée** : 15 min · **Objectif** : estimer le nombre d'exécuteurs et choisir le type d'agent
**Énoncé** : FretExpress passe à 6 développeurs, 3 dépôts. Pic mesuré : 30 builds de MR par heure (2 min chacun) + 4 builds de `main` par heure (4 min, attente d'approbation EXCLUE : agent libéré). Calculer le nombre d'exécuteurs avec une marge de 1,5. Proposer la répartition sur des agents de 4 cœurs / 8 Go, et justifier permanent ou éphémère.
**Critères de réussite** :
- [ ] Calcul détaillé et résultat arrondi au supérieur
- [ ] Choix argumenté (propreté, cache, coût, sécurité du socket Docker)

---

## Lab 09.3 ⭐⭐ — Sauvegarder et restaurer (semi-guidé)
**Durée** : 30 min · **Objectif** : sauvegarde complète ET restauration vérifiée
### Étapes
1. Sauvegarder.
   ```bash
   scripts/m09/labs/sauvegarde-jenkins.sh
   ```
   Résultat attendu :
   ```
   Sauvegarde : sauvegardes/jenkins-home-<DATE>.tgz (1,7M)
   Export JCasC : sauvegardes/jenkins-casc-<DATE>.yaml
   ```
2. Lister le contenu de l'archive : présence de `secrets/master.key`, `credentials.xml`, `users/`, `jobs/` ; absence de `workspace/` et `plugins/`.
   ```bash
   tar tzf sauvegardes/jenkins-home-*.tgz | grep -E '^\./(secrets/master.key|credentials.xml|users/|plugins/)' | head
   ```
3. Lire l'export JCasC : comment apparaissent les secrets ?
4. Restaurer sur une instance de test (port 8081) et vérifier.
   ```bash
   scripts/m09/labs/restauration-test.sh sauvegardes/jenkins-home-<DATE>.tgz
   ```
   Résultat attendu : `Demarrage de jenkins-restauration ... OK : http://localhost:8081`. Se connecter en `dev1` : job `fretexpress` visible, historique des builds présent.
5. Nettoyer : `scripts/m09/labs/restauration-test.sh --nettoyer`.

### Critères de réussite
- [ ] Restauration réussie : comptes, rôles, jobs et historique présents sur l'instance de test
- [ ] Explication : rôle de `secrets/master.key` ; pourquoi exclure `plugins/` et `workspace/`
- [ ] Instance de test supprimée

---

## Lab 09.4 ⭐⭐ — Credentials de dossier et audit de sécurité (semi-guidé)
**Durée** : 35 min · **Objectif** : secret limité à un projet ; écarts de sécurité mesurés et corrigés
### Étapes
1. Credential de portée dossier : job `fretexpress` › **Credentials** › **Stores scoped to fretexpress** › **Global credentials** › **Add Credentials** : **Secret text**, ID `api-carburant`, valeur fictive.
2. Vérifier la portée : `premier-job` › **Configure** › **Environment** › **Use secret text(s) or file(s)** › **Add** › **Secret text** : `api-carburant` absent de la liste. Annuler.
3. Auditer.
   ```bash
   scripts/m09/labs/audit-securite.sh
   ```
   Résultat attendu (extrait) :
   ```
   OK  Executeurs du controleur : 0
   OK  Strategie d'autorisation : RoleBasedAuthorizationStrategy
   INFO Credentials de portee GLOBAL : gitea-dev, sonar-token, registre-lecture
   Resultat : 0 KO
   ```
4. Corriger chaque `KO` (ex. journal d'audit : **Manage Jenkins** › **System** › **Audit Trail** › **Add Logger** › **Log file** : `/var/jenkins_home/audit/audit.log`, taille 10 Mo, 5 fichiers) puis relancer l'audit.
5. Lire le journal d'audit après une modification de job.
   ```bash
   docker exec cicd-jenkins-1 sh -c 'tail -3 /var/jenkins_home/audit/audit.log.0'
   ```
6. Lister les credentials de portée GLOBAL : lesquels pourraient passer en portée dossier ? Lesquels sont utilisés par des intégrations système (SonarQube) ?

### Critères de réussite
- [ ] `api-carburant` invisible hors du dossier `fretexpress`
- [ ] Audit à `0 KO`
- [ ] Journal d'audit : action identifiée (qui, quoi, quand)

---

## Défi 09.5 ⭐⭐⭐ — Rotation d'un secret sans interruption (autonome)
**Durée** : 20 min · **Objectif** : remplacer le jeton de déploiement sans casser la chaîne
**Énoncé** : générer un nouveau jeton Gitea `deploiement-2` (lecture des paquets), le mettre en service dans Jenkins (credential `registre-lecture` : par l'interface OU par le fichier `environnement/secrets/registre_token` + rechargement JCasC), vérifier un déploiement en intégration, puis révoquer l'ancien jeton et revérifier.
**Critères de réussite** :
- [ ] Déploiement réussi avec le nouveau jeton, ancien jeton révoqué dans Gitea
- [ ] Procédure écrite en 5 étapes maximum, ordre justifié (activer avant de révoquer)

---

## Bonus 🚀
Lire **Manage Jenkins** › **In-process Script Approval** : quelles signatures sont en attente ? Pourquoi ne jamais tout approuver en masse ?
