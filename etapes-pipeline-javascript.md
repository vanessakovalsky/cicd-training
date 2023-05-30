# Qu'est ce que doit faire mon pipeline d'intégration continue sur un projet Javascript ?

## Environnement (Agent)

- Environnement nodejs : 
  - soit nodejs et les outils nodes sont installés sur l'agent
  - soit utilisation d'un conteneur avec une image de type nodejs

## Qualité

- linter : eslint, jslint
- normes qualités : sonarqube 

## Sécurité :

- Checkmarx
- Owasp Zap proxy 

## Test unitaires

- npm test 
- autre ?

## Build

- installation des dépendances (configurer les dépendances si registre privé NPM à utiliser)
- build 
- packaging

## Tests d'intégrations /fonctionnel 

- mocha
- jasmine

## Envoi du package sur le depot de paquet (type Artifactory)

- push du paquet sur artifactory 

## Livraison 

- Déploiement du paquet sur les environnements cibles :
  - Si image : lancement de nouveaux conteneurs avec la nouvelle image
  - Si paquet: déploiement du nouveau paquet, puis vidage de cache ?
