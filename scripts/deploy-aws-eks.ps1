param(
  [string]$AwsRegion = "ap-south-1",
  [string]$ClusterName = "feastops-eks",
  [string]$RepositoryName = "feastops-food-delivery-api"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

foreach ($tool in @("aws", "kubectl", "docker")) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    throw "$tool is not installed or not on PATH."
  }
}

$caller = aws sts get-caller-identity --output json | ConvertFrom-Json
$accountId = $caller.Account
$registry = "$accountId.dkr.ecr.$AwsRegion.amazonaws.com"
$imageTag = "aws-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$imageUri = "$registry/$RepositoryName`:$imageTag"

Write-Host "FeastOps AWS EKS deploy"
Write-Host "======================="
Write-Host "AWS account: $accountId"
Write-Host "AWS region:  $AwsRegion"
Write-Host "EKS cluster: $ClusterName"

aws ecr describe-repositories --region $AwsRegion --repository-names $RepositoryName *> $null
if ($LASTEXITCODE -ne 0) {
  aws ecr create-repository --region $AwsRegion --repository-name $RepositoryName | Out-Null
}

aws ecr get-login-password --region $AwsRegion | docker login --username AWS --password-stdin $registry

docker build -t $imageUri (Join-Path $ProjectRoot "app")
docker push $imageUri

aws eks update-kubeconfig --region $AwsRegion --name $ClusterName
kubectl apply -k (Join-Path $ProjectRoot "k8s\aws")
kubectl -n feastops set image deployment/feastops-app "feastops-app=$imageUri"
kubectl -n feastops set env deployment/feastops-app PUBLIC_APP_URL="pending-aws-load-balancer"
kubectl -n feastops rollout status deployment/feastops-app --timeout=300s

Write-Host "Waiting for AWS LoadBalancer hostname"
for ($attempt = 1; $attempt -le 60; $attempt++) {
  $hostName = kubectl -n feastops get svc feastops-app-public -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null
  if ($hostName) {
    Write-Host ""
    Write-Host "Public AWS URL:"
    Write-Host "http://$hostName"
    exit 0
  }
  Start-Sleep -Seconds 10
}

kubectl -n feastops get svc feastops-app-public
throw "AWS LoadBalancer was created but no public hostname was assigned within the wait window."
