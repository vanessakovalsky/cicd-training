# Preparation d'un poste Windows 11 (Docker Desktop + WSL 2) pour la formation CI/CD.
# Valide le 22/11/2026 sur un poste de salle virtuelle (Guacamole, Windows 11 Entreprise,
# Docker Desktop 4.93 / Engine 29.8, session non elevee, sans Git ni Python cote Windows).
#
# Etapes (relancable, chaque etape deja faite est sautee) :
#   1. Docker Desktop demarre (moteur WSL 2)
#   2. Distribution Ubuntu-24.04 installee dans WSL (sans droits administrateur)
#      -> premier demarrage INTERACTIF : saisir l'utilisateur "stagiaire" et un mot de passe, puis "exit"
#   3. Integration WSL de Docker Desktop activee pour Ubuntu-24.04 (redemarrage de Docker Desktop)
#   4. Ubuntu : sudo sans mot de passe, groupe docker, distribution par defaut
#      (jamais de "wsl --terminate" : il coupe l'integration Docker Desktop, qui demande alors
#       un redemarrage manuel ; systemd inutile pour la pile)
#   5. Depot de la formation clone dans ~/formation (Ubuntu)
#
# Usage (PowerShell, session normale) :
#   powershell -ExecutionPolicy Bypass -File preparer-poste.ps1
#   powershell -ExecutionPolicy Bypass -File preparer-poste.ps1 -Demarrer   # + preflight et pile complete
# Pas d'accent dans ce fichier : PowerShell 5.1 lit les .ps1 sans BOM en ANSI.
param(
    [string]$Distro = "Ubuntu-24.04",
    [string]$Utilisateur = "stagiaire",
    [string]$Depot = "https://github.com/vanessakovalsky/cicd-training.git",
    [string]$Dossier = "ib-2026",
    [switch]$Demarrer
)
$ErrorActionPreference = "Stop"
function Etape($m) { Write-Host "`n== $m" -ForegroundColor Cyan }
function Ok($m)    { Write-Host "  OK  $m" -ForegroundColor Green }
function Ko($m)    { Write-Host "  KO  $m" -ForegroundColor Red; exit 1 }
# wsl.exe ecrit en UTF-16 : suppression des caracteres nuls
# (stderr d'un programme externe + ErrorActionPreference Stop = erreur bloquante sous PowerShell 5.1)
function Wsl-Texte { $ErrorActionPreference = "Continue"; (& wsl.exe @args 2>&1 | Out-String) -replace "`0", "" }
function Wsl-Root($cmd) { & wsl.exe -d $Distro -u root -- bash -lc $cmd; if ($LASTEXITCODE -ne 0) { Ko "commande root : $cmd" } }

$DockerExe = Join-Path $env:ProgramFiles "Docker\Docker\resources\bin\docker.exe"
if (-not (Test-Path $DockerExe)) { Ko "Docker Desktop absent : a installer par l'organisme de formation" }

Etape "1. Docker Desktop"
& $DockerExe info *> $null
if ($LASTEXITCODE -ne 0) {
    & $DockerExe desktop start | Out-Null
    for ($i = 0; $i -lt 60; $i++) { & $DockerExe info *> $null; if ($LASTEXITCODE -eq 0) { break }; Start-Sleep 5 }
}
& $DockerExe info *> $null
if ($LASTEXITCODE -ne 0) { Ko "le moteur Docker ne repond pas (lancer Docker Desktop a la main)" }
Ok ("moteur Docker " + (& $DockerExe version --format "{{.Server.Version}}"))

Etape "2. Distribution $Distro"
$liste = Wsl-Texte -l -q
$nouvelle = $liste -notmatch [regex]::Escape($Distro)
if ($nouvelle) {
    & wsl.exe --install -d $Distro --no-launch
    if ($LASTEXITCODE -ne 0) { Ko "installation de $Distro" }
}
Ok "$Distro installee"
# Tout premier lancement (meme avec -u root) = assistant interactif de creation du compte :
# il est lance au premier plan, jamais dans une commande dont la sortie est capturee.
$deja = if ($nouvelle) { "" } else { (Wsl-Texte -d $Distro -u root -- id -u $Utilisateur).Trim() }
if ($deja -notmatch '^\d+$') {
    Write-Host ""
    Write-Host "  Premier demarrage d'Ubuntu (interactif) :" -ForegroundColor Yellow
    Write-Host "    - nom d'utilisateur : $Utilisateur" -ForegroundColor Yellow
    Write-Host "    - mot de passe      : au choix (saisi deux fois, rien ne s'affiche)" -ForegroundColor Yellow
    Write-Host "    - puis taper : exit" -ForegroundColor Yellow
    & wsl.exe -d $Distro
    $deja = (Wsl-Texte -d $Distro -u root -- id -u $Utilisateur).Trim()
    if ($deja -notmatch '^\d+$') { Ko "utilisateur $Utilisateur absent dans $Distro (relancer le script)" }
}
Ok "utilisateur $Utilisateur"

Etape "3. Integration WSL de Docker Desktop"
$reglages = Join-Path $env:APPDATA "Docker\settings-store.json"
$json = if (Test-Path $reglages) { Get-Content $reglages -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
$actuelles = @($json.IntegratedWslDistros)
if ($actuelles -notcontains $Distro) {
    Copy-Item $reglages "$reglages.avant-formation" -ErrorAction SilentlyContinue
    $json | Add-Member -Force -NotePropertyName IntegratedWslDistros -NotePropertyValue (@($actuelles | Where-Object { $_ }) + $Distro)
    $json | Add-Member -Force -NotePropertyName EnableIntegrationWithDefaultWslDistro -NotePropertyValue $true
    # UTF-8 sans BOM (Set-Content -Encoding UTF8 de PowerShell 5.1 ajoute un BOM)
    [IO.File]::WriteAllText($reglages, ($json | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding $false))
    & $DockerExe desktop restart | Out-Null
    Start-Sleep 20
}
for ($i = 0; $i -lt 40; $i++) {
    $v = (Wsl-Texte -d $Distro -u root -- sh -c "docker version --format '{{.Server.Version}}' 2>/dev/null").Trim()
    if ($v -match '^\d') { break }; Start-Sleep 5
}
if ($v -notmatch '^\d') { Ko "docker indisponible dans $Distro (Docker Desktop > Settings > Resources > WSL integration)" }
Ok "docker $v dans $Distro"

Etape "4. Configuration d'Ubuntu"
Wsl-Root "echo '$Utilisateur ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$Utilisateur && chmod 440 /etc/sudoers.d/$Utilisateur"
Wsl-Root "getent group docker >/dev/null || groupadd docker; usermod -aG docker $Utilisateur"
& wsl.exe --set-default $Distro | Out-Null
# chaque nouvel appel wsl.exe ouvre une session qui relit les groupes
for ($i = 0; $i -lt 12; $i++) {
    $test = (Wsl-Texte -d $Distro -u $Utilisateur -- sh -c "docker ps >/dev/null 2>&1 && echo docker-ok").Trim()
    if ($test -match 'docker-ok') { break }; Start-Sleep 5
}
if ($test -notmatch 'docker-ok') { Ko "$Utilisateur n'accede pas a docker (fermer les onglets Ubuntu, relancer le script)" }
Ok "$Utilisateur : sudo, groupe docker, distribution par defaut"

Etape "5. Depot de la formation"
& wsl.exe -d $Distro -u $Utilisateur --cd "~" -- bash -lc "test -d ~/cicd-training/.git && git -C ~/cicd-training pull -q || git clone -q --depth 1 $Depot ~/cicd-training; ln -sfn ~/cicd-training/$Dossier ~/formation; ls ~/formation/scripts/setup/init-env.sh"
if ($LASTEXITCODE -ne 0) { Ko "clone de $Depot" }
Ok "~/formation -> ~/cicd-training/$Dossier"

if ($Demarrer) {
    Etape "6. Controles et demarrage de la pile (5 a 10 min)"
    & wsl.exe -d $Distro -u $Utilisateur --cd "~" -- bash -lc "cd ~/formation && scripts/setup/preflight.sh && scripts/setup/init-env.sh complet && cat environnement/acces.txt"
    if ($LASTEXITCODE -ne 0) { Ko "preflight ou demarrage de la pile" }
}

Write-Host "`nPoste pret. Terminal Ubuntu : menu de Windows Terminal (fleche v) > $Distro, puis : cd ~/formation" -ForegroundColor Green
Write-Host "Alerte du pare-feu Windows pour Docker Desktop Backend : cliquer Annuler (acces localhost suffisant)." -ForegroundColor Yellow
