// Deploie une version : cible 'int' ou 'recette' (remplacement), 'prod' (blue/green).
// Le compte du registre en lecture seule est injecte le temps du deploiement.
def call(String cible, String version) {
    def script = (cible == 'prod') ? "deploy/blue-green.sh '${version}'"
                                   : "deploy/deployer.sh '${cible}' '${version}'"
    withCredentials([usernamePassword(credentialsId: 'registre-lecture',
            usernameVariable: 'REGISTRE_USER', passwordVariable: 'REGISTRE_TOKEN')]) {
        retry(2) {
            sh script
        }
    }
    if (cible == 'prod') {
        currentBuild.description = "deploy-prod ${version}"
    }
}
