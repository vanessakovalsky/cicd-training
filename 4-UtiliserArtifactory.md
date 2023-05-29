# Exercice 4 - Découvrir artifactory

## Découvrir l'interface

* Connecter vous sur Artifactory, rechercher dans les depôts lesquels correspondent à des dépôts distants (qui permettent de récupérer des dépendances) et lesquels sont des dépôts locaux qui vont nous permettre de stocker nos paquets.
* Ouvrir un dépôt, puis aller voir le contenu d'un paquet

## Intégration avec Jenkins

* Nous allons utiliser Artifactory pour : récupèrer les dépendances et déposer notre paquet
* Pour cela nous devons d'abord configurer Artifactory avec l'étape suivante à ajouter à notre pipeline:

```
`stage ('Artifactory configuration') {
            steps {

                rtMavenDeployer (
                    id: "MAVEN_DEPLOYER",
                    serverId: "myartifactory",
                    releaseRepo: 'libs-release',
                    snapshotRepo: 'libs-snapshot'
                )

                rtMavenResolver (
                    id: "MAVEN_RESOLVER",
                    serverId: "myartifactory",
                    releaseRepo: 'libs-release-local',
                    snapshotRepo: 'libs-snapshot-local'
                )
            }
        }
```
* Puis nous utilisons maven pour construire notre package :
```
        stage ('Exec Maven') {
            steps {
                tool name: 'maventool', type: 'maven'
                sh './mvnw clean'
                sh './mvnw package'
            }
        }
```
* Ici la récupèration des dépendances ne passent pas par Artifactory, il faudrait modifier la configuration de Maven pour cela 
(si vous souhaitez le faire, vous pouvez récupèrer dans Artifactory le fichier de settings de maven et le rajouter à votre dépôt)

## Pour aller plus loin
* Des exemples de pipeline avec Artifactory pour différent langage et builder sont disponibles ici : https://github.com/jfrog/project-examples/tree/master/jenkins-examples/pipeline-examples/declarative-examples


