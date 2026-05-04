param(
  [int]$LocalPort = 31080,
  [string]$Name = "feastops-public-tunnel"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$PortForwardPidFile = Join-Path $ProjectRoot ".k8s-port-forward.pid"

try {
  Invoke-RestMethod -Uri "http://localhost:$LocalPort/health" -TimeoutSec 5 | Out-Null
} catch {
  Write-Host "Local app is not reachable yet. Starting Kubernetes port-forward..."
  if (Test-Path $PortForwardPidFile) {
    $oldPid = Get-Content $PortForwardPidFile -ErrorAction SilentlyContinue
    if ($oldPid) {
      Stop-Process -Id $oldPid -ErrorAction SilentlyContinue
    }
    Remove-Item $PortForwardPidFile -ErrorAction SilentlyContinue
  }

  $portForward = Start-Process `
    -FilePath "kubectl" `
    -ArgumentList @("-n", "feastops", "port-forward", "service/feastops-app", "$($LocalPort):80") `
    -WindowStyle Hidden `
    -PassThru
  $portForward.Id | Set-Content $PortForwardPidFile
  Start-Sleep -Seconds 5
  Invoke-RestMethod -Uri "http://localhost:$LocalPort/health" -TimeoutSec 10 | Out-Null
}

$existing = docker ps -a --filter "name=$Name" --format "{{.Names}}"
if ($existing -contains $Name) {
  docker rm -f $Name | Out-Null
}

docker run -d --name $Name cloudflare/cloudflared:latest tunnel --no-autoupdate --url "http://host.docker.internal:$LocalPort" | Out-Null

Write-Host "Waiting for Cloudflare quick tunnel URL..."
for ($attempt = 1; $attempt -le 20; $attempt++) {
  Start-Sleep -Seconds 2
  $logs = cmd /c "docker logs $Name 2>&1"
  $match = $logs | Select-String -Pattern "https://[-a-z0-9]+\.trycloudflare\.com" | Select-Object -Last 1
  if ($match) {
    $url = $match.Matches[0].Value
    Write-Host ""
    Write-Host "Temporary public URL:"
    Write-Host $url
    Write-Host ""
    Write-Host "Keep the Docker tunnel container running while you present."
    exit 0
  }
}

docker logs $Name --tail 80
throw "Cloudflare Tunnel started, but no public URL appeared in the logs."
