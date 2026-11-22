// Audit de securite de l'instance (console de scripts, droits admin). Sortie OK / KO.
import jenkins.model.Jenkins
import hudson.security.csrf.DefaultCrumbIssuer
import com.cloudbees.plugins.credentials.SystemCredentialsProvider
import com.cloudbees.plugins.credentials.CredentialsScope

def j = Jenkins.get()
def ko = 0
def verifier = { boolean ok, String libelle, String correctif ->
    println((ok ? "OK  " : "KO  ") + libelle + (ok ? "" : "  -> " + correctif))
    if (!ok) { ko++ }
}

verifier(j.numExecutors == 0, "Executeurs du controleur : ${j.numExecutors}",
         "Built-In Node > Number of executors = 0")
def strategie = j.authorizationStrategy.class.simpleName
verifier(!(strategie in ['Unsecured', 'FullControlOnceLoggedInAuthorizationStrategy']),
         "Strategie d'autorisation : ${strategie}", "matrice ou Role-based Strategy")
def anonyme = j.authorizationStrategy.getACL(j).hasPermission2(
        Jenkins.ANONYMOUS2, Jenkins.READ)
verifier(!anonyme, "Lecture anonyme desactivee", "retirer Overall/Read a anonymous")
verifier(j.crumbIssuer instanceof DefaultCrumbIssuer, "Protection CSRF active", "Security > CSRF Protection")
verifier(j.markupFormatter.class.simpleName == 'EscapedMarkupFormatter',
         "Formateur de texte : ${j.markupFormatter.class.simpleName}", "Plain text")
def utilisateurs = hudson.model.User.getAll().collect { it.id } - ['SYSTEM']
verifier(utilisateurs.size() > 1, "Comptes nominatifs : ${utilisateurs.join(', ')}",
         "un compte par personne, pas de compte admin partage")
def globaux = SystemCredentialsProvider.instance.credentials.findAll { it.scope == CredentialsScope.GLOBAL }
println "INFO Credentials de portee GLOBAL : ${globaux.collect { it.id }.join(', ') ?: 'aucun'}"
def avis = j.getExtensionList(jenkins.security.UpdateSiteWarningsMonitor)[0]
def plugins = avis?.activePluginWarningsByPlugin?.keySet()?.collect { it.shortName } ?: []
verifier(plugins.isEmpty(), "Plugins sans avis de securite actif",
         "mettre a jour : ${plugins.join(', ')}")
def audit = j.pluginManager.getPlugin('audit-trail')
def journal = new File(j.rootDir, 'audit/audit.log.0')
verifier(audit != null && journal.exists(), "Journal d'audit : ${journal.parent}/audit.log",
         "plugin Audit Trail, logger fichier")
println "Resultat : ${ko} KO"
