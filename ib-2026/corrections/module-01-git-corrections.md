# Module 01 — Corrections

## Lab 01.1 ⭐ — Versionner FretExpress et le publier sur Gitea
### Solution
Étapes de l'énoncé. Contrôle :
```bash
git log --oneline
git remote -v
```
Sortie attendue :
```
a1b2c3d (HEAD -> main, origin/main) chore: import initial de FretExpress
origin  http://localhost:3000/dev/fretexpress.git (fetch)
origin  http://localhost:3000/dev/fretexpress.git (push)
```
### Pourquoi
- Dépôt Gitea créé vide : un README initial créerait un historique distant divergent (push refusé).
- `.gitignore` fourni : l'environnement virtuel et les rapports ne doivent jamais être versionnés.
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| `! [rejected] main -> main (fetch first)` | Dépôt Gitea initialisé avec un README | `git pull --rebase origin main` puis `git push` |
| `fatal: Authentication failed` | Mauvais mot de passe, ou compte `reviewer` utilisé | Mot de passe de `dev` dans `acces.txt` ; `git credential-cache exit` pour oublier l'ancien |
| `error: src refspec main does not match any` | Aucun commit, ou branche `master` | `git branch -M main` après le premier commit |
| `.venv/` visible dans Gitea | `.gitignore` absent ou ajouté après coup | `git rm -r --cached .venv && git commit -m "chore: retirer .venv"` |

## Exercice 01.2 ⭐⭐ — Choisir et documenter la stratégie de branches
### Solution
Référence : `fil-rouge/solutions/m01/CONTRIBUTING.md` (GitHub Flow, branches `feat/`, `fix/`, `docs/`, `ci/`, `test/`, Conventional Commits, 1 approbation).
```bash
git switch -c docs/contributing
cp <FORMATION>/fil-rouge/solutions/m01/CONTRIBUTING.md .     # ou rédaction personnelle
git add CONTRIBUTING.md
git commit -m "docs: definir le workflow de contribution"
git push -u origin docs/contributing
```
### Pourquoi
GitHub Flow : petite équipe, livraisons fréquentes, `main` toujours déployable ; base saine pour la CI (jour 3) et le déploiement continu (jour 4). Git Flow ajouterait des branches longues sans bénéfice ici (aucune version maintenue en parallèle).
### Variantes acceptables
- Trunk-based : acceptable si justifié par des branches de moins d'un jour et des feature flags ; exige une suite de tests fiable dès maintenant (risque pour l'équipe au jour 1).
- Git Flow : refusé ici, sauf argument de maintenance de plusieurs versions en production (absent du contexte).
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| Bouton de fusion grisé | Aucune approbation (si la protection est déjà active) | Approbation par `reviewer` |
| `reviewer` ne peut pas approuver | Pas collaborateur du dépôt | Étape 7 du lab 01.1 |

## Lab 01.3 ⭐ — Revue, conflit et protection de `main`
### Solution
Contenu résolu possible du README :
```text
## Deploiement actuel

Manuel via un script scp lance par l'equipe exploitation (ticket OPS-112).
Cible : pipeline Jenkins, de chaque commit sur main jusqu'a la production.
```
Commandes (après résolution) :
```bash
git add README.md
git rebase --continue
git push --force-with-lease
git log --oneline --graph -5
```
### Pourquoi
- `pull --rebase` rejoue le commit du stagiaire APRÈS celui du collègue : historique linéaire, conflit résolu une seule fois sur la branche, jamais sur `main`.
- `--force-with-lease` : la branche a été réécrite ; l'option refuse le push si quelqu'un d'autre a poussé entre-temps.
- « Rejeter les approbations obsolètes » : un commit poussé après l'approbation impose une nouvelle revue.
### Erreurs fréquentes
| Symptôme | Cause | Déblocage |
|---|---|---|
| `fatal: No rebase in progress?` | `rebase --continue` lancé sans conflit en cours | Rien à faire ; vérifier `git status` |
| `! [rejected] (stale info)` | Branche distante modifiée par un tiers | `git fetch`, examiner, puis relancer |
| Marqueurs `<<<<<<<` poussés | `git add` d'un fichier non nettoyé | Corriger, nouveau commit ; `git diff --check` avant `add` |
| Éditeur `vim` ouvert par `rebase --continue` | Éditeur par défaut | `:wq` ; ou `git config --global core.editor nano` |
| Le script du collègue échoue (`401`) | Mot de passe `reviewer` absent de `.env` | Relancer `init-env.sh` (idempotent) |

## Défi 01.4 ⭐⭐⭐ — Contrôler le format des commits localement
### Solution
`.githooks/commit-msg` :
```bash
#!/bin/sh
# Refuse les messages hors Conventional Commits (types de CONTRIBUTING.md).
motif='^(feat|fix|test|refactor|docs|ci|chore)(\([a-z0-9-]+\))?: .{1,72}$'
premiere_ligne=$(head -n1 "$1")
if ! printf '%s' "$premiere_ligne" | grep -Eq "$motif"; then
  echo "Message refuse : '$premiere_ligne'" >&2
  echo "Format attendu : type(portee): resume (types : feat fix test refactor docs ci chore)" >&2
  exit 1
fi
```
```bash
chmod +x .githooks/commit-msg
git config core.hooksPath .githooks
git commit --allow-empty -m "update"
```
Sortie attendue :
```
Message refuse : 'update'
Format attendu : type(portee): resume (types : feat fix test refactor docs ci chore)
```
### Pourquoi
Retour immédiat au poste (shift-left) ; le hook reste contournable (`--no-verify`) : la vérification de référence doit aussi exister côté CI ou forge.
### Variantes acceptables
Outils dédiés (`commitlint`, `pre-commit` avec le hook `conventional-pre-commit`) : plus complets, une dépendance de plus.

## Bonus
Fusion par commit de fusion : historique en losange, commit de fusion sans contenu propre. Rebaser puis fusionner : historique linéaire, chaque commit testable isolément → `git bisect` plus simple.

## QCM — Réponses
1. **B** — `git commit` enregistre le contenu de l'index ; `push` publie, `add` prépare.
2. **C** — Git Flow : `develop`, `feature/*`, `release/*`, `hotfix/*` autour de `main`.
3. **B** — `type(portée): résumé` ; les autres messages n'indiquent ni type ni intention.
4. **B** — `--force-with-lease` vérifie que le distant n'a pas bougé depuis le dernier fetch.
5. **B** — Le push direct est refusé ; les fusions de MR restent possibles selon les règles.
6. **B** — Intégration au moins quotidienne = principe même de l'intégration continue.
