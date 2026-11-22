# Module 02 — Corrections

## Lab 02.1 ⭐ — Prendre en main Jenkins et connecter un agent
### Solution
Équivalent JCasC des étapes 4 à 7 (fichier `scripts/m02/catch-up/agent.yaml` du rattrapage) :
```yaml
jenkins:
  numExecutors: 0
  nodes:
    - permanent:
        name: agent-python
        labelString: "python docker"
        remoteFS: /home/jenkins/agent
        numExecutors: 2
        retentionStrategy: always
        launcher:
          ssh:
            host: agent
            port: 22
            credentialsId: agent-ssh
            javaPath: /opt/java/openjdk/bin/java
            sshHostKeyVerificationStrategy: nonVerifyingKeyVerificationStrategy
credentials:
  system:
    domainCredentials:
      - credentials:
          - basicSSHUserPrivateKey:
              scope: SYSTEM
              id: agent-ssh
              username: jenkins
              privateKeySource:
                directEntry:
                  privateKey: "${readFile:/run/secrets/formation/agent_ed25519}"
```
### Pourquoi
- Portée **System** : la clé sert au contrôleur pour lancer l'agent, aucun job ne doit pouvoir la lire.
- Clé publique installée dans l'agent au démarrage (`JENKINS_AGENT_SSH_PUBKEY`) ; la clé privée ne quitte pas le poste du stagiaire.
- `javaPath` explicite : sessions SSH non interactives sans `JAVA_HOME` dans le `PATH`.
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| `Authentication failed` | Clé collée incomplète (BEGIN / END manquants) ou utilisateur ≠ `jenkins` | Recoller la clé entière, vérifier `Username` |
| `java: not found` | JavaPath absent | **Advanced** › JavaPath `/opt/java/openjdk/bin/java` |
| `Connection refused` | Hôte `localhost` au lieu de `agent` | Host : `agent` (nom du service Compose) |
| `Host key verification failed` | Stratégie « Known hosts file » | « Non verifying » (banc) ou « Manually trusted key » |
| Builds toujours sur le contrôleur | Exécuteurs du Built-In Node non modifiés | Étape 4 |

## Lab 02.2 ⭐ — Premier job relié à Git
### Solution
Étapes de l'énoncé. Rattrapage : `scripts/m02/catch-up/premier-job.groovy` crée le même job.
### Pourquoi
- Label `python` : le job ne peut pas s'exécuter ailleurs que sur un agent équipé.
- venv dans le workspace : dépendances isolées par job.
- Échec provoqué sur une branche : `main` reste toujours au vert (règle du module 01).
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| `There are no nodes with the label 'python'` | Agent hors ligne ou label mal saisi | **Nodes** › `agent-python` › **Log** ; labels séparés par des espaces |
| `Couldn't connect to server` sur `gitea.localhost` | URL saisie avec un autre nom d'hôte | URL `http://localhost:3000/...` (réécrite vers `gitea:3000` dans l'agent) |
| `python3: not found` | Job exécuté hors de l'agent Python | Restreindre au label `python` |
| `couldn't find remote ref refs/heads/test/echec-volontaire` | Branche non poussée | `git push -u origin test/echec-volontaire` |

## Exercice 02.3 ⭐⭐ — Déclenchement automatique par scrutation
### Solution
**Triggers** › **Poll SCM** › Schedule : `H/2 * * * *` › **Save**. Pousser un commit sur `main` (via MR). **Git Polling Log** : `Changes found`. Cause du build : `Started by an SCM change`.
### Pourquoi
`H` : minute calculée à partir du nom du job (hash) → les jobs ne scrutent pas tous à la même seconde.
### Variantes acceptables
**Build periodically** (`H 2 * * *`) : construit même sans changement (build de nuit) ; ne répond pas à l'objectif.
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| Aucun déclenchement | Commit sur une autre branche que celle du job | Pousser sur la branche suivie |
| Scrutation sans effet sur le premier build | Aucune référence antérieure | Lancer un build manuel une fois |

## Défi 02.4 ⭐⭐⭐ — Job paramétré
### Solution
- **This project is parameterized** › **String Parameter** : nom `BRANCHE`, défaut `main`.
- Branch Specifier : `*/${BRANCHE}`.
- Shell :
  ```bash
  echo "Branche testee : ${BRANCHE}"
  python3 -m venv .venv
  . .venv/bin/activate
  pip install --quiet -e ".[dev]"
  pytest -v --junitxml=reports/junit.xml
  ```
- **Post-build Actions** › **Publish JUnit test result report** › `reports/junit.xml`.
### Pourquoi
Limites du freestyle : configuration stockée dans `JENKINS_HOME` (non versionnée, non revue), duplication entre jobs, pas de branches automatiques → pipeline as code au module 05.

## Bonus
Le YAML exporté contient le nœud `agent-python` : la configuration manuelle peut être capturée, mais elle reste non versionnée tant que le fichier n'est pas commité et rechargé (module 09).

## QCM — Réponses
1. **C** — Déploiement continu : mise en production automatique de chaque version validée.
2. **B** — Un exécuteur = un build simultané possible sur un nœud.
3. **B** — Le code des builds n'a alors jamais accès à `JENKINS_HOME` ni aux secrets du contrôleur.
4. **B** — Le label (ou l'expression de labels) sélectionne les agents éligibles.
5. **B** — Durée du pipeline = délai de retour (feedback) aux développeurs.
6. **B** — La fin de la console donne la dernière commande et son code de sortie.
