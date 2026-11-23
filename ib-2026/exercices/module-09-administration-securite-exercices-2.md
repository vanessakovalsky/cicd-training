# Module 09 — Exercices, bloc 2

Bloc 2 : séquences S9.3, S9.4. Point de départ : labs du bloc 1 terminés (`module-09-administration-securite-exercices-1.md`).

## Lab 09.3 ⭐⭐ — Sauvegarder et restaurer (semi-guidé)
**Durée** : 30 min · **Objectif** : sauvegarde complète ET restauration vérifiée
### Étapes
1. Sauvegarder.
   ```bash
   scripts/m09/labs/sauvegarde-jenkins.sh
   ```
   Résultat attendu :
   ```
   Sauvegarde : sauvegardes/jenkins-home-<DATE>.tgz (1,7M)
   Export JCasC : sauvegardes/jenkins-casc-<DATE>.yaml
   ```
2. Lister le contenu de l'archive : présence de `secrets/master.key`, `credentials.xml`, `users/`, `jobs/` ; absence de `workspace/` et `plugins/`.
   ```bash
   tar tzf sauvegardes/jenkins-home-*.tgz | grep -E '^\./(secrets/master.key|credentials.xml|users/|plugins/)' | head
   ```
3. Lire l'export JCasC : comment apparaissent les secrets ?
4. Restaurer sur une instance de test (port 8081) et vérifier.
   ```bash
   scripts/m09/labs/restauration-test.sh sauvegardes/jenkins-home-<DATE>.tgz
   ```
   Résultat attendu : `Demarrage de jenkins-restauration ... OK : http://localhost:8081`. Se connecter en `dev1` : job `fretexpress` visible, historique des builds présent.
5. Nettoyer : `scripts/m09/labs/restauration-test.sh --nettoyer`.

### Critères de réussite
- [ ] Restauration réussie : comptes, rôles, jobs et historique présents sur l'instance de test
- [ ] Explication : rôle de `secrets/master.key` ; pourquoi exclure `plugins/` et `workspace/`
- [ ] Instance de test supprimée

---

## Lab 09.4 ⭐⭐ — Credentials de dossier et audit de sécurité (semi-guidé)
**Durée** : 35 min · **Objectif** : secret limité à un projet ; écarts de sécurité mesurés et corrigés
### Étapes
1. Credential de portée dossier : job `fretexpress` › **Credentials** › **Stores scoped to fretexpress** › **Global credentials** › **Add Credentials** : **Secret text**, ID `api-carburant`, valeur fictive.
2. Vérifier la portée : `premier-job` › **Configure** › **Environment** › **Use secret text(s) or file(s)** › **Add** › **Secret text** : `api-carburant` absent de la liste. Annuler.
3. Auditer.
   ```bash
   scripts/m09/labs/audit-securite.sh
   ```
   Résultat attendu (extrait) :
   ```
   OK  Executeurs du controleur : 0
   OK  Strategie d'autorisation : RoleBasedAuthorizationStrategy
   INFO Credentials de portee GLOBAL : gitea-dev, sonar-token, registre-lecture
   Resultat : 0 KO
   ```
4. Corriger chaque `KO` (ex. journal d'audit : **Manage Jenkins** › **System** › **Audit Trail** › **Add Logger** › **Log file** : `/var/jenkins_home/audit/audit.log`, taille 10 Mo, 5 fichiers) puis relancer l'audit.
5. Lire le journal d'audit après une modification de job.
   ```bash
   docker exec cicd-jenkins-1 sh -c 'tail -3 /var/jenkins_home/audit/audit.log.0'
   ```
6. Lister les credentials de portée GLOBAL : lesquels pourraient passer en portée dossier ? Lesquels sont utilisés par des intégrations système (SonarQube) ?

### Critères de réussite
- [ ] `api-carburant` invisible hors du dossier `fretexpress`
- [ ] Audit à `0 KO`
- [ ] Journal d'audit : action identifiée (qui, quoi, quand)

---

## Défi 09.5 ⭐⭐⭐ — Rotation d'un secret sans interruption (autonome)
**Durée** : 20 min · **Objectif** : remplacer le jeton de déploiement sans casser la chaîne
**Énoncé** : générer un nouveau jeton Gitea `deploiement-2` (lecture des paquets), le mettre en service dans Jenkins (credential `registre-lecture` : par l'interface OU par le fichier `environnement/secrets/registre_token` + rechargement JCasC), vérifier un déploiement en intégration, puis révoquer l'ancien jeton et revérifier.
**Critères de réussite** :
- [ ] Déploiement réussi avec le nouveau jeton, ancien jeton révoqué dans Gitea
- [ ] Procédure écrite en 5 étapes maximum, ordre justifié (activer avant de révoquer)

---

## Bonus 🚀
Lire **Manage Jenkins** › **In-process Script Approval** : quelles signatures sont en attente ? Pourquoi ne jamais tout approuver en masse ?
