# Module 07 — Exercices, bloc 2

Bloc 2 : séquences S7.3. Point de départ : labs du bloc 1 terminés (`module-07-deploiement-exercices-1.md`).
URL des applications : `http://<hote>.fretexpress.localhost` (port 80) ; VM cloud ou `TRAEFIK_PORT` : ajouter `:8000` (ou le port choisi).

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
