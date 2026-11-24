# fretexpress-ci-lib

Modèles GitLab CI partagés des pipelines FretExpress (variante GitLab du module 08, équivalent de `fretexpress-pipeline-lib` pour Jenkins).

| Fichier | Modèles | Équivalent Jenkins |
|---|---|---|
| `templates/python.yml` | `.python` (venv + cache pip), `.version` | `pythonInstall()`, `fretexpressVersion()` |
| `templates/deploiement.yml` | `.deployer` (variable `CIBLE`) | `deployer(cible, version)` |

Utilisation, version figée par un tag :
```yaml
include:
  - project: dev/fretexpress-ci-lib
    ref: v1
    file: [templates/python.yml, templates/deploiement.yml]
```
Notification d'échec : native dans GitLab (mail de pipeline en échec ou réparé, paramètres de notification de l'utilisateur), pas de modèle.
