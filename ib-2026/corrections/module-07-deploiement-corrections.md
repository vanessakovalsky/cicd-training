# Module 07 — Corrections

Fichiers de référence : `fil-rouge/solutions/m07/Jenkinsfile` et `fil-rouge/solutions/m07/deploy/`.

## Lab 07.1 ⭐ — Déployer automatiquement en intégration
### Solution
Étape de l'énoncé. Sortie relevée sur le banc (build `main` n° 8) :
```
[deploy] Image localhost:3000/dev/fretexpress:1.0.8 recuperee
[deploy] Conteneur fretexpress-int (1.0.8) lance, hote int.fretexpress.localhost
[fumee] int.fretexpress.localhost OK (version 1.0.8)
```
Réponses aux questions de lecture :
- `docker pull` (fonction `recuperer_image`), après `docker login` avec le jeton de lecture.
- Labels : `traefik.enable=true`, règle `Host(\`int.fretexpress.localhost\`)`, point d'entrée `web`, port `8000`.
- `test-fumee.sh` : `/version` contient la version attendue (20 essais, 2 s d'intervalle) ET `/health` répond.
### Pourquoi
- Même image que celle publiée : la promotion commence ici.
- `docker rm -f` puis `docker run` : stratégie « recréation », interruption de quelques secondes acceptable en intégration.
- Jeton `read:package` : le déploiement n'a pas besoin d'écrire dans le registre.
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| `deploy/deployer.sh: Permission denied` | Bit exécutable perdu | `git update-index --chmod=+x deploy/*.sh` puis commit |
| `[fumee] ... KO : version attendue ..., obtenue aucune reponse` | Conteneur en échec au démarrage | `docker logs fretexpress-int` |
| `pull access denied` | Jeton invalide ou sans `package` | Nouveau jeton, credential mis à jour |
| Navigateur : `404 page not found` (Traefik) | Nom d'hôte erroné ou conteneur absent | Tableau de bord Traefik (http://localhost:8090) |
| URL inaccessible en cloud | Tunnel sans `-L 8000:localhost:80` | URL en `:8000` |

## Exercice 07.2 ⭐⭐ — Approbation avant recette et secrets protégés
### Solution
Étape `Recette` : voir slide et Jenkinsfile de référence.
Console de l'étape temporaire :
```
Warning: A secret was passed to "sh" using Groovy String interpolation, which is insecure.
+ echo 'jeton : ****'
jeton : ****
+ echo jeton : ****
jeton : ****
```
Expiration de l'approbation : `Timeout has been exceeded` puis build `ABORTED`, étapes suivantes sautées.
### Pourquoi
- Masquage : Jenkins remplace dans la console toute occurrence de la valeur du secret. Il ne protège pas d'un secret transformé (encodage base64, découpage) ni d'un secret écrit dans un fichier archivé.
- Guillemets doubles : Groovy insère la valeur dans le texte du script avant exécution → secret visible dans la ligne de commande du processus (`ps`), dans les fichiers temporaires du script et dans les vues de rejeu.
- `ABORTED` ≠ `FAILURE` : absence de décision, pas d'erreur ; aucune notification d'échec.
- `beforeInput true` : par défaut, la directive `input` d'une étape est évaluée AVANT sa condition `when` ; sans cette option, chaque build de MR attend une approbation (exécuteur bloqué jusqu'au `timeout`).
### Variantes acceptables
`input` sans `submitter` : tout utilisateur ayant le droit de build peut approuver → insuffisant pour une recette.
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| Bouton d'approbation absent | Utilisateur hors `submitter` | Se connecter en `admin` |
| Build bloqué des heures | `timeout` absent | `options { timeout(...) }` sur l'étape |
| Approbation demandée sur une MR ou une branche | `input` évalué avant `when` | `when { beforeInput true; branch 'main' }` (constaté sur le banc) |
| Un exécuteur occupé pendant l'attente | `input` avec agent global | Accepté au banc ; voir défi du module 10 |

## Lab 07.3 ⭐⭐ — Production en blue/green et retour arrière
### Solution
Sorties relevées sur le banc :
```
[deploy] Couleur active : aucune -> deploiement sur blue
[deploy] Image localhost:3000/dev/fretexpress:1.0.8 recuperee
[deploy] Conteneur fretexpress-prod-blue (1.0.8) lance, hote blue.prod.fretexpress.localhost
[fumee] blue.prod.fretexpress.localhost OK (version 1.0.8)
[deploy] Production basculee sur blue
[fumee] fretexpress.localhost OK (version 1.0.8)
```
`prod.yml` après bascule :
```yaml
# Genere par deploy/blue-green.sh - couleur active : blue
http:
  routers:
    fretexpress-prod:
      rule: "Host(`fretexpress.localhost`)"
      entryPoints: [web]
      service: fretexpress-prod-blue@docker
```
### Pourquoi
- Test de fumée AVANT la bascule (couleur inactive) puis APRÈS (production) : une version défaillante n'est jamais exposée.
- Fournisseur de fichiers Traefik surveillé (`--providers.file.watch=true`) : bascule prise en compte en moins d'une seconde, sans redémarrage.
- `currentBuild.description = "deploy-prod ..."` : marquage réutilisé pour mesurer les déploiements (DORA, module 10).
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| `Permission denied` sur `/srv/traefik-dynamic/prod.yml` | Volume créé avant l'agent (propriétaire root) | `docker compose restart agent` (l'entrée corrige les droits) |
| Production `404` après bascule | `prod.yml` mal formé | `docker logs cicd-traefik-1` ; relancer le déploiement |
| Les deux couleurs à la même version | Retour arrière puis nouveau déploiement sur la même couleur | Normal : la couleur inactive est réutilisée |

## Défi 07.4 ⭐⭐⭐ — Canary piloté
### Solution
```bash
docker exec -u jenkins -w /home/jenkins/agent/workspace/fretexpress_main cicd-agent-1 \
    deploy/canary.sh 1.0.<N-1> 10
for i in $(seq 1 100); do curl -s http://fretexpress.localhost/version; echo; done | sort | uniq -c
docker exec -u jenkins -w /home/jenkins/agent/workspace/fretexpress_main cicd-agent-1 \
    deploy/canary.sh --annuler
```
Mesure du banc (poids 30 %, 40 requêtes) : 12 réponses canary / 28 stables.
Proposition de Jenkinsfile :
```groovy
stage('Canary 10 %') {
    when { branch 'main' }
    steps { sh 'deploy/canary.sh "$VERSION" 10' }
}
stage('Validation canary') {
    when { branch 'main' }
    options { timeout(time: 15, unit: 'MINUTES') }
    input { message 'Canary sain : passer a 100 % ?'; ok 'Valider' }
    steps { sh 'deploy/canary.sh --valider' }
}
```
### Pourquoi
Répartition pondérée par requête (round-robin pondéré) : sur un petit échantillon, l'écart au poids peut atteindre quelques points.
### Variantes acceptables
Validation automatique sur métriques (taux d'erreur < seuil pendant 10 min) au lieu d'une approbation : cible des outils dédiés (Argo Rollouts, Flagger).

## Bonus
Surplus de 1 : la capacité ne baisse jamais pendant la mise à jour. Erreur résiduelle possible : requête routée vers une réplique en cours d'arrêt, avant que Traefik ne la retire (banc : 1 réponse vide sur 34 mesurées) ; parade en production : sonde de disponibilité et délai de drainage.

## QCM — Réponses
1. **B** — La même image (même empreinte) est déployée partout.
2. **C** — `submitter` liste les utilisateurs (ou groupes) autorisés.
3. **B** — Apostrophes simples : le shell résout la variable, Groovy n'insère jamais le secret.
4. **B** — Blue/green : l'ancienne couleur tourne encore, rebascule immédiate.
5. **B** — Poids 10 % ≈ une requête sur dix.
6. **B** — `/health` ET la version attendue sur `/version`.
7. **B** — Les deux versions servent le trafic en même temps.
