# Aide-mémoire CI/CD : Jenkins, Git, TDD

## Git au quotidien
| Besoin | Commande |
|---|---|
| Nouvelle branche | `git switch -c feat/<sujet>` |
| État, historique | `git status` · `git log --oneline --graph --all` |
| Se mettre à jour sur sa branche | `git pull --rebase origin main` |
| Conflit résolu pendant un rebase | `git add <fichier>` puis `git rebase --continue` (ou `--abort`) |
| Republier une branche réécrite | `git push --force-with-lease` |
| Message de commit | `type(portee): resume` — `feat`, `fix`, `test`, `refactor`, `docs`, `ci`, `chore` |

## TDD et pytest
`RED (test en échec) → GREEN (code minimal) → REFACTOR (tests au vert)`

| Besoin | Commande / code |
|---|---|
| Tests, arrêt au 1er échec | `pytest -x` · détail : `pytest -v` · filtre : `pytest -k zone` |
| Couverture de branches | `pytest --cov=fretexpress --cov-branch --cov-report=term-missing` |
| Seuil | `--cov-fail-under=90` |
| Rejouer un ordre aléatoire | `pytest --randomly-seed=<graine>` · désactiver : `-p no:randomly` |
| Exception attendue | `with pytest.raises(PoidsInvalide): ...` |
| Mock | `m = Mock(); m.taux_actuel.return_value = Decimal("0")` · `m.taux_actuel.assert_called_once_with()` |
| Dépendance FastAPI en test | `app.dependency_overrides[get_depot] = lambda: depot` |

## Jenkinsfile déclaratif
```groovy
@Library('fretexpress-lib@v1') _
pipeline {
    agent { label 'python' }
    options { timestamps(); timeout(time: 30, unit: 'MINUTES'); disableConcurrentBuilds() }
    environment { IMAGE = 'localhost:3000/dev/fretexpress' }
    stages {
        stage('Controles') { parallel { stage('Lint') { steps { sh '...' } } /* ... */ } }
        stage('Publication') { when { branch 'main' }; steps { /* withCredentials */ } }
        stage('Recette') {
            when { beforeInput true; branch 'main' }
            input { message 'Deployer ?'; submitter 'admin,recette1' }
            steps { deployer('recette', env.VERSION) }
        }
    }
    post { always { junit 'reports/*.xml' }; failure { notifierEquipe('failure') } }
}
```
- Chaque `sh` = nouveau shell : `. .venv/bin/activate &&` à chaque fois.
- Secret : `withCredentials([...]) { sh 'cmd "$TOKEN"' }` — apostrophes simples, jamais `"${TOKEN}"`.
- Valider : `curl -u admin:<MDP> -X POST -F "jenkinsfile=<Jenkinsfile" http://localhost:8080/pipeline-model-converter/validate`

## Conditions `post` et `when`
| `post` | Quand | `when` | Effet |
|---|---|---|---|
| `always` | Toujours | `branch 'main'` | Branche principale seulement |
| `failure` | Échec | `changeRequest()` | Merge requests seulement |
| `fixed` | Retour au vert | `environment name: 'X', value: 'oui'` | Selon une variable |
| `cleanup` | En dernier | `beforeInput true` | Condition évaluée avant `input` |

## Déploiement FretExpress
| Action | Commande (dans l'agent, dossier du workspace) |
|---|---|
| Intégration / recette | `deploy/deployer.sh int <VERSION>` · `deploy/deployer.sh recette <VERSION>` |
| Production blue/green | `deploy/blue-green.sh <VERSION>` |
| Retour arrière | `deploy/blue-green.sh --retour-arriere` |
| Canary 10 % / annuler | `deploy/canary.sh <VERSION> 10` · `deploy/canary.sh --annuler` |
| Couleur active | `docker exec cicd-traefik-1 cat /etc/traefik/dynamic/prod.yml` |

## Administration Jenkins
| Besoin | Où / commande |
|---|---|
| Exécuteurs du contrôleur à 0 | Manage Jenkins › Nodes › Built-In Node › Configure |
| Rôles | Manage Jenkins › Manage and Assign Roles |
| Configuration effective | Manage Jenkins › Configuration as Code › View Configuration |
| Sauvegarde / restauration testée | `scripts/m09/labs/sauvegarde-jenkins.sh` · `restauration-test.sh <archive>` |
| Audit | `scripts/m09/labs/audit-securite.sh` |
| DORA | `JENKINS_TOKEN=<jeton> python3 scripts/m10/labs/dora.py` |

## Indicateurs DORA
`Débit = Fréquence de déploiement + Délai de mise en production`
`Stabilité = Taux d'échec des changements + Temps de restauration`
