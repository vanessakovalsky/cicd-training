# Exercice 3- Bis - Premier Pipeline avec gitlab ci

## Création du fichier de pipeline et des étapes

* Revenir sur le projet sur Gitlab.com
* Créer un fichier à la racine du projet avec le nom : .gitlab-ci.yml 
* Sélectionner .gitlab-ci.yml pour le type de template et appliquer le template Bash. Cela va pré-remplir le fichier.
* Pour créer un fichier minimal : 
    * Supprimer toutes les lignes avant build 1 (donc les lignes 1 à 15)
    * Supprimer toutes les lignes après `echo "For example run a test suite"` dans la section test1
* Ajouter les étapes `build` et `test` en collant les lignes ci-dessous tout en haut du fichier. 
```yaml
    stages:
      - build 
      - test
```

* Pour visualiser et lancer le pipeline, cliqquer dans le menu sur `CI/CD pipelines`
* Cliquer sur le pipeline de votre projet pour voir le statut de votre pipeline.
* Cliquer sur chaque étape et chercher quel runner a executer l'étape.

## Publication d'un site statique

* Un site statique peut être déployer via un générateur de site ou du code html directement par un pipeline Gitlab.
* Pour cela on choisit un générateur et on demande à gitlab-ci de générer nos pages.
* Cela permet de publier une documentation par exemple, pour le faire vous pouvez ajouter un fichier markdown (ou copier un des fichiers de ce depôt)
* Exemple ici avec Pelican un générateur en Python : https://gitlab.com/pages/pelican/-/tree/main 
