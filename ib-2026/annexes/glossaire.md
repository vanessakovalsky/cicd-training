# Glossaire

## A
**Agent** : machine ou conteneur qui exécute les étapes des builds pour le contrôleur Jenkins (`agent-python` dans la formation).
**Alias URL** : adresse sous laquelle Gitea s'annonce (`http://localhost:3000`), déclarée dans Jenkins en plus de l'URL de serveur (`http://gitea:3000`) pour reconnaître les webhooks.
**Artefact** : produit livrable d'un build, versionné et immuable (paquet `.whl`, image Docker).
**Audit Trail** : plugin Jenkins qui journalise les actions des utilisateurs (qui, quoi, quand).

## B
**Bibliothèque partagée (shared library)** : dépôt Git de code Groovy chargé par `@Library`, qui fournit des étapes communes à plusieurs Jenkinsfile.
**Blue/green** : stratégie de déploiement à deux environnements de production, dont un seul reçoit le trafic ; bascule et retour arrière instantanés.
**Build** : exécution numérotée d'un job Jenkins.

## C
**Canary** : stratégie de déploiement qui expose une nouvelle version à une fraction du trafic avant généralisation.
**Contrôleur** : serveur Jenkins central (interface, planification, configuration, historique) ; n'exécute aucun build.
**Couverture de branches** : part des issues (vraie, fausse) de chaque condition exécutées par les tests.
**Credential** : secret stocké chiffré par Jenkins et référencé par un identifiant.

## D
**Déploiement continu** : chaque version validée est mise en production automatiquement.
**DORA** : programme de recherche DevOps Research and Assessment ; ses 4 indicateurs : fréquence de déploiement, délai de mise en production, taux d'échec des changements, temps de restauration.
**Doublure de test** : objet qui remplace une dépendance réelle pendant un test (dummy, stub, spy, mock, fake).

## E
**Exécuteur** : emplacement d'exécution d'un build sur un nœud ; nombre de builds simultanés possibles.

## F
**Fake** : doublure dotée d'une implémentation simplifiée mais fonctionnelle (`FournisseurCarburantFixe`).
**Fil rouge** : projet FretExpress, enrichi de module en module.

## G
**Git Flow** : stratégie de branches avec `develop`, `feature/*`, `release/*`, `hotfix/*`.
**GitHub Flow** : stratégie à branche principale toujours déployable, branches courtes et merge requests.

## I
**Idempotence** : propriété d'une action dont le résultat est le même qu'elle soit exécutée une ou plusieurs fois.
**Intégration continue (CI)** : intégration fréquente du code dans la branche principale, vérifiée automatiquement à chaque changement.

## J
**JCasC (Configuration as Code)** : plugin Jenkins qui applique une configuration décrite en YAML.
**Jenkinsfile** : fichier versionné qui décrit le pipeline (syntaxe déclarative ou scriptée).

## L
**Label** : étiquette d'agent utilisée pour choisir où un job s'exécute.
**Livraison continue** : chaque version est déployable à tout moment ; la mise en production reste une décision humaine.

## M
**Merge request (MR) / pull request (PR)** : demande de fusion d'une branche, support de la revue et des vérifications automatiques.
**Mock** : doublure qui vérifie les interactions attendues (appels, arguments).
**Multibranche (pipeline)** : job Jenkins qui crée un pipeline par branche et par merge request du dépôt.

## P
**Pipeline as code** : chaîne CI/CD décrite dans un fichier versionné avec le code.
**Promotion** : déploiement du même artefact d'un environnement au suivant, sans reconstruction.
**Pyramide des tests** : répartition visée : beaucoup de tests unitaires, moins de tests d'intégration, très peu de tests de bout en bout.

## Q
**Quality gate** : ensemble de conditions de qualité (couverture, bugs…) dont le verdict autorise ou bloque le pipeline.

## R
**Rolling update** : remplacement des instances une par une, sans interruption de service.

## S
**Stub** : doublure qui renvoie des réponses préprogrammées.
**Submitter** : liste des utilisateurs autorisés à approuver une étape `input`.

## T
**TDD (Test-Driven Development)** : développement piloté par les tests : test en échec, code minimal, refactorisation.
**Test de fumée** : vérification minimale d'un service juste après son déploiement (`/health`, `/version`).
**Test instable (flaky)** : test dont le résultat varie sans changement de code.
**Trunk-based development** : intégration directe et très fréquente sur la branche principale.

## W
**Webhook** : appel HTTP envoyé par la forge à Jenkins à chaque événement (push, merge request).
**Workspace** : répertoire de travail d'un job sur l'agent.
