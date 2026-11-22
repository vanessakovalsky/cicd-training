# Module 10 — Exercices

Travail en binôme (un poste pilote, rotation à mi-parcours). Point de départ commun : état fin M09.
Retard : `scripts/m09/catch-up/catch-up.sh`. Historique DORA généré par le formateur à 12:30 (`scripts/setup/generate-dora-history.sh 6`).

## Lab 10.1 ⭐⭐ — Construire et valider la chaîne complète (semi-guidé)
**Durée** : 90 min · **Objectif** : un commit traverse toute la chaîne ; un incident est détecté, contenu et réparé ; la chaîne est mesurée
**Contexte** : le directeur technique de FretExpress demande une démonstration de bout en bout et des chiffres.

### Partie A — Assembler (25 min)
1. Revue du Jenkinsfile de `main` : vérifier la présence des 12 étapes (slide « Le Jenkinsfile final »). Comparer avec `fil-rouge/solutions/m10/Jenkinsfile`.
2. Ajouter le marquage d'échec de production (branche `ci/marquage-echec`, MR) :
   ```groovy
   stage('Production') {
       when { branch 'main' }
       steps { deployer('prod', env.VERSION) }
       post {
           failure {
               script { currentBuild.description = "echec-prod ${env.VERSION}" }
           }
       }
   }
   ```
3. Fusionner après revue (compte `reviewer`) et pipeline au vert.

### Partie B — Du commit à la production (25 min)
4. Petit changement métier en TDD : nouvelle zone `SUISSE` (coefficient 1,8). Test d'abord, puis code, MR, revue, fusion.
5. Suivre le build `main` : approbation de la recette par `recette1` ; vérifier la production.
   ```bash
   curl -s -X POST http://fretexpress.localhost/devis -H 'Content-Type: application/json' \
        -d '{"poids_kg": 1, "zone": "SUISSE"}'
   ```
   Résultat attendu : `{"numero":"D-000<N>","montant":"10.35"}` (`5,00 × 1,8 × 1,15 = 10,35`).
6. Chronométrer : heure du commit → heure de la bascule en production (console : `Production basculee sur ...`).

### Partie C — Incident et restauration (20 min)
7. Simuler un incident : sur une branche, créer `deploy/.simuler-echec-prod` (fichier vide), MR, fusion, approbation.
   Résultat attendu (console) :
   ```
   [deploy] Incident simule : bascule annulee, production inchangee sur <couleur>
   ```
   Build `FAILURE`, description `echec-prod 1.0.<N>`, production toujours sur la version précédente.
8. Réparer : supprimer le fichier par une nouvelle MR ; mesurer le temps entre l'échec et le déploiement réussi suivant.

### Partie D — Mesurer (20 min)
9. Jeton d'API : avatar `admin` › **Security** › **API Token** › **Add new Token**.
   ```bash
   JENKINS_TOKEN=<JETON> python3 scripts/m10/labs/dora.py
   ```
10. Relever les 4 indicateurs ; identifier le principal goulot (attente d'approbation ? durée du pipeline ? échecs ?).

### Critères de réussite
- [ ] Zone `SUISSE` en production via MR + pipeline, sans action manuelle autre que revue et approbation
- [ ] Un build `echec-prod` suivi d'un `deploy-prod` ; production jamais interrompue
- [ ] 4 indicateurs DORA relevés et commentés (limites de la mesure comprises)

---

## Exercice 10.2 ⭐⭐ — Présenter la chaîne (restitution)
**Durée** : 35 min (5 min par binôme + questions) · **Objectif** : expliquer la chaîne et défendre des améliorations
**Énoncé** : présentation de 5 min maximum :
1. Schéma de la chaîne (outil libre, Mermaid conseillé).
2. Démonstration ou captures : un commit jusqu'à la production.
3. Mesures DORA et leur lecture.
4. Trois axes d'amélioration classés par rapport gain / effort, chacun relié à un indicateur.
**Critères de réussite** :
- [ ] Temps respecté
- [ ] Chaque axe d'amélioration relié à une mesure (pas d'opinion seule)

---

## Défi 10.3 ⭐⭐⭐ — Libérer l'exécuteur pendant l'approbation (autonome)
**Durée** : 30 min (pour les binômes en avance) · **Objectif** : aucun exécuteur occupé pendant l'attente de la recette
**Énoncé** : restructurer le Jenkinsfile : `agent none` au niveau du pipeline, agent `python` par étape (ou par groupe d'étapes), approbation hors agent. Le workspace n'est plus partagé entre étapes : transmettre ce qui est nécessaire (`stash` / `unstash` des scripts `deploy/`).
**Critères de réussite** :
- [ ] Pendant l'attente d'approbation, **Nodes** › `agent-python` : 2 exécuteurs libres
- [ ] Chaîne toujours fonctionnelle jusqu'à la production

---

## Bonus 🚀
Ajouter au rapport DORA la durée médiane du pipeline (hors attente d'approbation) en utilisant l'API Jenkins (`/wfapi` absent : utiliser la durée totale et l'horodatage de l'approbation dans la console).
