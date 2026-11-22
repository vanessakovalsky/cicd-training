// Cree ou met a jour le job freestyle "premier-job" du lab 2.2 (idempotent).
import jenkins.model.Jenkins
import hudson.model.FreeStyleProject
import hudson.plugins.git.GitSCM
import hudson.plugins.git.BranchSpec
import hudson.plugins.git.UserRemoteConfig
import hudson.tasks.Shell
import hudson.model.labels.LabelAtom

def j = Jenkins.get()
def job = j.getItem("premier-job") ?: j.createProject(FreeStyleProject, "premier-job")
job.setDescription("Lab 2.2 : recupere fretexpress depuis Gitea et lance les tests")
job.setAssignedLabel(new LabelAtom("python"))
job.setScm(new GitSCM(
    [new UserRemoteConfig("http://localhost:3000/dev/fretexpress.git", null, null, null)],
    [new BranchSpec("*/main")], null, null, []))
job.getBuildersList().clear()
job.getBuildersList().add(new Shell('''python3 -m venv .venv
. .venv/bin/activate
pip install --quiet -e ".[dev]"
pytest -v'''))
job.save()
println "premier-job pret"
