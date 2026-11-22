# fretexpress-pipeline-lib

Bibliotheque partagee Jenkins (shared library) des pipelines FretExpress.

| Etape | Role |
|---|---|
| `pythonInstall()` | venv + dependances (cache pip persistant) |
| `fretexpressVersion()` | version `<majeur>.<mineur>.<BUILD_NUMBER>` ecrite dans `pyproject.toml` |
| `deployer(cible, version)` | deploiement `int`, `recette` ou `prod` (blue/green) avec le compte registre en lecture |
| `notifierEquipe()` | mail d'echec ou de retour au vert |

Utilisation dans un Jenkinsfile :

    @Library('fretexpress-lib@v1') _

Configuration : Administrer Jenkins > System > Global Trusted Pipeline Libraries,
nom `fretexpress-lib`, depot `http://gitea:3000/dev/fretexpress-pipeline-lib.git`.
