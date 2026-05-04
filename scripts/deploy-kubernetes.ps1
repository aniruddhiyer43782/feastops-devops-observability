param(
  [string]$ImageName = "",
  [int]$LocalPort = 31080
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$PortForwardPidFile = Join-Path $ProjectRoot ".k8s-port-forward.pid"
if (-not $ImageName) {
  $ImageName = "feastops-food-delivery-api:k8s-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
}

Write-Host "FeastOps Kubernetes deploy"
Write-Host "==========================="

$context = kubectl config current-context 2>$null
if (-not $context) {
  throw "No Kubernetes context is selected. Enable Docker Desktop Kubernetes, minikube, kind, or select a cloud context first."
}

Write-Host "Using Kubernetes context: $context"
Write-Host "Building image: $ImageName"
docker build -t $ImageName (Join-Path $ProjectRoot "app")

Write-Host "Applying manifests from ./k8s"
kubectl apply -k (Join-Path $ProjectRoot "k8s")
kubectl -n feastops set image deployment/feastops-app "feastops-app=$ImageName"

Write-Host "Waiting for rollout"
kubectl -n feastops rollout status deployment/feastops-app --timeout=180s

Write-Host "Refreshing localhost port-forward on port $LocalPort"
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

Write-Host "Waiting for app health through localhost:$LocalPort"
$healthUrl = "http://localhost:$LocalPort/health"
$statusUrl = "http://localhost:$LocalPort/api/devops/status"
for ($attempt = 1; $attempt -le 30; $attempt++) {
  try {
    $health = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 2
    if ($health.status -eq "ok") {
      break
    }
  } catch {
    Start-Sleep -Seconds 2
  }
}

$deploymentStatus = Invoke-RestMethod -Uri $statusUrl -TimeoutSec 5
if ($deploymentStatus.deployment.target -ne "kubernetes") {
  throw "The app responded, but it did not report Kubernetes deployment mode."
}

Write-Host ""
Write-Host "Deployment ready."
Write-Host "Kubernetes URL: http://localhost:$LocalPort"
Write-Host "Namespace: feastops"
Write-Host "Deployment: feastops-app"
Write-Host "Replicas: 2"
Write-Host "Current pod shown by app: $($deploymentStatus.deployment.podName)"
