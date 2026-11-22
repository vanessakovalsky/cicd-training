# Module 09 — Corrections

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

## Lab 09.3 ⭐⭐ — Sauvegarder et restaurer
### Solution
Sorties relevées sur le banc :
```
Sauvegarde : sauvegardes/jenkins-home-20261113-1037.tgz (1,7M)
Export JCasC : sauvegardes/jenkins-casc-20261113-1037.yaml
Demarrage de jenkins-restauration ... OK : http://localhost:8081 (memes comptes que l'instance sauvegardee)
```
Contrôle sur l'instance restaurée : `curl -u dev1:<MDP> http://localhost:8081/job/fretexpress/api/json` → `200`.
### Pourquoi
- `secrets/master.key` chiffre les clés qui chiffrent `credentials.xml` : sans elle, les credentials restaurés sont illisibles.
- `plugins/` (174 Mo sur le banc) : reconstruit par l'image (`plugins.txt` figé) ; `workspace/` : reconstruit par les builds.
- L'export JCasC ne contient pas les valeurs des secrets en clair (valeurs chiffrées ou masquées) : il ne remplace pas l'archive.
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| `Bind for 0.0.0.0:8081 failed` | Port 8081 occupé | Libérer le port ou modifier le script (`-p 8082:8080`) |
| Instance restaurée sans plugins | Image différente de celle de la sauvegarde | Utiliser `cicd-formation/jenkins:local` (même `plugins.txt`) |
| Agents hors ligne sur l'instance de test | Instance hors du réseau `cicd` | Normal : test de restauration de la configuration seulement |

## Lab 09.4 ⭐⭐ — Credentials de dossier et audit de sécurité
### Solution
Audit relevé sur le banc après rattrapage M09 :
```
OK  Executeurs du controleur : 0
OK  Strategie d'autorisation : RoleBasedAuthorizationStrategy
OK  Lecture anonyme desactivee
OK  Protection CSRF active
OK  Formateur de texte : EscapedMarkupFormatter
OK  Comptes nominatifs : admin, dev1, ops1, recette1
INFO Credentials de portee GLOBAL : gitea-dev, sonar-token, registre-lecture
OK  Plugins sans avis de securite actif
OK  Journal d'audit : /var/jenkins_home/audit/audit.log
Resultat : 0 KO
```
Journal d'audit en JCasC :
```yaml
unclassified:
  audit-trail:
    logBuildCause: true
    loggers:
      - logFile:
          log: /var/jenkins_home/audit/audit.log
          limit: 10
          count: 5
```
Question 6 : `gitea-dev` et `registre-lecture` (utilisés par le seul pipeline FretExpress) → portée dossier `fretexpress` ; `sonar-token` → référencé par la configuration globale du serveur SonarQube, à garder global (ou System selon l'usage).
### Pourquoi
Portée dossier : un autre projet hébergé sur la même instance ne peut pas utiliser le jeton de déploiement de FretExpress.
### Variantes acceptables
Domaines de credentials (restriction par nom d'hôte) : complémentaires, moins lisibles que la portée dossier.

## Défi 09.5 ⭐⭐⭐ — Rotation d'un secret sans interruption
### Solution
1. Gitea : nouveau jeton `deploiement-2` (**package : Lecture**).
2. Jenkins : mettre à jour `registre-lecture` (interface) ; avec JCasC : `printf '%s' '<JETON>' > environnement/secrets/registre_token` puis **Configuration as Code** › **Reload existing configuration**.
3. Vérifier : rejouer un build `main` (étape `Deploiement integration` au vert).
4. Révoquer `deploiement` dans Gitea.
5. Revérifier : nouveau build au vert.
### Pourquoi
Activer avant de révoquer : aucune fenêtre sans jeton valide. Revérifier après révocation : prouve qu'aucun composant n'utilisait encore l'ancien jeton.

## Bonus
Une signature approuvée ouvre une méthode Java à TOUS les scripts de l'instance ; approuver en masse revient à désactiver le bac à sable.

## QCM — Réponses
1. **B** — Le security realm authentifie ; la stratégie d'autorisation attribue les droits.
2. **B** — Sans `Overall/Read`, aucune page n'est accessible.
3. **B** — 40 × 0,05 h × 1,5 = 3.
4. **B** — `credentials.xml` est inutilisable sans `secrets/master.key`.
5. **B** — Le démon Docker permet de monter le système de fichiers de l'hôte dans un conteneur privilégié.
6. **C** — Portée dossier : jobs du dossier seulement.
7. **B** — JCasC remplace la liste des credentials système qu'il déclare.
