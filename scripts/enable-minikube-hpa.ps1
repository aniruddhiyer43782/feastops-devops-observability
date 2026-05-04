$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$LocalMinikube = Join-Path $ProjectRoot "tools\minikube.exe"

if (Test-Path $LocalMinikube) {
  $Minikube = $LocalMinikube
} elseif (Get-Command minikube -ErrorAction SilentlyContinue) {
  $Minikube = "minikube"
} else {
  throw "Minikube is not installed. Download it to tools\minikube.exe or install it on PATH."
}

Write-Host "Enabling Minikube metrics-server for HPA"
Write-Host "======================================="
& "$Minikube" addons enable metrics-server
kubectl -n kube-system rollout status deployment/metrics-server --timeout=180s
kubectl -n feastops get hpa
