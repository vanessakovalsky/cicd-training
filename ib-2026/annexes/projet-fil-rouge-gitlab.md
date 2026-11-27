# Projet fil rouge — TP03, TP13, TP04 sur GitLab CI

Session ib du 23 au 27/11/2026, J5 après-midi. Fiches d'orientation : objectifs, correspondances, indices progressifs, points de contrôle. Aucune solution complète.

## Contexte
- Application = Hipster Shop / Online Boutique : sources `application/` du kit fil rouge du parcours (non fournies ici).
- Outils cibles en entreprise = GitLab + SonarQube (pas de Jenkins) → TP réalisés sur GitLab CI.
- Banc = poste de formation :

| Brique | Adresse | Équivalent en entreprise |
|---|---|---|
| GitLab CE + runner (exécuteur Docker) | http://localhost:8929 (utilisateur `dev`, mot de passe `GITEA_DEV_PASSWORD` de `environnement/.env`) | GitLab du groupe, runners partagés |
| SonarQube | http://localhost:9000 ; depuis un job : `http://sonarqube:9000` | SonarQube du groupe |
| Registre d'images | Gitea : `localhost:3000/dev/<image>` | Registre GitLab : `$CI_REGISTRY_IMAGE` |

Écart à documenter dans le README : registre GitLab désactivé sur le banc → images poussées dans le registre Gitea.

## Correspondance Jenkins → GitLab CI
| Notion vue en formation (Jenkins) | GitLab CI |
|---|---|
| `Jenkinsfile` | `.gitlab-ci.yml` à la racine du dépôt |
| `stage('...')` | `stages:` + un job par tâche (`stage:`) |
| `agent { label 'python' }` | `image:` du job (un conteneur par job) |
| `parallel` | jobs d'un même stage ; `needs:` |
| `matrix` | `parallel: matrix:` |
| `withCredentials` | variables CI/CD masquées (**Settings** › **CI/CD** › **Variables**) |
| `junit`, `recordCoverage` | `artifacts: reports: junit`, `coverage_report` (cobertura), `coverage:` |
| `withSonarQubeEnv` + `waitForQualityGate` | `sonar-scanner ... -Dsonar.qualitygate.wait=true` |
| `when { changeset ... }` | `rules: - changes: [...]` |
| `env.BUILD_NUMBER` | `$CI_PIPELINE_IID` |

Exemples complets dans le paquet : `fil-rouge/solutions/m07/.gitlab-ci.yml` et `fil-rouge/solutions/m08/.gitlab-ci.yml` (FretExpress).

## Démarrage (11:50, 30 min)
1. GitLab prêt : `scripts/setup/gitlab/init-gitlab.sh` (lancé à 09:00) → dernière ligne `GitLab : http://localhost:8929 - utilisateur dev ...`.
2. Dépôt : copie de `application/` dans `~/hipster-shop`, puis `git init -b main`, commit, `git push` vers `http://localhost:8929/dev/hipster-shop.git` (le premier push crée le projet privé).
3. Variables CI/CD du projet, AVANT le premier pipeline utile : `SONAR_HOST_URL`, `SONAR_TOKEN` (masquée), `REGISTRE_TOKEN` (masquée, jeton Gitea `dev` avec **package : écriture**).
4. Premier job « bonjour » (versions de `python3`, `docker`, `sonar-scanner`) → pipeline vert = runner opérationnel.

Point de contrôle 12:20 : pipeline vert dans **Build** › **Pipelines**.

Image par défaut du runner = image de l'agent Jenkins de la formation (Python 3.12, client Docker, `sonar-scanner`). Son point d'entrée lance un serveur SSH → à neutraliser :
```yaml
default:
  image:
    name: cicd-formation/agent-python:local
    entrypoint: [""]
```

### Erreurs fréquentes (constatées le 27/11)
| Symptôme | Cause | Déblocage |
|---|---|---|
| `JENKINS_AGENT_SSH_PUBKEY absente`, job en échec immédiat | Point d'entrée SSH de l'image de l'agent ; une `image:` d'une seule ligne dans un job remplace celle de `default:` | `entrypoint: [""]` (forme longue de `image:`) dans `default:` ET dans tout job qui redéfinit l'image |
| `... does not appear to be a Python project: neither 'setup.py' nor 'pyproject.toml' found` | `pip install -e .` à la racine (`before_script` recopié de FretExpress) ; Hipster Shop = un `requirements.txt` par service | `before_script: []` ; `cd src/<service>` puis `pip install -r requirements.txt` ; chemins des rapports préfixés par `src/<service>/` |
| Pipeline avec des jobs `code_quality`, `secret_detection`, `container_scanning` jamais écrits | Auto DevOps : push sans `.gitlab-ci.yml` | **Settings** › **CI/CD** › **Auto DevOps** : décocher ; annuler le pipeline ; pousser le `.gitlab-ci.yml` dès le premier commit |
| Jobs d'un même stage exécutés l'un après l'autre, longtemps `pending` | Runner à `concurrent = 1` (avant correctif de `init-gitlab.sh`) | `docker exec cicd-gitlab-runner-1 sed -i 's/^concurrent = .*/concurrent = 4/' /etc/gitlab-runner/config.toml` (relu automatiquement) |
| Variable vide dans un job de branche | Variable **Protected** : branches protégées seulement (`main`) | Décocher **Protected** pour `SONAR_TOKEN` ; garder **Masked** |

## Périmètre conseillé
- Service principal : `recommendationservice` (Python, logique testable, pas de base de données).
- Extension : `emailservice` (Python) ; `shippingservice` ou `productcatalogservice` (Go, image `golang`).
- Un service de bout en bout > plusieurs services à moitié.

---

## TP03 — Pipeline CI/CD (13:30, 45 min)
**Objectif** : build → test → package → push automatisés pour un service.
**Attendu** : `.gitlab-ci.yml` ; image `localhost:3000/dev/hipster-<service>:1.0.<n>` visible dans Gitea (**dev** › **Packages**).

### Étapes
1. Dockerfile du service (repris du TP02 s'il existe).
2. Stages `tests`, `qualite` (TP04), `build`.
3. Job `build` : version, `docker build`, connexion au registre, `docker push`, déconnexion.
4. Lancement de l'image produite = preuve de fonctionnement.

### Indices
- **Indice 1** : socket Docker de l'hôte monté dans les jobs → `docker build` et `docker push` directs, sans Docker-in-Docker.
- **Indice 2** : `pip install -r requirements.txt` en échec → lire la première erreur. `google-cloud-profiler==4.1.0` = aucun paquet précompilé pour Python 3.12 → compilation C++ obligatoire. Image `python:3.12-slim` = pas de compilateur.
- **Indice 3** : Dockerfile en deux étapes (multi-stage) : étape de construction avec `g++` (installation des dépendances), étape finale `slim` qui ne copie que le résultat.
- **Indice 4** : au démarrage, `No module named 'pkg_resources'` → ancienne version d'OpenTelemetry. `setuptools` absent des images Python récentes : l'ajouter explicitement (`"setuptools<81"`).
- **Indice 5** : connexion au registre sans afficher le jeton : `--password-stdin` ; version = `1.0.$CI_PIPELINE_IID`.
- **Indice 6** : lancement de l'image → lire l'exception : une variable d'environnement d'adresse est obligatoire.

### Critères de réussite
- [ ] Pipeline déclenché par un push, sans action manuelle
- [ ] Image versionnée dans le registre ; une version par pipeline
- [ ] Aucun secret en clair dans `.gitlab-ci.yml` ni dans le journal du job
- [ ] Conteneur démarré : journal `listening on port: 8080`

---

## TP13 — Tests automatisés (14:15, 60 min)
**Objectif** : tests obligatoires dans la CI ; rapport de tests et couverture visibles dans GitLab.
**Attendu** : dossier `tests/` du service ; job `tests` bloquant ; onglet **Tests** du pipeline renseigné.

### Quoi tester (`ListRecommendations`)
- Produits déjà dans le panier → jamais recommandés
- Catalogue de 10 produits → 5 recommandations au plus, sans doublon
- Panier = tout le catalogue → aucune recommandation

### Indices
- **Indice 1** : job `tests` dans une image capable de compiler les dépendances (`python:3.12`, pas `slim`) ; mêmes dépendances que l'image (indices 2 et 4 du TP03) + `pytest`, `pytest-cov`.
- **Indice 2** : import de `recommendation_server` depuis `tests/` → chemin d'import à régler (`conftest.py` ou `PYTHONPATH`).
- **Indice 3** : catalogue = appel gRPC à `productcatalogservice` → à remplacer par un faux catalogue (objet avec une méthode `ListProducts` qui renvoie un `demo_pb2.ListProductsResponse`).
- **Indice 4** : `product_catalog_stub` n'existe qu'au lancement du serveur (bloc `if __name__ == "__main__"`) → `monkeypatch.setattr(..., raising=False)`.
- **Indice 5** : choix aléatoire (`random.sample`) → tester des propriétés (taille, exclusion), jamais un ordre précis.
- **Indice 6** : rapports GitLab = `artifacts: when: always` + `reports: junit` + `coverage_report` (format `cobertura`) ; pourcentage du pipeline = mot-clé `coverage:` (expression régulière sur la ligne `TOTAL`).

### Critères de réussite
- [ ] Au moins 3 tests verts ; onglet **Tests** du pipeline renseigné
- [ ] Couverture affichée sur le job et dans la merge request
- [ ] Test cassé volontairement (branche + merge request) → pipeline rouge, job `build` non exécuté

---

## TP04 — Qualité de code (15:30, 45 min)
**Objectif** : analyse SonarQube de chaque service ; pipeline bloqué si la quality gate échoue.
**Attendu** : job `sonarqube` entre `tests` et `build` ; quality gate propre au projet, seuils justifiés.

### Étapes
1. Jeton d'analyse SonarQube (avatar › **My Account** › **Security** › **Generate Tokens**, type **Global Analysis Token**, comme au lab 06.1) → variable masquée `SONAR_TOKEN`.
2. Job d'analyse : clé de projet par service (`hipster-<service>`), rapport de couverture du TP13 transmis.
3. Blocage : job en échec si la gate échoue.
4. Seuils : quality gate dédiée, associée au projet SonarQube.

### Indices
- **Indice 1** : `sonar-scanner` déjà présent dans l'image par défaut du runner ; paramètres en `-D...` ou dans `sonar-project.properties` du service.
- **Indice 2** : code généré (`demo_pb2*.py`) et tests = hors périmètre analysé (`sonar.exclusions`, `sonar.tests`).
- **Indice 3** : couverture = artefact du job `tests` (`needs: [tests]`) → `sonar.python.coverage.reportPaths`.
- **Indice 4** : pas de webhook comme avec Jenkins : `-Dsonar.qualitygate.wait=true` → le scanner attend le verdict, code de sortie non nul si `FAILED`.
- **Indice 5** : gate par défaut du banc = `FretExpress` (couverture ≥ 80 %, aucun bug) → premier verdict attendu `FAILED` (banc : 42 %). Décision à argumenter : plus de tests OU gate dédiée (seuil sur le **nouveau code** ?).
- **Indice 6** (extension) : plusieurs services → `parallel: matrix: - SERVICE: [...]` ; `rules: changes:` pour n'analyser que le service modifié.

### Critères de réussite
- [ ] Projet `hipster-<service>` visible dans SonarQube, couverture importée (≠ 0 %)
- [ ] Gate en échec → job `sonarqube` rouge → `build` non exécuté
- [ ] Gate dédiée, seuils justifiés dans le README

---

## Restitution (16:15, 5 min par personne)
`README.md` par TP (convention du kit fil rouge) :
```text
Contexte · Objectif · Prérequis · Commandes exécutées · Résultat obtenu · Problèmes rencontrés · Améliorations possibles
```
- Preuves : capture du pipeline, onglet **Tests**, verdict SonarQube, image dans le registre.
- Écarts banc / entreprise : registre, URL SonarQube, runners, variables protégées.
- Questions de réflexion des TP : problème réel résolu, gain (délai, fiabilité, maintenabilité), risques restants, contexte réglementé.
