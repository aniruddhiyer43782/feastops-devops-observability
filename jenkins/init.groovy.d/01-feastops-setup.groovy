import hudson.security.FullControlOnceLoggedInAuthorizationStrategy
import hudson.security.HudsonPrivateSecurityRealm
import hudson.security.HudsonPrivateSecurityRealm.Details
import com.coravy.hudson.plugins.github.GithubProjectProperty
import hudson.plugins.git.BranchSpec
import hudson.plugins.git.GitSCM
import hudson.plugins.git.UserRemoteConfig
import jenkins.model.Jenkins
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import org.jenkinsci.plugins.workflow.job.WorkflowJob

def jenkins = Jenkins.get()
def realm = jenkins.getSecurityRealm()

if (!(realm instanceof HudsonPrivateSecurityRealm)) {
  realm = new HudsonPrivateSecurityRealm(false)
  jenkins.setSecurityRealm(realm)
}

def adminUser = realm.allUsers.find { it.id == "admin" } ?: realm.createAccount("admin", "admin")
adminUser.addProperty(Details.fromPlainPassword("admin"))
jenkins.setSecurityRealm(realm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
jenkins.setAuthorizationStrategy(strategy)

def jobName = "feastops-local-ci"
def existingJob = jenkins.getItem(jobName)
def repoUrl = "https://github.com/aniruddhiyer43782/feastops-devops-observability.git"
def scm = new GitSCM(
  [new UserRemoteConfig(repoUrl, null, null, null)],
  [new BranchSpec("*/main")],
  false,
  [],
  null,
  null,
  []
)
def definition = new CpsScmFlowDefinition(scm, "Jenkinsfile")
definition.setLightweight(true)

def job = existingJob ?: jenkins.createProject(WorkflowJob, jobName)
job.setDefinition(definition)
job.setDescription("CI/CD pipeline for FeastOps. Builds from GitHub main, supports push webhooks, Sonar Quality Gate, Docker image smoke test, and registry publishing.")
job.removeProperty(GithubProjectProperty)
job.addProperty(new GithubProjectProperty("https://github.com/aniruddhiyer43782/feastops-devops-observability/"))
job.save()

job.getBuilds().findAll { it.isBuilding() }.each { build ->
  build.doKill()
}

def hasSuccessfulBuild = job.getBuilds().any { !it.isBuilding() && it.getResult()?.toString() == "SUCCESS" }

if (!hasSuccessfulBuild) {
  job.scheduleBuild2(20)
}

jenkins.save()
