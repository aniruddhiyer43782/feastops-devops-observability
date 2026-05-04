import hudson.security.FullControlOnceLoggedInAuthorizationStrategy
import hudson.security.HudsonPrivateSecurityRealm
import hudson.security.HudsonPrivateSecurityRealm.Details
import jenkins.model.Jenkins
import org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition
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
def pipelineFile = new File("/workspace/feastops/Jenkinsfile")
def pipelineScript = pipelineFile.exists() ? pipelineFile.text : """
pipeline {
  agent any
  stages {
    stage('Workspace Check') {
      steps {
        error 'Jenkinsfile not found at /workspace/feastops/Jenkinsfile'
      }
    }
  }
}
"""

def job = existingJob ?: jenkins.createProject(WorkflowJob, jobName)
job.setDefinition(new CpsFlowDefinition(pipelineScript, true))
job.setDescription("Local CI/CD pipeline for FeastOps. Reads /workspace/feastops/Jenkinsfile, supports GitHub push webhooks, Sonar Quality Gate, Docker image smoke test, and registry publishing.")
job.save()

job.getBuilds().findAll { it.isBuilding() }.each { build ->
  build.doKill()
}

def hasSuccessfulBuild = job.getBuilds().any { !it.isBuilding() && it.getResult()?.toString() == "SUCCESS" }

if (!hasSuccessfulBuild) {
  job.scheduleBuild2(20)
}

jenkins.save()
