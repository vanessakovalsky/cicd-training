# Agent Jenkins SSH : Python 3.12, Java 21 (requis par l'agent), client Docker, sonar-scanner.
FROM eclipse-temurin:21-jre AS java

FROM python:3.12-slim-bookworm
ARG DOCKER_CLI_VERSION=27.5.1
ARG SONAR_SCANNER_VERSION=7.1.0.4889

COPY --from=java /opt/java/openjdk /opt/java/openjdk
ENV JAVA_HOME=/opt/java/openjdk

RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-server git curl unzip ca-certificates jq \
 && rm -rf /var/lib/apt/lists/* \
 && ln -s /opt/java/openjdk/bin/java /usr/local/bin/java \
 && curl -fsSL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_CLI_VERSION}.tgz" \
    | tar xz --strip-components=1 -C /usr/local/bin docker/docker \
 && curl -fsSL -o /tmp/scanner.zip \
    "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}.zip" \
 && unzip -q /tmp/scanner.zip -d /opt && rm /tmp/scanner.zip \
 && ln -s /opt/sonar-scanner-${SONAR_SCANNER_VERSION}/bin/sonar-scanner /usr/local/bin/sonar-scanner \
 && useradd --create-home --shell /bin/bash --uid 1000 jenkins \
 && mkdir -p /home/jenkins/agent /home/jenkins/.cache /home/jenkins/.ssh /run/sshd /srv/traefik-dynamic \
 && chown -R jenkins:jenkins /home/jenkins /srv/traefik-dynamic \
 && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

# Les URL de clonage annoncees par Gitea (http://localhost:3000/...) pointent vers le conteneur gitea
RUN git config --system url."http://gitea:3000/".insteadOf "http://localhost:3000/"

# Variables visibles dans les sessions SSH de Jenkins
RUN printf 'JAVA_HOME=/opt/java/openjdk\nPIP_DISABLE_PIP_VERSION_CHECK=1\n' >> /etc/environment

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
EXPOSE 22
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
