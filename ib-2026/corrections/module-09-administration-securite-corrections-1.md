# Module 09 — Corrections, bloc 1

Bloc 1 (séquences S9.1, S9.2). Autre bloc : `module-09-administration-securite-corrections-2.md`.

Configuration de référence : `scripts/m09/catch-up/jenkins.yaml` (utilisateurs, rôles, contrôleur sans exécuteur, journal d'audit).

## Lab 09.1 ⭐ — Utilisateurs, rôles et permissions
### Solution
Extrait JCasC de référence :
```yaml
jenkins:
  numExecutors: 0
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: dev1
          name: Developpeuse FretExpress
          password: "${readFile:/run/secrets/formation/utilisateurs_password}"
  authorizationStrategy:
    roleBased:
      roles:
        global:
          - name: admin
            permissions: ["Overall/Administer"]
            entries:
              - user: admin
          - name: lecteur
            permissions: ["Overall/Read"]
            entries:
              - group: authenticated
          - name: exploitant
            permissions: ["Agent/Configure", "Agent/Connect", "Agent/Disconnect"]
            entries:
              - user: ops1
        items:
          - name: fretexpress-dev
            pattern: "fretexpress.*"
            permissions: ["Job/Read", "Job/Build", "Job/Cancel", "Job/Workspace"]
            entries:
              - user: dev1
          - name: fretexpress-recette
            pattern: "fretexpress.*"
            permissions: ["Job/Read", "Job/Build"]
            entries:
              - user: recette1
```
Matrice relevée sur le banc :
```
dev1 job=200 manage=403
ops1 job=404 manage=403
recette1 job=200 manage=403
```
Approbation par `dev1` (API) : `400` ; par `recette1` : `200`, console `Approved by Recetteur FretExpress`.
### Pourquoi
- `Overall/Read` au groupe `authenticated` : condition pour se connecter ; aucun droit sur les jobs sans rôle d'item.
- Motif `fretexpress.*` : couvre le job multibranche et ses branches (`fretexpress/main`, `fretexpress/PR-3`).
- `submitter 'admin,recette1'` dans le Jenkinsfile : l'approbation est un droit DISTINCT du droit de lancer un build.
- `Overall/Read` donné à tous pour simplifier : `ops1` voit la page des agents (`/computer/agent-python` → `200`) mais pas les jobs (`404`).
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| `admin` bloqué après **Save** | Rôle `admin` non attribué | `docker exec` : remettre `loggedInUsersCanDoAnything` dans `casc/jenkins.yaml`, redémarrer Jenkins |
| `dev1` : `Access Denied` à la connexion | `Overall/Read` absent | Rôle `lecteur` à **Authenticated Users** |
| `dev1` ne voit aucun job | Motif d'item incorrect (`fretexpress` sans `.*`) | Motif = expression régulière : `fretexpress.*` |
| Rôles perdus après un rattrapage | `jenkins.yaml` de travail non mis à jour | Étape 8 ; ou rattrapage M09 |

## Exercice 09.2 ⭐ — Dimensionner les agents
### Solution
- MR : 30 × 2 min = 60 min de build par heure = 1,00 exécuteur occupé en continu.
- `main` : 4 × 4 min = 16 min par heure = 0,27 exécuteur.
- Total : 1,27 × 1,5 = 1,9 → **2 exécuteurs** au pic ; 1 agent de 4 cœurs avec 2 à 3 exécuteurs suffit, 2 agents pour la redondance.
- Recommandation : agents éphémères (conteneurs) pour les MR (environnement propre, coût nul au repos, cache pip sur volume) ; agent de déploiement séparé, seul à accéder au démon Docker cible.
### Pourquoi
L'approbation retenue un exécuteur dans le pipeline actuel (agent global) : à exclure du calcul seulement si le pipeline libère l'agent pendant l'attente (`agent none` + agent par étape).
