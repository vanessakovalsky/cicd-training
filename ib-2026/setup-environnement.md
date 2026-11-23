# Mise en place de l'environnement

Une seule pile Docker Compose (`environnement/compose.yaml`), déployée au choix sur le poste du stagiaire ou sur une VM Google Cloud par stagiaire. Mêmes scripts, mêmes URL (en cloud : par tunnel SSH).

## 1. Composants et versions (banc du 13/11/2026)

| Composant | Image / version | Rôle | Port hôte |
|---|---|---|---|
| Jenkins LTS | `jenkins/jenkins:2.580.2-lts-jdk21` + plugins figés (`environnement/jenkins/plugins.txt`) | Contrôleur, JCasC | 8080 |
| Agent Jenkins | `cicd-formation/agent-python:local` (Python 3.12.16, Java 21.0.13, Docker CLI 27.5.1, sonar-scanner 7.1.0.4889) | Exécution des pipelines | — |
| Gitea | `gitea/gitea:1.24` (1.24.7) | Forge, MR, registre PyPI et conteneurs | 3000, 2222 |
| SonarQube Community Build | `sonarqube:25.6.0.109173-community` | Analyse statique (profil `complet`) | 9000 |
| Traefik | `traefik:v3.6` (3.6.25) | Routage des environnements déployés | 80 (`TRAEFIK_PORT`), 8090 |
| Mailpit | `axllent/mailpit:v1.24` (1.24.2) | Réception des notifications | 8025 |

Dépendances Python du fil rouge (figées dans `pyproject.toml`) : FastAPI 0.162.5, Uvicorn 0.54.0, httpx 0.28.1, pytest 9.2.0, pytest-cov 7.1.0, pytest-randomly 5.1.0, ruff 0.17.5, twine 7.0.0, pip-audit 2.10.0.

Mémoire mesurée, pile complète au repos : ≈ 4 Go (SonarQube ≈ 2,3 Go, Jenkins ≈ 0,9 Go).

## 2. Poste local

### Prérequis
- Linux, macOS ou Windows (WSL 2) ; Docker Engine ≥ 25 ou Docker Desktop ; Compose v2 ≥ 2.24.
- Profil `complet` : 12 Go de mémoire allouée à Docker recommandés (8 Go minimum, autres conteneurs arrêtés) ; profil `leger` : 6 Go.
- 30 Go de disque libre ; accès à Docker Hub, PyPI, `download.docker.com`, `binaries.sonarsource.com` (construction de l'agent).
- Git, `curl`, Python ≥ 3.10 (scripts de mesure) ; navigateur récent.

### Installation
```bash
git clone <URL_DEPOT_FORMATION> formation-cicd && cd formation-cicd
scripts/setup/preflight.sh                 # PROFIL=leger pour le profil sans SonarQube
scripts/setup/init-env.sh complet          # ou : leger ; port 80 pris : TRAEFIK_PORT=8000
cat environnement/acces.txt
```
Sortie attendue (fin de `init-env.sh`) :
```
Attente de Gitea ................. OK
Attente de Jenkins  OK
New user 'dev' has been successfully created!
New user 'reviewer' has been successfully created!
Attente de SonarQube .... OK
Pile demarree. Acces : .../environnement/acces.txt
```

### Fichiers générés (jamais versionnés)
| Fichier | Contenu |
|---|---|
| `environnement/.env` | Mots de passe aléatoires (Jenkins, Gitea), clé publique de l'agent, `SONAR_ADMIN_PASSWORD` (après rattrapage M06) |
| `environnement/secrets/` | Clé privée de l'agent, jetons (Gitea, SonarQube, registre), mot de passe des utilisateurs du M09 |
| `environnement/jenkins/casc/` | Configuration JCasC de travail (copie de `casc-initial/`, modifiée par les labs et les rattrapages) |
| `environnement/acces.txt` | URL et comptes |

### Points d'attention constatés sur le banc
- Port 80 déjà utilisé (serveur web local) : `TRAEFIK_PORT=8000` ; URL des applications en `:8000`.
- Docker Desktop : arrêt possible au premier démarrage de SonarQube si d'autres conteneurs consomment la mémoire ; arrêter ces conteneurs ou utiliser le profil `leger`.
- Dans les conteneurs, `curl` et `git` envoient tout nom `*.localhost` sur la boucle locale : Gitea est donc annoncé en `http://localhost:3000` et réécrit vers `http://gitea:3000` par `git config url.insteadOf` (images Jenkins et agent).
- Registre d'images : `localhost:3000` (port publié) ; considéré comme non chiffré autorisé par le démon Docker.
- Docker Engine ≥ 29 : Traefik ≥ 3.6 obligatoire (Traefik 3.3 : fournisseur Docker en erreur `Error response from daemon`, aucune route vers les applications déployées, test de fumée en échec).

## 2 bis. Poste Windows en salle virtuelle (Guacamole)

Banc du 22/11/2026, poste de salle virtuelle ib Cegos : Windows 11 Entreprise, 12 vCPU, 64 Go, Docker Desktop 4.93 (Engine 29.8, moteur WSL 2) ; session non élevée ; ni Git ni Python côté Windows.

Principe : pile et scripts dans Ubuntu (WSL 2) ; navigateur côté Windows (Edge ou Chrome).
```
Windows (Edge, localhost:8080 / 3000 / 9000 / 8025)
   └── Docker Desktop ── moteur WSL 2 ── conteneurs de la pile
   └── Ubuntu-24.04 (WSL) ── ~/formation ── scripts/*.sh ── docker (intégration WSL)
```

### Préparation (une fois par poste, 10 min)
Dans PowerShell (session normale, sans élévation) :
```powershell
irm https://raw.githubusercontent.com/vanessakovalsky/cicd-training/main/ib-2026/scripts/setup/windows/preparer-poste.ps1 -OutFile $env:TEMP\preparer-poste.ps1
powershell -ExecutionPolicy Bypass -File $env:TEMP\preparer-poste.ps1 -Demarrer
```
- Étapes : Docker Desktop démarré → `Ubuntu-24.04` installée → intégration WSL activée (redémarrage de Docker Desktop) → `stagiaire` (sudo, groupe `docker`) → dépôt cloné dans `~/formation` → `preflight.sh` + `init-env.sh complet` (`-Demarrer`).
- Étape interactive (premier démarrage d'Ubuntu) : effacer le nom proposé (`ib`), saisir `stagiaire`, mot de passe au choix (deux fois, sans affichage), puis `exit`.
- Alerte « Sécurité Windows » pour Docker Desktop Backend : **Annuler** (accès `localhost` suffisant, aucun port exposé au réseau de la salle).
- Terminal de travail : Windows Terminal › flèche ▾ › `Ubuntu-24.04`, puis `cd ~/formation`.

### Points d'attention constatés
| Symptôme | Cause | Action |
|---|---|---|
| `permission denied ... docker.sock` | Groupe `docker` pris en compte à la session suivante | `exit`, rouvrir l'onglet Ubuntu (ou `wsl --shutdown`) |
| `The command 'docker' could not be found in this WSL 2 distro` | Intégration WSL désactivée | Docker Desktop › Settings › Resources › WSL integration › `Ubuntu-24.04` |
| Étape 3 : `KO docker indisponible dans Ubuntu-24.04` (Docker Desktop 4.99, session du 23/11) | Réglage écrit par le script perdu au redémarrage de Docker Desktop (intégration « None selected ») | Settings › WSL integration › cocher `Ubuntu-24.04` › **Apply**, puis relancer le script. Script corrigé : arrêt de Docker Desktop avant écriture, puis activation manuelle guidée si la vérification échoue |
| `preflight.sh` : KO sur `*.localhost` (version antérieure au 22/11) | `getent` sans `nss-myhostname` sous WSL | Sans effet : `curl` et les navigateurs résolvent `*.localhost` eux-mêmes |
| Caractères `\| \ # { [` absents à la frappe | Clavier AZERTY + AltGr à travers Guacamole (constaté en saisie automatisée) `[À VÉRIFIER avec un clavier physique]` | Presse-papier Guacamole : `Ctrl+Alt+Maj` › coller le texte › `Ctrl+V` dans le terminal |
| Fenêtre Docker Desktop au premier plan après redémarrage | Comportement de Docker Desktop | Réduire la fenêtre avant de saisir dans le terminal |
| Docker Desktop : « WSL integration with distro 'Ubuntu-24.04' unexpectedly stopped » | Distribution arrêtée (`wsl --terminate`, `wsl --shutdown`) | **Restart the WSL integration** ; éviter `wsl --terminate` pendant la formation |

### Nettoyage du poste (fin de session)
```powershell
wsl -d Ubuntu-24.04 -- bash -lc "cd ~/formation && scripts/setup/nettoyer-poste.sh"
wsl --unregister Ubuntu-24.04
Copy-Item $env:APPDATA\Docker\settings-store.json.avant-formation $env:APPDATA\Docker\settings-store.json
```

## 3. VM Google Cloud (une par stagiaire)

### Prérequis formateur
- Projet GCP dédié à la session, API Compute Engine activée, `gcloud` authentifié (`gcloud auth login`).
- Paramètres dans `scripts/setup/gcp.env` : `GCP_PROJET`, `GCP_ZONE` (défaut `europe-west9-a`), `GCP_TYPE` (`e2-standard-4`), `GCP_SOURCES_SSH` (IP publique du centre de préférence).
- Liste des comptes : `scripts/setup/comptes.txt` (`00` = démonstration).

### Contrôles et provisionnement (ressources PAYANTES)
```bash
scripts/setup/preflight.sh --cloud          # J-7 puis J-1 : quota CPUS, type de machine, réseau
scripts/setup/provision-vm.sh               # J-1 : toutes les VM ; ou provision-vm.sh 03 04
scripts/setup/vm.sh tous --acces            # accès de chaque VM
scripts/setup/vm.sh 03 --tunnel             # commande de tunnel à transmettre au stagiaire 03
```
- `provision-vm.sh` : crée la règle de pare-feu `cicd-formation-ssh` (port 22 seulement), une clé SSH par stagiaire (`scripts/setup/keys/`), la VM (Ubuntu 24.04, 50 Go `pd-balanced`, script de démarrage `startup-script.sh` : Docker CE, `vm.max_map_count`, utilisateur `stagiaire`), copie les fichiers de la formation dans `/opt/formation`, lance `init-env.sh complet`.
- Aucun port applicatif n'est ouvert sur Internet : accès par tunnel SSH (`-L 8080`, `-L 3000`, `-L 9000`, `-L 8025`, `-L 8090`, `-L 8000:localhost:80`).
- Coût : `e2-standard-4` + 50 Go `pd-balanced` en `europe-west9` `[À VÉRIFIER : grille tarifaire GCP du jour]` ; ordre de grandeur 8 à 12 $ par VM pour 5 jours × 10 h, VM arrêtées la nuit (disque toujours facturé).

### Exploitation pendant la session
```bash
scripts/setup/vm.sh tous --demarrer                           # chaque matin, 08:15
scripts/setup/vm.sh tous --arreter                            # chaque soir, 18:00
scripts/setup/vm.sh tous --etat
scripts/setup/vm.sh 03 scripts/m05/catch-up/catch-up.sh       # rattrapage d'un stagiaire
```

## 4. Rattrapages et scripts de labs

| Script | Rôle |
|---|---|
| `scripts/mXX/catch-up/catch-up.sh` | Amène le compte à l'état final du module XX (cumulatif, relançable) |
| `scripts/m01/labs/simuler-collegue.sh` | Merge request concurrente (conflit du lab 01.3) |
| `scripts/m04/labs/installer-depart.sh` | Code livré sans tests + test instable (module 04) |
| `scripts/m07/labs/demo-rolling.sh` | Démonstration rolling update (formateur) |
| `scripts/m08/labs/mesurer-durees.sh` | Durées des builds de `main` |
| `scripts/m09/labs/audit-securite.sh` | Audit de sécurité de Jenkins |
| `scripts/m09/labs/sauvegarde-jenkins.sh`, `restauration-test.sh` | Sauvegarde et restauration testée |
| `scripts/m10/labs/dora.py` | Indicateurs DORA (API Jenkins ou `builds-demo.json`) |
| `scripts/setup/generate-dora-history.sh` | Historique de déploiements (J5, 12:30) |

⚠️ Les rattrapages rechargent JCasC : la liste des credentials système est régénérée (`scripts/lib/commun.sh`, fonction `jenkins_credentials_yaml`) ; un credential système créé à la main disparaît.

## 5. Vérifications

```bash
docker compose -f environnement/compose.yaml ps --format '{{.Service}} {{.Status}}'
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/login      # 200
curl -s http://localhost:3000/api/healthz                                   # "status": "pass"
curl -s http://localhost:9000/api/system/status                             # "status":"UP"
```

## 6. Nettoyage

### Poste local
```bash
scripts/setup/nettoyer-poste.sh              # conteneurs, volumes, images, secrets
scripts/setup/nettoyer-poste.sh --garder-images
```
Ordre appliqué : conteneurs déployés par les pipelines (`scripts/m07/cleanup/cleanup.sh`) → pile et volumes → images listées dans `scripts/setup/images.txt` et images `localhost:3000/dev/fretexpress:*` → fichiers générés.

### Google Cloud (après la session, par le formateur)
```bash
scripts/setup/deprovision-vm.sh              # toutes les VM de comptes.txt + règle de pare-feu
```
- Suppression par nom exact (`cicd-stagiaire-NN`), disques compris (`--delete-disks all`) ; aucune corbeille.
- Contrôle final affiché : instances et disques restants portant le label `formation=cicd-jenkins` (liste vide attendue).
- Projet dédié : le supprimer après vérification de la facture (suppression différée de 30 jours par Google Cloud `[À VÉRIFIER]`).
