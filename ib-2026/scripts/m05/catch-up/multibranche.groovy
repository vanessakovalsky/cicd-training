// Job multibranche "fretexpress" sur le depot Gitea dev/fretexpress (idempotent).
import jenkins.model.Jenkins
import jenkins.branch.BranchSource
import org.jenkinsci.plugin.gitea.GiteaSCMSource
import org.jenkinsci.plugin.gitea.BranchDiscoveryTrait
import org.jenkinsci.plugin.gitea.OriginPullRequestDiscoveryTrait
import org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject

def j = Jenkins.get()
def projet = j.getItem("fretexpress") ?: j.createProject(WorkflowMultiBranchProject, "fretexpress")
def source = new GiteaSCMSource("http://gitea:3000", "dev", "fretexpress")
source.setCredentialsId("gitea-dev")
source.setTraits([new BranchDiscoveryTrait(1), new OriginPullRequestDiscoveryTrait(1)])
projet.getSourcesList().clear()
projet.getSourcesList().add(new BranchSource(source))
projet.save()
projet.scheduleBuild2(0)
println "multibranche fretexpress pret (scan lance)"
