# Module 05 — Exercices, bloc 1

Bloc 1 : séquences S5.1, S5.2. Bloc 2 : `module-05-jenkinsfile-exercices-2.md`.

Point de départ : `main` à l'état fin M04 (36 tests). Retard : `scripts/m04/catch-up/catch-up.sh`.

## Lab 05.1 ⭐ — Écrire un pipeline de build et de tests (guidé)
**Durée** : 55 min · **Objectif** : Jenkinsfile déclaratif versionné, exécuté par un job Pipeline
**Contexte** : la configuration de `premier-job` n'est ni versionnée ni relue ; l'équipe veut la chaîne dans le dépôt.
**Prérequis** : agent `agent-python` en ligne

### Étapes
1. Créer la branche.
   ```bash
   cd ~/fretexpress && git switch main && git pull
   git switch -c ci/jenkinsfile
   ```
2. Créer `Jenkinsfile` à la racine (contenu des slides « Le Jenkinsfile FretExpress (1/3) à (3/3) »).
3. Valider la syntaxe avant tout commit.
   Variables : `<MOT_DE_PASSE_ADMIN>` = mot de passe Jenkins de `admin`.
   ```bash
   curl -s -u admin:<MOT_DE_PASSE_ADMIN> -X POST -F "jenkinsfile=<Jenkinsfile" \
        http://localhost:8080/pipeline-model-converter/validate
   ```
   Résultat attendu : `Jenkinsfile successfully validated.`
4. Commit et push.
   ```bash
   git add Jenkinsfile
   git commit -m "ci: pipeline declaratif de build et de tests"
   git push -u origin ci/jenkinsfile
   ```
5. Jenkins › **New Item** › `fretexpress-pipeline` › **Pipeline** › **OK** :
   - **Pipeline** › Definition : **Pipeline script from SCM** › SCM : **Git**
   - Repository URL : `http://localhost:3000/dev/fretexpress.git` · Branch Specifier : `*/ci/jenkinsfile`
   - Script Path : `Jenkinsfile` › **Save**
6. **Build Now**, puis **Pipeline Overview** (vue graphique) et **Console Output**.
   Résultat attendu (fin de console) :
   ```
   [Pipeline] junit
   Recording test results
   [Pipeline] archiveArtifacts
   Archiving artifacts
   Recording fingerprints
   Finished: SUCCESS
   ```
7. Ouvrir **Test Result** (36 tests) et **Build Artifacts** (`fretexpress-1.0.0-py3-none-any.whl`).
8. Introduire une erreur de syntaxe (`step` au lieu de `steps`), relancer le validateur, lire le message, corriger.
   Résultat attendu (validateur) :
   ```
   WorkflowScript: 4: Unknown stage section "step". Starting with version 0.5, steps in a stage must be in a ‘steps’ block.
   ```

### Critères de réussite
- [ ] `Jenkinsfile` sur la branche `ci/jenkinsfile`, validé
- [ ] Build au vert : 3 étapes visibles, rapport de 36 tests, wheel archivé
- [ ] Aucune configuration de build saisie dans l'interface (hors source du Jenkinsfile)

---

## Défi 05.4 ⭐⭐⭐ — Pipeline plus robuste (autonome)
**Durée** : 20 min · **Objectif** : pipeline qui échoue vite et proprement
**Énoncé** : enrichir le Jenkinsfile : `timeout` par étape (installation : 5 min), message d'aide en cas d'échec des tests (`post` d'étape), nettoyage du workspace en fin de build sauf en échec (diagnostic), nom de build lisible (`#<N> - <commit court>`).
**Critères de réussite** :
- [ ] Échec volontaire : message d'aide affiché, workspace conservé
- [ ] Succès : workspace vidé
- [ ] Nom des builds au format demandé
