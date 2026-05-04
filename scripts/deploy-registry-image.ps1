param(
  [Parameter(Mandatory = $true)]
  [string]$RegistryImage,

  [int]$Replicas = 2,
  [int]$LocalPort = 31080
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$PortForwardPidFile = Join-Path $ProjectRoot ".k8s-port-forward.pid"

Write-Host "Deploying FeastOps from registry image"
Write-Host "======================================"
Write-Host "Image: $RegistryImage"

kubectl apply -k (Join-Path $ProjectRoot "k8s")
kubectl -n feastops set image deployment/feastops-app "feastops-app=$RegistryImage"
kubectl -n feastops set env deployment/feastops-app "APP_REPLICAS=$Replicas"
kubectl -n feastops scale deployment/feastops-app --replicas=$Replicas
kubectl -n feastops rollout status deployment/feastops-app --timeout=180s

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

Write-Host "Waiting for http://localhost:$LocalPort/health"
for ($attempt = 1; $attempt -le 30; $attempt++) {
  try {
    $health = Invoke-RestMethod -Uri "http://localhost:$LocalPort/health" -TimeoutSec 2
    if ($health.status -eq "ok") {
      break
    }
  } catch {
    Start-Sleep -Seconds 2
  }
}

$health = Invoke-RestMethod -Uri "http://localhost:$LocalPort/health" -TimeoutSec 5
if ($health.status -ne "ok") {
  throw "Registry-image deployment did not become healthy."
}

kubectl -n feastops get deploy,svc,pods,hpa -o wide
Write-Host ""
Write-Host "Registry-image Kubernetes app: http://localhost:$LocalPort"
