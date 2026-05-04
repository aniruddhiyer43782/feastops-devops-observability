param(
  [string]$JenkinsUrl = "http://localhost:8081",
  [string]$JenkinsUser = "admin",
  [string]$JenkinsPassword = "admin",
  [string]$JobName = "feastops-local-ci",
  [string]$RegistryImage = "ghcr.io/aniruddhiyer43782/feastops-food-delivery-api:jenkins",
  [string]$RegistryCredentialsId = "registry-credentials",
  [ValidateSet("true", "false")]
  [string]$PushImage = "true"
)

$ErrorActionPreference = "Stop"

$pair = "${JenkinsUser}:${JenkinsPassword}"
$basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{ Authorization = "Basic $basic" }
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$crumb = Invoke-RestMethod -Uri "$JenkinsUrl/crumbIssuer/api/json" -Headers $headers -WebSession $session
$headers[$crumb.crumbRequestField] = $crumb.crumb

$body = @{
  REGISTRY_IMAGE = $RegistryImage
  REGISTRY_CREDENTIALS_ID = $RegistryCredentialsId
  PUSH_IMAGE = $PushImage
}

$before = Invoke-RestMethod -Uri "$JenkinsUrl/job/$JobName/api/json?tree=lastBuild[number]" -Headers $headers -WebSession $session
$previousBuildNumber = $before.lastBuild.number

$response = Invoke-WebRequest `
  -Uri "$JenkinsUrl/job/$JobName/buildWithParameters" `
  -Method Post `
  -Headers $headers `
  -WebSession $session `
  -Body $body `
  -UseBasicParsing | Out-Null

$queueUrl = $response.Headers.Location
if (-not $queueUrl) {
  $buildNumber = $null
  for ($attempt = 1; $attempt -le 30; $attempt++) {
    $job = Invoke-RestMethod -Uri "$JenkinsUrl/job/$JobName/api/json?tree=lastBuild[number,url]" -Headers $headers -WebSession $session
    if ($job.lastBuild.number -and $job.lastBuild.number -gt $previousBuildNumber) {
      $buildNumber = $job.lastBuild.number
      break
    }
    Start-Sleep -Seconds 2
  }
  if (-not $buildNumber) {
    throw "Jenkins did not start a new build after #$previousBuildNumber."
  }
} else {
  $buildNumber = $null
  for ($attempt = 1; $attempt -le 30; $attempt++) {
    $queue = Invoke-RestMethod -Uri "$($queueUrl)api/json" -Headers $headers -WebSession $session
    if ($queue.executable.number) {
      $buildNumber = $queue.executable.number
      break
    }
    Start-Sleep -Seconds 2
  }
  if (-not $buildNumber) {
    throw "Jenkins queue item did not start a build: $queueUrl"
  }
}

Write-Host "Triggered Jenkins build #$buildNumber"
Write-Host "$JenkinsUrl/job/$JobName/$buildNumber/"

for ($attempt = 1; $attempt -le 90; $attempt++) {
  $build = Invoke-RestMethod -Uri "$JenkinsUrl/job/$JobName/$buildNumber/api/json?tree=number,building,result,url" -Headers $headers -WebSession $session
  if (-not $build.building) {
    $build | ConvertTo-Json -Depth 4
    if ($build.result -ne "SUCCESS") {
      throw "Jenkins build #$buildNumber finished with result $($build.result)"
    }
    exit 0
  }
  Start-Sleep -Seconds 10
}

throw "Jenkins build #$buildNumber is still running after 15 minutes."
