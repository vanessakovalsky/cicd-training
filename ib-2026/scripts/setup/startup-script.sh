#!/bin/bash
# Script de demarrage Compute Engine (execute en root a chaque demarrage). ASCII uniquement.
# Installe Docker Engine + Compose v2, regle vm.max_map_count, cree l'utilisateur stagiaire.
set -eu
if ! command -v docker >/dev/null 2>&1; then
  apt-get update -q
  apt-get install -y -q ca-certificates curl git python3
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  . /etc/os-release
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -q
  apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi
echo 'vm.max_map_count=524288' > /etc/sysctl.d/99-sonarqube.conf
sysctl -q -p /etc/sysctl.d/99-sonarqube.conf
id stagiaire >/dev/null 2>&1 || useradd --create-home --shell /bin/bash stagiaire
usermod -aG docker stagiaire   # aussi si l agent invite Google a cree le compte avant
mkdir -p /opt/formation && chown stagiaire:stagiaire /opt/formation
touch /var/run/formation-pret
