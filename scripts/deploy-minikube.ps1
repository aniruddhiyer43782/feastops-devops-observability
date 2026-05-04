param(
  [string]$ImageName = "feastops-food-delivery-api:minikube",
  [int]$Replicas = 2,
  [int]$LocalPort = 31080
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$LocalMinikube = Join-Path $ProjectRoot "tools\minikube.exe"
$PortForwardPidFile = Join-Path $ProjectRoot ".minikube-port-forward.pid"

if (Test-Path $LocalMinikube) {
  $Minikube = $LocalMinikube
} elseif (Get-Command minikube -ErrorAction SilentlyContinue) {
  $Minikube = "minikube"
} else {
  throw "Minikube is not installed. Download it to tools\minikube.exe or install it on PATH, then rerun .\scripts\deploy-minikube.cmd."
}

Write-Host "FeastOps Minikube deploy"
Write-Host "========================"

$minikubeStatus = & "$Minikube" status --format "{{.Host}}" 2>$null
if ($minikubeStatus -ne "Running") {
  & "$Minikube" start --driver=docker
} else {
  Write-Host "Minikube is already running."
}
kubectl config use-context minikube
kubectl config set-context --current --namespace=feastops | Out-Null

Write-Host "Using Minikube Docker daemon"
& "$Minikube" -p minikube docker-env --shell powershell | Invoke-Expression

Write-Host "Building image: $ImageName"
docker build -t $ImageName (Join-Path $ProjectRoot "app")

Write-Host "Applying Kubernetes manifests"
kubectl apply -k (Join-Path $ProjectRoot "k8s")
kubectl -n feastops set image deployment/feastops-app "feastops-app=$ImageName"
kubectl -n feastops set env deployment/feastops-app "APP_REPLICAS=$Replicas"
kubectl -n feastops scale deployment/feastops-app --replicas=$Replicas
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

$health = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 5
if ($health.status -ne "ok") {
  throw "The app did not become healthy through localhost:$LocalPort."
}

Write-Host ""
Write-Host "Minikube deployment ready."
Write-Host "Image: $ImageName"
Write-Host "Replicas: $Replicas"
kubectl -n feastops get deploy,svc,pods -l app.kubernetes.io/part-of=feastops -o wide
$minikubeIp = & "$Minikube" ip
Write-Host "Minikube NodePort URL: http://$($minikubeIp):31080"
Write-Host "Windows-friendly URL: http://localhost:$LocalPort"
