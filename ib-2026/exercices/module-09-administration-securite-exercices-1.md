# Module 09 — Exercices, bloc 1

Bloc 1 : séquences S9.1, S9.2. Bloc 2 : `module-09-administration-securite-exercices-2.md`.

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
