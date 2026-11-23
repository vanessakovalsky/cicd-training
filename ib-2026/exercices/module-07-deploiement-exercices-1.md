# Module 07 — Exercices, bloc 1

Bloc 1 : séquences S7.1, S7.2. Bloc 2 : `module-07-deploiement-exercices-2.md`.

Point de départ : état fin M06 (image `1.0.<N>` publiée par `main`). Retard : `scripts/m06/catch-up/catch-up.sh`.
URL des applications : `http://<hote>.fretexpress.localhost` (port 80) ; VM cloud ou `TRAEFIK_PORT` : ajouter `:8000` (ou le port choisi).

## Lab 07.1 ⭐ — Déployer automatiquement en intégration (guidé)
**Durée** : 40 min · **Objectif** : chaque build de `main` déploie l'image publiée en intégration et la vérifie
**Contexte** : l'équipe de recette veut toujours disposer de la dernière version de `main`, sans demander à personne.

### Étapes
1. Branche `cd/integration`. Copier les scripts de déploiement fournis et les lire.
   ```bash
   cd ~/fretexpress && git switch main && git pull && git switch -c cd/integration
   cp -r <FORMATION>/fil-rouge/solutions/m07/deploy .
   ls deploy
   ```
   Résultat attendu : `blue-green.sh  canary.sh  commun.sh  deployer.sh  test-fumee.sh`
   Questions de lecture : quelle commande récupère l'image ? quels labels Traefik sont posés ? que vérifie `test-fumee.sh` ?
2. Jeton de déploiement à droits minimaux : Gitea (`dev`) › **Paramètres** › **Applications** › nouveau jeton `deploiement`, permission **package : Lecture** uniquement.
3. Credential Jenkins **Username with password** : ID `registre-lecture`, Username `dev`, Password = jeton `deploiement`.
4. Ajouter après `Publication` :
   ```groovy
   stage('Deploiement integration') {
       when { branch 'main' }
       steps {
           withCredentials([usernamePassword(credentialsId: 'registre-lecture',
                   usernameVariable: 'REGISTRE_USER', passwordVariable: 'REGISTRE_TOKEN')]) {
               sh 'deploy/deployer.sh int "$VERSION"'
           }
       }
   }
   ```
5. Commit, MR (le build `PR-<N>` saute l'étape : `Stage "Deploiement integration" skipped due to when conditional`), revue, fusion.
6. Build `main` : résultat attendu (console) :
   ```
   [deploy] Image localhost:3000/dev/fretexpress:1.0.<N> recuperee
   [deploy] Conteneur fretexpress-int (1.0.<N>) lance, hote int.fretexpress.localhost
   [fumee] int.fretexpress.localhost OK (version 1.0.<N>)
   ```
7. Vérifier depuis le poste.
   ```bash
   curl -s http://int.fretexpress.localhost/version
   curl -s -X POST http://int.fretexpress.localhost/devis -H 'Content-Type: application/json' \
        -d '{"poids_kg": 2, "zone": "UE"}'
   ```
   Résultat attendu : `{"version":"1.0.<N>"}` puis `{"numero":"D-0001","montant":"11.21"}` (taux carburant par défaut 15 % : `9,75 × 1,15 = 11,2125 → 11,21`).
8. Tableau de bord Traefik (http://localhost:8090) : routeur `fretexpress-int@docker`.

### Critères de réussite
- [ ] Conteneur `fretexpress-int` à la version du dernier build de `main`
- [ ] Étape sautée sur les MR, exécutée sur `main`
- [ ] Jeton de déploiement en lecture seule (aucun droit d'écriture)

---

## Exercice 07.2 ⭐⭐ — Approbation avant recette et secrets protégés (semi-autonome)
**Durée** : 40 min · **Objectif** : recette déployée seulement après approbation ; aucun secret exposé
**Énoncé** :
1. Ajouter l'étape `Recette` (slide « L'approbation dans le pipeline ») : `when { beforeInput true; branch 'main' }`, `submitter 'admin,recette1'` (l'utilisateur `recette1` sera créé au module 09), `timeout` de 30 min, même credential que l'intégration. Vérifier sur la MR que l'étape est sautée SANS demande d'approbation.
2. Fusionner ; approuver dans Jenkins ; vérifier http://recette.fretexpress.localhost/version.
3. Sur une branche de test (jamais fusionnée), étape temporaire :
   ```groovy
   withCredentials([usernamePassword(credentialsId: 'registre-lecture',
           usernameVariable: 'U', passwordVariable: 'P')]) {
       sh 'echo "jeton : $P"'
       sh "echo jeton : ${P}"
   }
   ```
   Lire la console : que montre chaque ligne ? quel avertissement Jenkins affiche-t-il ?
4. Tester le refus : laisser expirer une approbation (timeout réduit à 1 min sur la branche de test) ; observer le statut du build.
**Indices** : la console masque les valeurs connues des secrets ; le problème des guillemets doubles est l'insertion du secret dans le texte du script.
**Critères de réussite** :
- [ ] Recette déployée après approbation, à la même version que l'intégration
- [ ] Explication écrite de l'avertissement d'interpolation Groovy
- [ ] Comportement à l'expiration décrit (statut `ABORTED`)
