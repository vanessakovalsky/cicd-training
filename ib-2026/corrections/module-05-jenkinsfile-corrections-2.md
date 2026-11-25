# Module 05 — Corrections, bloc 2

Bloc 2 (séquences S5.3, S5.4). Autre bloc : `module-05-jenkinsfile-corrections-1.md`.

Jenkinsfile de référence : `fil-rouge/solutions/m05/Jenkinsfile`.

## Lab 05.2 ⭐ — Multibranche, webhook et statut de MR
### Solution
Équivalent automatisé : `scripts/m05/catch-up/catch-up.sh` (jeton, credential, serveur Gitea en JCasC, job multibranche par script Groovy, webhook par l'API Gitea). Extrait JCasC :
```yaml
unclassified:
  giteaServers:
    servers:
      - displayName: gitea
        serverUrl: http://gitea:3000
        aliasUrl: http://localhost:3000
        manageHooks: false
```
Statuts publiés (relevés sur le banc) : `fretexpress/pipeline/head` (branches), `fretexpress/pipeline/pr-main` (MR vers `main`).
### Pourquoi
- `manageHooks: false` : Jenkins créerait un webhook vers son URL publique `http://localhost:8080`, injoignable depuis le conteneur Gitea ; webhook créé à la main vers `http://jenkins:8080`.
- Comportement « Discover branches » par défaut : une branche ayant une MR n'est construite qu'une fois (job `PR-<N>`), pas deux.
- Motif `fretexpress/pipeline/pr-*` : couvre toute MR, quelle que soit la branche cible.
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| Webhook `200` mais aucun build | Alias URL absente | Étape 3 |
| Webhook en erreur `dial tcp ... connection refused` | URL `localhost:8080` dans le webhook | `http://jenkins:8080/gitea-webhook/post` |
| Webhook refusé `webhook can only call allowed HTTP servers` | Liste d'hôtes autorisés de Gitea | Déjà ouvert sur le banc (`GITEA__webhook__ALLOWED_HOST_LIST`) |
| Liste **Repository** vide à l'étape 4 | Jeton sans `organization : Lecture`, ou credential / Owner non renseigné | Nouveau jeton avec le droit ; `gitea-dev` › **Update credential** › **Change Password** (sinon ancien jeton conservé) ; ressaisir l'Owner |
| Job sans webhook, sans `PR-<N>` ni statut | Source **Git** choisie au lieu de **Gitea** | Configure › Branch Sources › source **Gitea** |
| Statut absent sur la MR, console `HTTP 401/Unauthorized` | Jeton sans droit d'écriture sur le dépôt | Nouveau jeton (repository : écriture) |
| Scan : `Does not meet criteria` pour `main` | Pas encore de Jenkinsfile sur `main` | Normal avant la fusion de la MR |

## Exercice 05.3 ⭐⭐ — Déclencheurs complémentaires
### Solution
```groovy
pipeline {
    agent { label 'python' }
    triggers {
        cron(env.BRANCH_NAME == 'main' ? 'H 2 * * *' : '')
    }
    // options, stages, post inchangés
}
```
### Pourquoi
- Les déclencheurs d'un job multibranche sont lus dans le Jenkinsfile de la branche, après un premier build.
- `pollSCM` en plus du webhook : requêtes inutiles toutes les N minutes ; la scrutation périodique du multibranche (1 h) suffit comme filet.
### Variantes acceptables
`triggers { cron('H 2 * * *') }` dans un Jenkinsfile spécifique à `main` : refusé (divergence de Jenkinsfile entre branches).

## Bonus
Webhook : build lancé en 1 à 3 s. Scrutation `H/5` : jusqu'à 5 min d'attente, et une requête Git toutes les 5 min même sans changement.

## QCM — Réponses
1. **B** — `pipeline { }` ; `node { }` est la racine du pipeline scripté.
2. **C** — `fixed` : build réussi après un build en échec ou instable.
3. **B** — Chaque étape `sh` démarre un shell neuf.
4. **C** — Le webhook pousse l'événement immédiatement, sans requête répétée.
5. **B** — Un job `PR-<N>` par merge request découverte.
6. **B** — URL annoncée ≠ URL du serveur : déclarer l'Alias URL.
