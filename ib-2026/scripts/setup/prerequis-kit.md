# Kit de prérequis (à faire avant le J1, 2 à 3 h)

Formation « Pipelines et processus DevOps CI/CD avec Jenkins, Git et TDD ».

## 1. Terminal Linux (45 min)
- Se déplacer et lire : `pwd`, `ls -la`, `cd`, `cat`, `less`, `grep -n`, chemins relatifs et absolus.
- Créer et modifier : `mkdir -p`, `cp -r`, `mv`, `rm -r`, un éditeur (`nano` ou VS Code).
- Variables d'environnement : `export NOM=valeur`, `echo $NOM`.
- Exercice : créer `~/essai/a/b`, y copier un fichier, rechercher un mot avec `grep -rn`.

## 2. Git (45 min)
- Documentation officielle : https://git-scm.com/book/fr/v2 (chapitres 1 à 3).
- Commandes : `git clone`, `status`, `add`, `commit -m`, `log --oneline`, `switch -c`, `merge`, `push`, `pull`.
- Exercice : dépôt local, 3 commits, une branche, une fusion.

## 3. Python (45 min)
- Documentation officielle : https://docs.python.org/fr/3.12/tutorial/ (chapitres 3 à 6).
- Fonctions, conditions, dictionnaires, classes simples, `import`, environnement virtuel (`python3 -m venv .venv`, `. .venv/bin/activate`, `pip install`).
- Exercice : fonction `prix(poids)` avec une condition, appelée depuis un second fichier.

## 4. Docker (30 min)
- Documentation officielle : https://docs.docker.com/get-started/
- Notions : image, conteneur, port publié, volume ; commandes `docker ps`, `docker logs`, `docker exec`.
- Installation sur le poste : Docker Desktop ou Docker Engine + Compose v2 ; lancer `scripts/setup/preflight.sh` (fourni) et envoyer la sortie au formateur à J-2.

## 5. Auto-évaluation
Pouvoir répondre sans aide : quelle différence entre `git add` et `git commit` ? Que fait `docker ps` ? Comment activer un environnement virtuel Python ?
