# Exercice 4 - Découvrir artifactory

## Découvrir l'interface

* Connecter vous sur Artifactory, rechercher dans les depôts lesquels correspondent à des dépôts distants (qui permettent de récupérer des dépendances) et lesquels sont des dépôts locaux qui vont nous permettre de stocker nos paquets.
* Ouvrir un dépôt, puis aller voir le contenu d'un paquet

## Configuration du projet Java

* Dans votre projet Java (vous pouvez en générer un dans gitlab à partir du template, par exemple choisir spring template
* Ajouter dans le fichier pom.xml les lignes suivantes afin de configurer l'endroit ou va se déployer votre paquet

```
<distributionManagement>
    <repository>
        <id>central</id>
        <name>a0rl23w1ryiht-artifactory-primary-0-releases</name>
        <url>https://kovalibretraining.jfrog.io/artifactory/libs-release</url>
    </repository>
</distributionManagement>
```
* Toujours dans ce fichier, enlever la mention SNAPSHOT de la version
* Vous avez besoin d'un fichier de settings que Artifactory peut générer pour vous en allant dans votre compte (ici il est paramètrer directement dans Jenkins pour l'ensemble des projets)

## Intégration avec Jenkins


* Nous allons utiliser Artifactory pour : récupèrer les dépendances et déposer notre paquet
* Pour cela voici le fichier de pipeline (Jenkinsfile) dont vous pouvez vous inspirez:

```
pipeline {
    agent any

    stages {
        stage("Clone the project") {
            steps {
                git branch: 'master', credentialsId: 'vanessa_gitlab_token', url: 'https://gitlab.com/formation15/demojava.git'
            }
        }



         stage ('Exec Maven') {
            steps {
                configFileProvider([configFile(fileId: '2b23c996-edc9-43f9-8822-287d13a1e383', targetLocation: 'settings.xml', variable: 'MAVEN_SETTINGS_CML')]) {
                    sh 'chmod +x mvnw'
                    sh './mvnw clean package deploy -s settings.xml -DskipTests'
            }
        }
                
            }

        stage ('Publish build info') {
            steps {
                rtPublishBuildInfo (
                    serverId: "myartifactory"
                )
            }
        }

    }
  
}
```
* Lors de l'étape d'execution de l'execution de maven, nous récupérons le fichier de settings qui a été fournit au niveau de Jenkins (il n'est pas ajouter dans le depôt de code, car ils contient des informations de connexions qui ne doivent pas être versionnée)
* Lancer le pipeline, et aller voir dans artifactory, vous devriez retrouver votre package

## Pour aller plus loin
* Des exemples de pipeline avec Artifactory pour différent langage et builder sont disponibles ici : https://github.com/jfrog/project-examples/tree/master/jenkins-examples/pipeline-examples/declarative-examples


