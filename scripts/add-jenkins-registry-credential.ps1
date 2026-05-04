param(
  [string]$JenkinsUrl = "http://localhost:8081",
  [string]$JenkinsUser = "admin",
  [string]$JenkinsPassword = "admin",
  [string]$CredentialId = "registry-credentials",
  [Parameter(Mandatory = $true)]
  [string]$RegistryUsername,
  [Parameter(Mandatory = $true)]
  [string]$RegistryToken
)

$ErrorActionPreference = "Stop"

$pair = "${JenkinsUser}:${JenkinsPassword}"
$basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{ Authorization = "Basic $basic" }
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$crumb = Invoke-RestMethod -Uri "$JenkinsUrl/crumbIssuer/api/json" -Headers $headers -WebSession $session
$headers[$crumb.crumbRequestField] = $crumb.crumb

$script = @"
import com.cloudbees.plugins.credentials.CredentialsScope
import com.cloudbees.plugins.credentials.SystemCredentialsProvider
import com.cloudbees.plugins.credentials.domains.Domain
import com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl

String credentialId = '$CredentialId'
String username = '$RegistryUsername'
String token = '$RegistryToken'
def store = SystemCredentialsProvider.getInstance().getStore()
def domain = Domain.global()
def existing = SystemCredentialsProvider.getInstance().getCredentials().find { it.id == credentialId }
def credential = new UsernamePasswordCredentialsImpl(
  CredentialsScope.GLOBAL,
  credentialId,
  'Container registry credentials for FeastOps image publishing',
  username,
  token
)

if (existing != null) {
  store.updateCredentials(domain, existing, credential)
} else {
  store.addCredentials(domain, credential)
}
SystemCredentialsProvider.getInstance().save()
println "Credential saved: " + credentialId
"@

Invoke-RestMethod -Uri "$JenkinsUrl/scriptText" -Method Post -Headers $headers -WebSession $session -Body @{ script = $script }
