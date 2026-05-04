$ErrorActionPreference = "Stop"

Write-Host "FeastOps Kubernetes status"
Write-Host "=========================="

kubectl config current-context
kubectl -n feastops get deploy,svc,pod,pdb -l app.kubernetes.io/part-of=feastops

Write-Host ""
Write-Host "App health:"
$health = Invoke-RestMethod -Uri "http://localhost:31080/health" -TimeoutSec 5
$health | Format-List

Write-Host ""
Write-Host "Deployment evidence from app:"
$status = Invoke-RestMethod -Uri "http://localhost:31080/api/devops/status" -TimeoutSec 5
$status.deployment | Format-List
