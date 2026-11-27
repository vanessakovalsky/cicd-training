# Module 08 — Corrections, bloc 2

Bloc 2 (séquences S8.3, S8.4). Autre bloc : `module-08-optimisation-corrections-1.md`.

Fichiers de référence : `fil-rouge/solutions/m08/Jenkinsfile`, bibliothèque `fil-rouge/fretexpress-pipeline-lib/` (tag `v1`).

## Lab 08.3 ⭐⭐ — Factoriser dans une bibliothèque partagée
### Solution
Équivalent JCasC (rattrapage `scripts/m08/catch-up/bibliotheque.yaml`) :
```yaml
unclassified:
  globalLibraries:
    libraries:
      - name: fretexpress-lib
        defaultVersion: v1
        implicit: false
        allowVersionOverride: true
        retriever:
          modernSCM:
            scm:
              git:
                remote: http://gitea:3000/dev/fretexpress-pipeline-lib.git
                credentialsId: gitea-dev
```
Jenkinsfile : `fil-rouge/solutions/m08/Jenkinsfile` (`@Library('fretexpress-lib@v1') _`, `pythonInstall()`, `fretexpressVersion()`, `deployer(...)`, `notifierEquipe(...)`). Console : `Loading library fretexpress-lib@v1`. Build `main` relevé sur le banc : `SUCCESS`, description `deploy-prod 1.0.10`.
Correspondance : `pythonInstall` → étape `Installation` ; `fretexpressVersion` → étape `Version` ; `deployer` → 3 étapes de déploiement (avec `withCredentials` et `retry`) ; `notifierEquipe` → `mail` de `post`.
### Pourquoi
- Bibliothèque « trusted » : code hors bac à sable (accès à `currentBuild`, `env`) ; d'où le dépôt protégé et la revue.
- `retry(2)` dans `deployer` : déploiement idempotent (même version, même couleur cible).
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| `No such library resource` / `Library fretexpress-lib not found` | Nom ou déclaration absente | **Global Trusted Pipeline Libraries**, nom exact |
| `couldn't find remote ref v1` | Tag non poussé | `git push origin v1` |
| `No signature of method: ... pythonInstall()` | `_` oublié après `@Library(...)` | `@Library('fretexpress-lib@v1') _` |
| Changement de bibliothèque sans effet | Tag `v1` figé | Nouveau tag, ou `@Library('fretexpress-lib@main')` pour tester |

## Exercice 08.4 ⭐ — Fiabiliser et mesurer le gain
### Solution
- `retry(2)` : autour de `docker push` (étape `Publication`) et dans `deployer` ; jamais autour de `twine upload` (`409 Conflict` au second essai, version déjà publiée — constaté sur le banc avec `--skip-existing` non supporté par Gitea).
- `timeout` : global (30 min), recette (30 min), quality gate (5 min).
- Tableau (banc) : durée 59-67 s → 68-70 s (contrôles en plus, audit compris) ; Jenkinsfile 162 → 145 lignes (déploiements, version et notifications appelés en une ligne) ; 0 → 4 branches parallèles.

## Défi 08.5 ⭐⭐⭐ — Faire évoluer la bibliothèque
### Solution
```groovy
// vars/notifierEquipe.groovy (branche feat/notif-statut)
def call(String etat, String destinataires = 'equipe@fretexpress.localhost') {
    def sujet = (etat == 'fixed') ? 'REPARE' : 'ECHEC'
    mail to: destinataires,
         subject: "${sujet} ${env.JOB_NAME} #${env.BUILD_NUMBER}",
         body: "${sujet} en ${currentBuild.durationString} : ${env.BUILD_URL}console"
}
```
Test : `@Library('fretexpress-lib@feat/notif-statut') _` sur une branche de `fretexpress` (autorisé par **Allow default version to be overridden**) ; puis `git tag -a v2` ; migration par MR.

## Défi 08.6 ⭐⭐⭐ — Variante GitLab CI
### Solution
Fichiers : `fil-rouge/solutions/m08/.gitlab-ci.yml` et `fil-rouge/fretexpress-ci-lib/`. Extrait (matrice et fusion de couverture) :
```yaml
tests:
  extends: .python
  stage: controles
  needs: []
  parallel:
    matrix:
      - SUITE: [unit, integration]
  script:
    - if [ "$SUITE" = unit ]; then MARQUEUR="not integration"; else MARQUEUR=integration; fi
    - COVERAGE_FILE=.coverage.$SUITE pytest -m "$MARQUEUR" --junitxml=reports/junit-$SUITE.xml
      --cov=fretexpress --cov-branch --cov-report=
  artifacts:
    when: always
    paths: [".coverage.*"]
    reports:
      junit: reports/junit-*.xml

couverture:
  extends: .python
  stage: controles
  needs: [tests]
  script:
    - coverage combine .coverage.unit .coverage.integration
    - coverage xml -o reports/coverage.xml
```
### Pourquoi
- Jobs d'un même stage : parallèles par défaut (Jenkins : `parallel` explicite). Chaque job = conteneur neuf : installation répétée par job, d'où l'intérêt du cache.
- `cache:` GitLab : archive sauvegardée par le runner (volume `/cache`) et restaurée au job suivant ; chemin obligatoirement DANS le projet (`$CI_PROJECT_DIR/.cache/pip`).
- Mesures du banc : poste local lent, job `lint` 104 s cache froid → 68 s cache chaud (`Successfully extracted cache`) ; poste de la salle, contrôles en parallèle 23 à 29 s chacun, pipeline complet jusqu'à la production en 4 min (hors approbation).
- `include: project` + `ref: v1` : version figée comme `@Library('...@v1')` ; une branche de `fretexpress-ci-lib` se teste avec `ref: <branche>`.
- `interruptible: true` : un nouveau commit annule le pipeline obsolète ; jamais sur publication ni déploiement (état intermédiaire).
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| `Project 'dev/fretexpress-ci-lib' not found or access denied` | Projet privé d'un autre utilisateur, ou tag absent | Même propriétaire (`dev`) ; `git push origin v1` |
| `No such file: .coverage.unit` dans `couverture` | Artefacts de la matrice non transmis | `needs: [tests]` + `paths: [".coverage.*"]` |
| Aucun gain de cache | `PIP_CACHE_DIR` hors du projet | Chemin sous `$CI_PROJECT_DIR` |
| Cache froid sur `main` alors qu'il est chaud sur la branche | Caches séparés branches protégées / non protégées (clé suffixée `-protected`) | Normal : premier pipeline de `main` sans cache |

## Bonus
Coût : chaque étape sur un nouvel agent reclone le dépôt et réinstalle les dépendances (≈ 30 s) ; gain : exécuteur libéré pendant l'attente d'approbation (jusqu'à 30 min). Rentable dès qu'une attente humaine existe (défi 10.3).

## QCM — Réponses
1. **B** — La durée de l'étape parallèle est celle de la branche la plus longue.
2. **B** — Un fichier de mesure par processus, fusionnés ensuite.
3. **B** — `branch 'main'`.
4. **B** — `vars/deployer.groovy` avec `call()`.
5. **B** — Version figée : reproductibilité et maîtrise des évolutions.
6. **B** — Push d'une version : idempotent, erreurs réseau passagères.
7. **B** — Le cache de `~/.cache` disparaît avec le conteneur.
