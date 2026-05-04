param(
  [string]$Name = "feastops-jenkins-webhook-tunnel",
  [int]$JenkinsPort = 8081
)

$ErrorActionPreference = "Stop"

$existing = docker ps -a --filter "name=$Name" --format "{{.Names}}"
if ($existing -contains $Name) {
  docker rm -f $Name | Out-Null
}

docker run -d --name $Name cloudflare/cloudflared:latest tunnel --no-autoupdate --url "http://host.docker.internal:$JenkinsPort" | Out-Null

Write-Host "Waiting for Jenkins public webhook URL..."
for ($attempt = 1; $attempt -le 20; $attempt++) {
  Start-Sleep -Seconds 2
  $logs = cmd /c "docker logs $Name 2>&1"
  $match = $logs | Select-String -Pattern "https://[-a-z0-9]+\.trycloudflare\.com" | Select-Object -Last 1
  if ($match) {
    $url = $match.Matches[0].Value
    Write-Host ""
    Write-Host "Temporary Jenkins URL:"
    Write-Host $url
    Write-Host ""
    Write-Host "GitHub webhook payload URL:"
    Write-Host "$url/github-webhook/"
    Write-Host ""
    Write-Host "Keep this Docker tunnel container running while webhook auto-builds are needed."
    exit 0
  }
}

docker logs $Name --tail 80
throw "Cloudflare Tunnel started, but no public Jenkins URL appeared in the logs."
