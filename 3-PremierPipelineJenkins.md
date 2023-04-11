# Exercice 3 - Premier pipeline Jenkins

## Objectifs 
* Créer un premier pipeline
* Executer et analyser le résultat de son pipeline

## Sur Gitlab, création du fichier de pipeline
* Dans votre projet conference-app  créer un fichier Jenkinsfile (respecter la casse) à la racine
* Définir le contenu suivant pour que le script créer un fichier TP3/test.txt qui contient 'hello' lors de l'execution du pipeline (Pipeline scripté)
```
pipeline {
    agent any
    stages {
        stage('build') {
            steps {
                sh 'mkdir -p TP3'
                sh 'echo "Fichier créé par Jenkins" >> TP3/test.txt' 
            }
        }
    }
}
```

## Sur Jenkins, création et lancement du job

* créer un job pipeline  s’appuyant sur votre projet conference-app.
* Sur la page d'accueil de Jenkins, choisir Nouveau Item
* Définir un nom, choisir le type Pipeline et cliquer sur OK
* Dans la page de configuration:
    * Dans Build Trigger, cocher la case `Build when a change is pushed to GitLab. GitLab webhook URL: http://3.129.65.240:18080/project/Exercice`
        * Noter l'URL après Gitlab webhook URL
        * Choisir les évènements qui vont déclencher le Build (vous pouvez laisser ceux cocher par défaut)
        * Déplier le menu Advanced, générer un Secret Token et noter le 
    * Dans Pipeline : 
        * Définition : Choisir `Pipeline Script from SCM`
        * SCM: Git
        * Repository URL : l'URL de votre dépot (la même que pour faire un git clone)
        * Dans Credentials, ajouter un credentials avec votre identifiant et mot de passe pour vous connecter à Gitlab
    * Laisser les autres options par défaut (ou modifier les si vous le souhaitez), et cliquer sur `Sauver`
* Lancer un build du job
* Consulter et analyser les logs
* Vérifier dans le workspace que le dossier TP3 contient bien le fichier `test.txt`

## Déclenchement d'un build à chaque push sur le dépôt Gitlab

* Dans les paramètres du projet de Gitlab, choisir WebHooks
    * Renseignez l'URL de webhook et le token qui ont été généré par Jenkins à l'étape précédente
    * Désactiver `Enable SSL verification` 
    * Cliquer sur `Add Webhook`
* Faire un push sur le dépôt sur la branche master (ou celle que vous avez configurer dans Jenkins
* Vérifier dans Jenkins suite au push qu'un build a bien été déclencher

## Bonus : ajouter le clone du projet à votre pipeline


## Pour aller plus loin : 
* Le paramètrage des pipelines multi-branches nécessites différentes configuration, vous pouvez suivre la documentation (en anglais) disponible ici : https://www.jenkins.io/blog/2019/08/23/introducing-gitlab-branch-source-plugin/ 
* Des exemples de pipelines jenkins sont disponibles ici : https://github.com/jenkinsci/pipeline-examples 
