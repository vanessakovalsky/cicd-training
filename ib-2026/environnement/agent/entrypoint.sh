#!/bin/sh
# Installe la cle publique du controleur, donne acces au socket Docker, lance sshd.
set -eu
if [ -z "${JENKINS_AGENT_SSH_PUBKEY:-}" ]; then
  echo "JENKINS_AGENT_SSH_PUBKEY absente" >&2
  exit 1
fi
printf '%s\n' "$JENKINS_AGENT_SSH_PUBKEY" > /home/jenkins/.ssh/authorized_keys
chown -R jenkins:jenkins /home/jenkins/.ssh /home/jenkins/.cache /srv/traefik-dynamic
chmod 700 /home/jenkins/.ssh && chmod 600 /home/jenkins/.ssh/authorized_keys

if [ -S /var/run/docker.sock ]; then
  gid=$(stat -c '%g' /var/run/docker.sock)
  if [ "$gid" = "0" ]; then
    chmod 666 /var/run/docker.sock   # Docker Desktop : socket root:root (banc de formation uniquement)
  else
    getent group "$gid" >/dev/null || groupadd -g "$gid" dockerhost
    usermod -aG "$(getent group "$gid" | cut -d: -f1)" jenkins
  fi
fi
[ -f /etc/ssh/ssh_host_ed25519_key ] || ssh-keygen -A
exec /usr/sbin/sshd -D -e
