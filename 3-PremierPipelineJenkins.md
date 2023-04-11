# Exercice 3 - Premier pipeline Jenkins

## Objectifs 
* Créer un premier pipeline
* Executer et analyser le résultat de son pipeline

## Sur Gitlab, 
* Dans votre projet conference-app  créer un fichier Jenkinsfile (respecter la casse) à la racine
* Définir le contenu suivant pour que le script créer un fichier TP3/test.txt qui contient 'hello' lors de l'execution du pipeline (Pipeline scripté)
```
pipeline {
    agent { docker { image 'maven:3.9.0-eclipse-temurin-11' } }
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

## Sur Jenkins

* créer un job pipeline de type multibranche  s’appuyant sur votre projet helloworld.
* Lancer un build du job et consulter et analyser les logs
