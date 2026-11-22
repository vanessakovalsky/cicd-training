// Mail a l'equipe selon le resultat : ECHEC (failure) ou REPARE (fixed).
def call(String etat, String destinataires = 'equipe@fretexpress.localhost') {
    def sujet = (etat == 'fixed') ? 'REPARE' : 'ECHEC'
    mail to: destinataires,
         subject: "${sujet} ${env.JOB_NAME} #${env.BUILD_NUMBER}",
         body: "${sujet} : ${env.BUILD_URL}console"
}
