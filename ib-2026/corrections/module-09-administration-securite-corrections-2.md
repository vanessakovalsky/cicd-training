# Module 09 — Corrections, bloc 2

Bloc 2 (séquences S9.3, S9.4). Autre bloc : `module-09-administration-securite-corrections-1.md`.

Configuration de référence : `scripts/m09/catch-up/jenkins.yaml` (utilisateurs, rôles, contrôleur sans exécuteur, journal d'audit).

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
