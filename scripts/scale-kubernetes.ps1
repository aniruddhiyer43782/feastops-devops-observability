param(
  [Parameter(Mandatory = $true)]
  [ValidateRange(1, 10)]
  [int]$Replicas
)

$ErrorActionPreference = "Stop"

Write-Host "Scaling FeastOps on Kubernetes"
Write-Host "=============================="
Write-Host "Target replicas: $Replicas"

kubectl -n feastops set env deployment/feastops-app "APP_REPLICAS=$Replicas"
kubectl -n feastops scale deployment/feastops-app --replicas=$Replicas
kubectl -n feastops rollout status deployment/feastops-app --timeout=180s

Write-Host ""
kubectl -n feastops get deploy,svc,pods -l app.kubernetes.io/part-of=feastops -o wide

Write-Host ""
Write-Host "Scale operation complete."
