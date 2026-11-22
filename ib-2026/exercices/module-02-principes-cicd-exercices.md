# Module 02 — Exercices

Interface Jenkins en anglais : libellés exacts en anglais, traduction entre parenthèses.

## Lab 02.1 ⭐ — Prendre en main Jenkins et connecter un agent (guidé)
**Durée** : 60 min · **Objectif** : agent `agent-python` en ligne, contrôleur sans exécuteur
**Contexte** : l'instance Jenkins de FretExpress vient d'être installée ; aucun agent n'est déclaré.
**Prérequis** : lab 00.1 ; accès `admin` (fichier `acces.txt`)

### Étapes
1. Explorer : http://localhost:8080 › **Manage Jenkins** (Administrer Jenkins). Repérer **System**, **Nodes**, **Credentials**, **Plugins**, **Security**, **Configuration as Code**.
2. Ouvrir **Configuration as Code** › **View Configuration** : retrouver `numExecutors: 2` et l'utilisateur `admin`.
3. Ouvrir **Plugins** › **Installed plugins** : vérifier la présence de `Git`, `Gitea`, `SSH Build Agents`, `Configuration as Code`.
4. Mettre les exécuteurs du contrôleur à 0 : **Manage Jenkins** › **Nodes** › **Built-In Node** › **Configure** › **Number of executors** : `0` › **Save**.
5. Afficher la clé privée de l'agent (poste local ; VM : même commande dans `/opt/formation`).
   ```bash
   cat environnement/secrets/agent_ed25519
   ```
   Résultat attendu : clé privée au format OpenSSH (bloc encadré par des lignes `-----BEGIN ...` et `-----END ...`).
6. Créer le credential : **Manage Jenkins** › **Credentials** › **System** › **Global credentials (unrestricted)** › **Add Credentials** :
   - Kind : **SSH Username with private key**
   - Scope : **System** (utilisable par Jenkins, invisible des jobs)
   - ID : `agent-ssh` · Username : `jenkins`
   - Private Key › **Enter directly** › coller la clé complète (lignes BEGIN / END comprises)
   - **Create**
7. Créer le nœud : **Manage Jenkins** › **Nodes** › **New Node** › nom `agent-python`, **Permanent Agent** › **Create** :
   - Number of executors : `2`
   - Remote root directory : `/home/jenkins/agent`
   - Labels : `python docker`
   - Usage : **Use this node as much as possible**
   - Launch method : **Launch agents via SSH** · Host : `agent` · Credentials : `jenkins (agent-ssh)`
   - Host Key Verification Strategy : **Non verifying Verification Strategy**
   - **Advanced** › JavaPath : `/opt/java/openjdk/bin/java`
   - **Save**
8. Vérifier : **Nodes** › `agent-python` › **Log**.
   Résultat attendu (fin) :
   ```
   This is a Unix agent
   Agent successfully connected and online
   ```

### Critères de réussite
- [ ] **Nodes** : `Built-In Node` avec 0 exécuteur, `agent-python` en ligne avec 2 exécuteurs
- [ ] Credential `agent-ssh` de portée **System**
- [ ] Labels `python` et `docker` visibles sur l'agent

---

## Lab 02.2 ⭐ — Premier job relié à Git (guidé)
**Durée** : 40 min · **Objectif** : job `premier-job` qui récupère `fretexpress` et lance les tests
**Contexte** : première automatisation de FretExpress ; les tests ne sont aujourd'hui lancés que sur le poste de Kevin.

### Étapes
1. **New Item** (Nouvel élément) › nom `premier-job` › **Freestyle project** › **OK**.
2. **General** › cocher **Restrict where this project can be run** › Label Expression : `python`.
3. **Source Code Management** › **Git** :
   - Repository URL : `http://localhost:3000/dev/fretexpress.git` (dépôt public : aucun credential)
   - Branch Specifier : `*/main`
4. **Build Steps** › **Add build step** › **Execute shell** :
   ```bash
   python3 -m venv .venv
   . .venv/bin/activate
   pip install --quiet -e ".[dev]"
   pytest -v
   ```
5. **Save** › **Build Now**. Ouvrir le build `#1` › **Console Output**.
   Résultat attendu (extrait) :
   ```
   Building remotely on agent-python (python docker) in workspace
     /home/jenkins/agent/workspace/premier-job
   Cloning repository http://localhost:3000/dev/fretexpress.git
   + pytest -v
   ========================= 2 passed in 0.34s =========================
   Finished: SUCCESS
   ```
6. Ouvrir **Workspace** : retrouver le code récupéré et le dossier `.venv`.
7. Provoquer un échec sans toucher à `main` : créer une branche avec un test cassé.
   ```bash
   cd ~/fretexpress && git switch main && git pull
   git switch -c test/echec-volontaire
   sed -i 's/"statut": "ok"/"statut": "ko"/' tests/test_api.py
   git commit -am "test: echec volontaire (lab 02.2)"
   git push -u origin test/echec-volontaire
   ```
8. Configurer `premier-job` : Branch Specifier `*/test/echec-volontaire` › **Save** › **Build Now**.
   Résultat attendu (fin de console) :
   ```
   FAILED tests/test_api.py::test_health_repond_ok - AssertionError: assert {'statut': 'ok'} == {'statut': 'ko'}
   ========================= 1 failed, 1 passed in 0.41s =========================
   Build step 'Execute shell' marked build as failure
   Finished: FAILURE
   ```
9. Remettre `*/main` dans le job ; supprimer la branche : `git push origin --delete test/echec-volontaire`.

### Critères de réussite
- [ ] Build `#1` au vert, exécuté sur `agent-python`
- [ ] Un build rouge analysé : test, assertion et étape en échec identifiés
- [ ] Job revenu sur `*/main`, dernier build au vert

---

## Exercice 02.3 ⭐⭐ — Déclenchement automatique par scrutation (semi-autonome)
**Durée** : 15 min · **Objectif** : relancer `premier-job` à chaque nouveau commit sans clic
**Énoncé** : configurer une scrutation du dépôt toutes les 2 minutes, pousser un commit (MR fusionnée ou branche suivie), constater le déclenchement et sa cause.
**Indices** : section **Triggers** ; syntaxe cron de Jenkins avec `H` ; page **Git Polling Log** du job.
**Critères de réussite** :
- [ ] Un build dont la cause est `Started by an SCM change`
- [ ] Explication de l'intérêt du symbole `H` (répartition de charge)

---

## Défi 02.4 ⭐⭐⭐ — Job paramétré (autonome)
**Durée** : 15 min · **Objectif** : choisir la branche testée au lancement
**Énoncé** : transformer `premier-job` en job paramétré (`BRANCHE`, défaut `main`) utilisé dans le Branch Specifier ; afficher la branche testée en tête de console ; publier le rapport `reports/junit.xml` (action post-build **Publish JUnit test result report**).
**Critères de réussite** :
- [ ] **Build with Parameters** propose `BRANCHE`
- [ ] Page **Test Result** du build : 2 tests
- [ ] Explication des limites du freestyle (configuration non versionnée)

---

## Bonus 🚀
Ouvrir **Manage Jenkins** › **Configuration as Code** › **Download Configuration** et retrouver dans le YAML le nœud `agent-python` créé à la main. Conclusion sur la reproductibilité d'une configuration faite par clics.
