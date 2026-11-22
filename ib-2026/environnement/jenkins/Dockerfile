FROM jenkins/jenkins:2.580.2-lts-jdk21
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
# Les URL de clonage annoncees par Gitea (http://localhost:3000/...) pointent vers le conteneur gitea
USER root
RUN git config --system url."http://gitea:3000/".insteadOf "http://localhost:3000/"
USER jenkins
