# Module 07 — Corrections, bloc 1

Bloc 1 (séquences S7.1, S7.2). Autre bloc : `module-07-deploiement-corrections-2.md`.

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
