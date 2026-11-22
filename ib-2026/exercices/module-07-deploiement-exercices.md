# Module 07 — Exercices

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

---

## Lab 07.3 ⭐⭐ — Production en blue/green et retour arrière (semi-guidé)
**Durée** : 40 min · **Objectif** : mise en production sans interruption, retour arrière en une commande
**Contexte** : la production FretExpress ne doit jamais être interrompue pendant les heures d'ouverture.

### Étapes
1. Ajouter l'étape `Production` après `Recette` :
   ```groovy
   stage('Production') {
       when { branch 'main' }
       steps {
           withCredentials([usernamePassword(credentialsId: 'registre-lecture',
                   usernameVariable: 'REGISTRE_USER', passwordVariable: 'REGISTRE_TOKEN')]) {
               sh 'deploy/blue-green.sh "$VERSION"'
           }
           script { currentBuild.description = "deploy-prod ${env.VERSION}" }
       }
   }
   ```
2. Fusionner, approuver la recette. Résultat attendu (premier déploiement) :
   ```
   [deploy] Couleur active : aucune -> deploiement sur blue
   [fumee] blue.prod.fretexpress.localhost OK (version 1.0.<N>)
   [deploy] Production basculee sur blue
   [fumee] fretexpress.localhost OK (version 1.0.<N>)
   ```
3. Deuxième changement (petit commit via MR) → nouveau build, approbation : déploiement sur `green`, bascule.
4. Pendant le déploiement, dans un terminal : sonder la production chaque demi-seconde.
   ```bash
   while true; do curl -s -o /dev/null -w '%{http_code} ' http://fretexpress.localhost/health; sleep 0.5; done
   ```
   Résultat attendu : uniquement des `200`.
5. Lire le fichier de bascule et identifier la couleur active.
   ```bash
   docker exec cicd-traefik-1 cat /etc/traefik/dynamic/prod.yml
   ```
6. Retour arrière (incident simulé sur la nouvelle version).
   ```bash
   docker exec -u jenkins -w /home/jenkins/agent/workspace/fretexpress_main cicd-agent-1 \
       deploy/blue-green.sh --retour-arriere
   curl -s http://fretexpress.localhost/version
   ```
   Résultat attendu : `[deploy] Production basculee sur blue` puis la version précédente.
7. Rétablir la dernière version (`--retour-arriere` à nouveau).

### Critères de réussite
- [ ] Deux couleurs en service, `prod.yml` pointant sur la plus récente
- [ ] Aucune erreur de sonde pendant la bascule
- [ ] Retour arrière en moins d'une minute, sans rebuild

---

## Défi 07.4 ⭐⭐⭐ — Canary piloté (autonome)
**Durée** : 25 min · **Objectif** : exposer une version à 10 % puis 50 % du trafic, puis décider
**Énoncé** : avec `deploy/canary.sh`, déployer la version précédente (ou une version de test) en canary à 10 %, mesurer la répartition sur 100 requêtes, passer à 50 %, puis annuler. Proposer une modification du Jenkinsfile pour un canary automatique (étape `input` « Valider le canary ? » entre 10 % et 100 %).
**Critères de réussite** :
- [ ] Répartition mesurée cohérente avec le poids (± 10 points)
- [ ] `--annuler` ramène 100 % du trafic sur la version stable
- [ ] Proposition de Jenkinsfile relue en binôme

---

## Bonus 🚀
Lire `scripts/m07/labs/demo-rolling.sh` (démonstration du formateur) : pourquoi la nouvelle réplique est-elle démarrée AVANT l'arrêt de l'ancienne ? Quelle erreur reste possible pendant l'arrêt d'une réplique ?
