# Module 10 — Corrections

Jenkinsfile de référence : `fil-rouge/solutions/m10/Jenkinsfile` ; bibliothèque : `fil-rouge/fretexpress-pipeline-lib` (tag `v1`).

## Lab 10.1 ⭐⭐ — Construire et valider la chaîne complète
### Solution
Partie B — test et code de la zone `SUISSE` :
```python
@pytest.mark.parametrize(
    ("zone", "attendu"),
    [("FR", Decimal("5.00")), ("UE", Decimal("7.50")), ("MONDE", Decimal("12.50")),
     ("SUISSE", Decimal("9.00"))],
)
def test_coefficient_de_zone(zone, attendu):
    assert calculer_tarif(1, zone) == attendu
```
```python
COEFFICIENTS_ZONE = {
    "FR": Decimal("1.0"),
    "UE": Decimal("1.5"),
    "SUISSE": Decimal("1.8"),
    "MONDE": Decimal("2.5"),
}
```
Partie C — sortie relevée sur le banc (build `main` n° 13) :
```
[deploy] Couleur active : green -> deploiement sur blue
[deploy] Image localhost:3000/dev/fretexpress:1.0.13 recuperee
[deploy] Conteneur fretexpress-prod-blue (1.0.13) lance, hote blue.prod.fretexpress.localhost
[deploy] Incident simule : bascule annulee, production inchangee sur green
```
Partie D — mesure relevée sur le banc (historique de 4 commits générés + 2 déploiements antérieurs) :
```
Indicateurs DORA - FretExpress (branche main)
  Deploiements en production   : 6
  Frequence de deploiement     : 144.00 par jour
  Delai de mise en production  : 0.17 h (mediane)
  Taux d'echec des changements : 14.29 %
  Temps de restauration        : 0.03 h (mediane)
  Repere                       : elite / haute performance
```
### Pourquoi
- `post { failure }` au niveau de l'étape `Production` : seul un échec de CETTE étape est un échec de changement en production ; un test rouge sur une MR n'en est pas un.
- Incident simulé AVANT la bascule : le blue/green protège la production (la nouvelle couleur n'est jamais exposée) ; l'incident compte pourtant dans le taux d'échec (changement non livré).
- Lecture des mesures : la fréquence est extrapolée sur une très courte période (quelques minutes) ; le délai médian (≈ 10 min) contient surtout l'attente d'approbation.
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| `dora.py` : `HTTP Error 401` | Jeton absent ou utilisateur non `admin` | `JENKINS_TOKEN` (jeton d'API d'`admin`) |
| `dora.py` : 0 déploiement | Descriptions absentes (Jenkinsfile sans `deployer()` de la bibliothèque v1) | Rattrapage M09 puis M10 |
| `{"detail":"Zone inconnue : SUISSE"}` en production | Version déployée antérieure à la fusion | Vérifier `/version` ; attendre la bascule |
| L'incident ne se déclenche pas | Fichier non commité (`.simuler-echec-prod` ignoré ?) | `git add -f deploy/.simuler-echec-prod` |
| `dora.py` : `ImportError: cannot import name 'UTC'` | Python < 3.11 (ancienne copie du script) | Version courante du script (`timezone.utc`) |

## Exercice 10.2 ⭐⭐ — Présenter la chaîne
### Grille d'observation
| Critère | Attendu |
|---|---|
| Schéma | Les 6 maillons et leurs outils, sens du flux |
| Démonstration | Commit → statut MR → build `main` → approbation → production |
| Mesures | 4 indicateurs, limite de l'échantillon reconnue |
| Améliorations | 3 axes reliés à un indicateur, effort estimé |
Exemples d'axes recevables : approbation de recette remplacée par des tests de bout en bout automatisés (délai) ; agent libéré pendant l'approbation (file d'attente) ; agents éphémères avec cache (propreté et durée) ; canary automatique avec critères de santé (taux d'échec).

## Défi 10.3 ⭐⭐⭐ — Libérer l'exécuteur pendant l'approbation
### Solution (structure)
```groovy
pipeline {
    agent none
    stages {
        stage('CI') {
            agent { label 'python' }
            stages {
                stage('Installation') { steps { pythonInstall(); fretexpressVersion() } }
                // Controles, Couverture, SonarQube, Build, Publication, Deploiement integration
            }
            post { success { stash name: 'deploy', includes: 'deploy/**' } }
        }
        stage('Recette') {
            when { beforeInput true; branch 'main' }
            input { id 'recette'; message 'Deployer en recette ?'; submitter 'admin,recette1' }
            agent { label 'python' }
            steps { unstash 'deploy'; deployer('recette', env.VERSION) }
        }
        stage('Production') {
            when { branch 'main' }
            agent { label 'python' }
            steps { unstash 'deploy'; deployer('prod', env.VERSION) }
        }
    }
}
```
### Pourquoi
Avec `input` et `agent` sur la même étape, la directive `input` est évaluée AVANT l'allocation de l'agent : aucun exécuteur n'est retenu pendant l'attente. `env.VERSION`, fixé dans l'étape `CI`, reste disponible dans les étapes suivantes.

## Défi 10.4 ⭐⭐⭐ — Variante GitLab CI : incident et mesure DORA
### Solution
Pipeline : `fil-rouge/solutions/m08/.gitlab-ci.yml` (aucun ajout : l'échec de production est suivi nativement). Mesure : `scripts/m10/labs/dora_gitlab.py`.
```bash
GITLAB_TOKEN=<JETON> python3 scripts/m10/labs/dora_gitlab.py
```
Mesure du banc (3 déploiements réussis, 1 incident rejoué 3 fois par `retry`, 1 réparation) :
```
Indicateurs DORA - FretExpress (branche main)
  Deploiements en production   : 3
  Taux d'echec des changements : 25.00 %
  Temps de restauration        : 0.09 h (mediane)
```
### Pourquoi
- GitLab enregistre chaque déploiement avec son statut (`success`, `failed`) et son commit : aucune convention à maintenir (Jenkins : description `deploy-prod` / `echec-prod` posée par le Jenkinsfile).
- Délai de mise en production : commits du déploiement = comparaison avec le déploiement réussi précédent (`/repository/compare`).
- `retry: 2` sur le modèle `.deployer` : l'incident simulé est rejoué 2 fois (3 déploiements `failed` dans GitLab) ; `dora_gitlab.py` compte UN échec par commit. À limiter (`retry: when:`) en production réelle.
- Tableau de bord DORA intégré à GitLab : offre Ultimate uniquement, d'où le script (édition CE).

## Bonus
Durée hors attente = durée totale − (horodatage de `Approved by` − horodatage de `Deployer en recette or Abort`), deux lignes horodatées par `timestamps()` dans la console.

## QCM — Réponses
1. **B** — Taux d'échec et temps de restauration : stabilité ; fréquence et délai : débit.
2. **B** — Convention du pipeline : description `deploy-prod <version>`.
3. **B** — Du commit à sa présence en production.
4. **B** — 6 déploiements en quelques minutes, ramenés à 24 h.
5. **B** — Boucle mesurer / agir / remesurer, un goulot à la fois.
6. **A** — Des tests instables tolérés font ignorer les vrais échecs.
