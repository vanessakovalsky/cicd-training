# Module 07 — Corrections, bloc 2

Bloc 2 (séquences S7.3). Autre bloc : `module-07-deploiement-corrections-1.md`.

Fichiers de référence : `fil-rouge/solutions/m07/Jenkinsfile` et `fil-rouge/solutions/m07/deploy/`.

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

## Défi 07.5 ⭐⭐⭐ — Variante GitLab CI
### Solution
Fichier complet : `fil-rouge/solutions/m07/.gitlab-ci.yml`. Extrait (approbation et production) :
```yaml
recette:
  extends: .deploiement
  stage: recette
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: manual
  allow_failure: false
  environment: { name: recette, url: "http://recette.fretexpress.localhost" }
  script:
    - deploy/deployer.sh recette "$VERSION"

production:
  extends: .deploiement
  stage: production
  resource_group: production
  environment: { name: production, url: "http://fretexpress.localhost" }
  script:
    - deploy/blue-green.sh "$VERSION"
```
Sorties relevées sur le banc (poste de la salle, GitLab 19.6.1) :
```
[deploy] Image localhost:3000/dev/fretexpress:1.0.1001 recuperee
[deploy] Conteneur fretexpress-int (1.0.1001) lance, hote int.fretexpress.localhost
[fumee] int.fretexpress.localhost OK (version 1.0.1001)
...
[deploy] Couleur active : blue -> deploiement sur green
[deploy] Production basculee sur green
[fumee] fretexpress.localhost OK (version 1.0.1003)
```
Job `retour-arriere` : `[deploy] Production basculee sur blue` en 10 s. Durées : contrôles 25 s, build 44 s, publication 35 s, intégration 20 s.
### Pourquoi
- `when: manual` + `allow_failure: false` : pipeline `blocked` (bloqué) jusqu'au lancement ; avec `allow_failure: true` (défaut des jobs manuels), la production partirait sans recette.
- Qui peut approuver : tout membre autorisé à lancer un pipeline sur `main` (branche protégée). Liste nominative d'approbateurs = environnements protégés et approbations de déploiement (offres Premium et Ultimate) ; `submitter` Jenkins : gratuit.
- Version : `dotenv` transmet `VERSION` à tous les jobs suivants (les jobs ne partagent ni workspace ni variables).
- Variables protégées : absentes des pipelines de branches non protégées (une MR ne peut pas lire le jeton).
- **Prevent outdated deployment jobs** (activé par défaut) : le bouton ▶ d'un job de déploiement est grisé si un pipeline plus récent a déjà déployé (aucun retour involontaire à une version ancienne).
- Retour arrière : job manuel `retour-arriere` (bascule instantanée) ou **Environments** › **Rollback** (relance le déploiement précédent : image re-téléchargée, plus lent).
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| Job en échec immédiat : `JENKINS_AGENT_SSH_PUBKEY absente` | Entrypoint SSH de l'image de l'agent exécuté | `entrypoint: [""]` dans `image:` |
| Bouton ▶ grisé, `older than the latest deployment` | Pipeline plus ancien que le dernier déploiement (Prevent outdated deployment jobs) | Lancer le pipeline le plus récent ; retour arrière : job `retour-arriere` |
| `retour-arriere` : `Couleur green absente` | Premier déploiement : une seule couleur en service | Normal ; tester après un 2e déploiement |
| `[deploy]` : `pull access denied` | Variables protégées sur une branche non protégée | Déployer depuis `main` uniquement |
| `VERSION` vide dans `build` | Artefact `dotenv` non téléchargé | Job `version` dans un stage antérieur, ou `needs: [version]` |
| `twine upload` refusé (version existante) | Version déjà publiée (relance d'un pipeline) | Nouveau pipeline (nouveau numéro) ; pas de `retry` sur la publication |
| `fatal: unable to access 'http://localhost:8929/...'` dans un job | Clonage par l'URL externe | Runner enregistré avec `--clone-url http://gitlab:8929` (`init-gitlab.sh`) |

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
