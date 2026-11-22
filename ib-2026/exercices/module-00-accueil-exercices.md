# Module 00 — Exercices

## Lab 00.1 ⭐ — Démarrer et vérifier la pile (guidé)
**Durée** : 15 min · **Objectif** : disposer d'un environnement complet et opérationnel
**Contexte** : premier jour chez FretExpress ; la plateforme CI/CD de l'équipe est fournie sous forme de pile Docker Compose.
**Prérequis** : Docker Engine ≥ 25 et Compose v2 (poste local), ou accès SSH à la VM `cicd-stagiaire-<NN>` (cloud)

### Étapes
1. Cas VM cloud uniquement : ouvrir le tunnel SSH communiqué par le formateur (terminal laissé ouvert).
   Variables : `<NN>` = numéro de stagiaire, `<IP_VM>` = adresse de la VM.
   ```bash
   ssh -i stagiaire-<NN> -N -L 8080:localhost:8080 -L 3000:localhost:3000 \
       -L 9000:localhost:9000 -L 8025:localhost:8025 -L 8090:localhost:8090 \
       -L 8000:localhost:80 stagiaire@<IP_VM>
   ```
   Résultat attendu : aucune sortie, la commande reste active. Applications déployées ensuite accessibles sur le port 8000 (ex. `http://int.fretexpress.localhost:8000`).
   Cas poste Windows en salle virtuelle : préparer le poste avec `scripts/setup/windows/preparer-poste.ps1 -Demarrer` (procédure : `setup-environnement.md`, section 2 bis), qui enchaîne les étapes 2 et 3 dans Ubuntu (WSL) ; poursuivre à l'étape 4.
2. Cas poste local uniquement : se placer dans le dossier de la formation et lancer les contrôles.
   ```bash
   scripts/setup/preflight.sh
   ```
   Résultat attendu : `Resultat : 0 KO`. Mémoire < 12 Go : relancer avec `PROFIL=leger`.
3. Cas poste local uniquement : démarrer la pile (5 à 10 min la première fois).
   ```bash
   scripts/setup/init-env.sh complet      # ou : scripts/setup/init-env.sh leger
   ```
   Résultat attendu (fin) :
   ```
   Attente de Gitea ...... OK
   Attente de Jenkins  OK
   New user 'dev' has been successfully created!
   New user 'reviewer' has been successfully created!
   Attente de SonarQube ..... OK
   Pile demarree. Acces : .../environnement/acces.txt
   ```
4. Afficher les accès (VM : `cat /opt/formation/environnement/acces.txt` sur la VM, ou demander au formateur).
   ```bash
   cat environnement/acces.txt
   ```
5. Se connecter à chaque outil avec les comptes du fichier : Jenkins (`admin`), Gitea (`dev`), SonarQube (`admin` / `admin`, nouveau mot de passe imposé à noter), Mailpit.
6. Vérifier l'état des conteneurs.
   ```bash
   docker compose -f environnement/compose.yaml ps --format '{{.Service}} {{.Status}}'
   ```
   Résultat attendu (profil complet) :
   ```
   agent Up 3 minutes
   gitea Up 3 minutes
   jenkins Up 3 minutes
   mailpit Up 3 minutes (healthy)
   sonarqube Up 3 minutes
   traefik Up 3 minutes
   ```

### Critères de réussite
- [ ] `preflight.sh` : 0 KO (ou KO compris et accepté avec le formateur)
- [ ] Connexion réussie à Jenkins, Gitea et SonarQube
- [ ] Mot de passe SonarQube modifié et noté

---

## Exercice 00.2 ⭐⭐ — Quiz de positionnement (semi-autonome)
**Durée** : 10 min · **Objectif** : identifier ses points forts et les notions à consolider
**Énoncé** : répondre seul aux 10 questions, puis comparer avec la grille (fichier corrections). Reporter son score sur la feuille de positionnement du formateur.

1. Commande Git qui crée une branche ET s'y place ?
2. Différence entre `git merge` et `git rebase` (une phrase) ?
3. Commande qui affiche les conteneurs Docker en cours d'exécution ?
4. Rôle d'un fichier `requirements.txt` ou `pyproject.toml` en Python ?
5. Que vérifie un test unitaire ?
6. Que signifie « CI » ?
7. Qu'est-ce qu'une merge request (ou pull request) ?
8. Commande qui affiche le contenu d'un fichier dans un terminal Linux ?
9. Qu'est-ce qu'une variable d'environnement ?
10. Qu'est-ce qu'un fichier YAML ?

**Critères de réussite** : score noté ; 3 notions à consolider identifiées.

---

## Défi 00.3 ⭐⭐⭐ — Cartographier les flux (autonome)
**Durée** : 5 min (ou en fin de journée) · **Objectif** : comprendre qui parle à qui dans la pile
**Énoncé** : à partir de `environnement/compose.yaml`, dessiner (papier ou Mermaid) les flux réseau entre services : ports publiés, réseau `cicd`, volumes partagés (`traefik-dynamic`), socket Docker.
**Critères de réussite** : les 3 flux suivants figurent sur le schéma : Gitea → Jenkins (webhook), Jenkins → agent (SSH), agent → démon Docker de l'hôte (socket).

---

## Bonus 🚀
Lire `environnement/jenkins/casc-initial/jenkins.yaml` : identifier où est défini le compte `admin` et pourquoi le mot de passe n'y apparaît pas en clair.
