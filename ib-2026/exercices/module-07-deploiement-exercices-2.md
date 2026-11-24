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

## Défi 07.5 ⭐⭐⭐ — Variante GitLab CI : la même chaîne de livraison (autonome)
**Durée** : 45 min (après le lab 07.3) · **Objectif** : chaîne `main` → intégration → recette (manuelle) → production blue/green, décrite en `.gitlab-ci.yml` et exécutée par un runner GitLab
**Contexte** : une filiale de FretExpress utilise GitLab ; la même chaîne doit y tourner, avec les MÊMES scripts `deploy/` et le même registre.
**Prérequis** : GitLab démarré sur le poste (4 min au premier lancement sur un poste de la salle) :
```bash
<FORMATION>/scripts/setup/gitlab/init-gitlab.sh
```
Résultat attendu (fin, 4 min sur un poste de la salle) : `Runner : online` puis `GitLab : http://localhost:8929 - utilisateur dev ...`. Connexion : `dev`, mot de passe `GITEA_DEV_PASSWORD` de `environnement/.env`.

### Équivalences
| Jenkins | GitLab CI |
|---|---|
| `Jenkinsfile`, `stage` | `.gitlab-ci.yml`, `stages:` + jobs |
| Agent `python` (SSH) | Runner, exécuteur `docker`, image de l'agent |
| `when { branch 'main' }` | `rules: - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH` |
| `input` + `submitter` | Job `when: manual` + `allow_failure: false` (pipeline « bloqué ») |
| Credential + `withCredentials` | Variable CI/CD masquée et protégée |
| `env.VERSION` | Artefact `dotenv` (variable transmise aux jobs suivants) |
| `currentBuild.description` | Environnements GitLab (**Operate** › **Environments**) |

### Étapes clés
1. Pousser le dépôt vers GitLab (second dépôt distant, Gitea reste l'origine) :
   ```bash
   cd ~/fretexpress && git switch main && git pull
   git remote add gitlab http://localhost:8929/dev/fretexpress.git
   git push gitlab main
   ```
   Aucun pipeline : pas encore de `.gitlab-ci.yml`.
2. GitLab › projet `dev/fretexpress` › **Settings** › **CI/CD** › **Variables** : `GITEA_USER` (`dev`), `GITEA_TOKEN` (nouveau jeton Gitea, permission **package : Lecture et écriture**), `REGISTRE_USER` (`dev`), `REGISTRE_TOKEN` (jeton `deploiement` du lab 07.1). Jetons : **Masked** et **Protected**.
3. Branche `ci/gitlab`, fichier `.gitlab-ci.yml`. Point de départ imposé (image de l'agent, version calculée une seule fois) :
   ```yaml
   default:
     image:
       name: cicd-formation/agent-python:local
       entrypoint: [""]
     before_script:
       - python3 -m venv .venv && . .venv/bin/activate
       - pip install --quiet -e ".[dev]"

   stages: [preparation, controles, build, publication, integration, recette, production]

   version:
     stage: preparation
     before_script: []
     script:
       - BASE=$(python3 -c "import tomllib; print(tomllib.load(open('pyproject.toml','rb'))['project']['version'])")
       - echo "VERSION=${BASE%.*}.$((1000 + CI_PIPELINE_IID))" | tee version.env
     artifacts:
       reports:
         dotenv: version.env
   ```
   (`1000 +` : aucune collision avec les versions publiées par Jenkins dans le même registre)
4. Écrire les autres jobs à partir du Jenkinsfile et du tableau : `analyse-statique` et `tests` (rapports `junit`, couverture `cobertura`), `build`, `publication` (sur `main`), `deploiement-integration`, `recette` (manuel), `production` (`deploy/blue-green.sh`), `retour-arriere` (manuel). Jobs de déploiement : `environment:` avec nom et URL.
5. Pousser `ci/gitlab`, ouvrir une MR dans GitLab : pipeline de MR limité aux contrôles et au build. Fusionner.
6. Pipeline `main` : intégration déployée, pipeline **bloqué** sur `recette` ; lancer la recette (▶), puis la production. Résultat attendu (job `production`) :
   ```
   [deploy] Couleur active : <couleur> -> deploiement sur <autre couleur>
   [deploy] Production basculee sur <autre couleur>
   [fumee] fretexpress.localhost OK (version 1.0.10<NN>)
   ```
   (bouton ▶ grisé sur un pipeline plus ancien qu'un déploiement déjà fait : normal, voir les corrections)
7. **Operate** › **Environments** : 3 environnements et leur version ; lancer `retour-arriere`, vérifier `curl -s http://fretexpress.localhost/version`.

### Critères de réussite
- [ ] Pipeline de MR sans publication ni déploiement ; pipeline `main` jusqu'à la production
- [ ] Aucun jeton en clair dans `.gitlab-ci.yml` ni dans les journaux (`[MASKED]`)
- [ ] Différences Jenkins / GitLab relevées : approbation, secrets, transmission de la version, retour arrière

⚠️ Mêmes conteneurs que la chaîne Jenkins (`fretexpress-int`, `-recette`, `-prod-*`) : la dernière chaîne qui déploie fixe la version en service.

---

## Bonus 🚀
Lire `scripts/m07/labs/demo-rolling.sh` (démonstration du formateur) : pourquoi la nouvelle réplique est-elle démarrée AVANT l'arrêt de l'ancienne ? Quelle erreur reste possible pendant l'arrêt d'une réplique ?
