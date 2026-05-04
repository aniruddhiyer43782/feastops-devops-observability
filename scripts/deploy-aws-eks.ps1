param(
  [string]$AwsRegion = "us-east-1",
  [string]$ClusterName = "feastops-eks",
  [string]$RepositoryName = "feastops-food-delivery-api",
  [string]$ImageTag = "latest"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-Tool {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [string[]]$Fallbacks = @()
  )

  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  foreach ($fallback in $Fallbacks) {
    if (Test-Path $fallback) {
      return $fallback
    }
  }

  throw "$Name is not installed or not on PATH."
}

$Aws = Resolve-Tool "aws" @("C:\Program Files\Amazon\AWSCLIV2\aws.exe")
$Kubectl = Resolve-Tool "kubectl"
$Docker = Resolve-Tool "docker"

function Invoke-AwsJson {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  $output = & $Aws @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw ($output -join "`n")
  }

  return $output | ConvertFrom-Json
}

function Invoke-Native {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$FilePath failed with exit code $LASTEXITCODE"
  }
}

$caller = Invoke-AwsJson @("sts", "get-caller-identity", "--output", "json")
$accountId = $caller.Account
$registry = "$accountId.dkr.ecr.$AwsRegion.amazonaws.com"
$imageUri = "$registry/$RepositoryName`:$ImageTag"

Write-Host "FeastOps AWS EKS deploy"
Write-Host "======================="
Write-Host "AWS account: $accountId"
Write-Host "AWS region:  $AwsRegion"
Write-Host "EKS cluster: $ClusterName"
Write-Host "ECR image:   $imageUri"

try {
  Invoke-AwsJson @("ecr", "describe-repositories", "--region", $AwsRegion, "--repository-names", $RepositoryName, "--output", "json") | Out-Null
} catch {
  Invoke-Native $Aws @("ecr", "create-repository", "--region", $AwsRegion, "--repository-name", $RepositoryName)
}

$existingImage = $null
try {
  $existingImage = Invoke-AwsJson @("ecr", "describe-images", "--region", $AwsRegion, "--repository-name", $RepositoryName, "--image-ids", "imageTag=$ImageTag", "--output", "json")
} catch {
  $existingImage = $null
}

if (-not $existingImage) {
  Write-Host "ECR tag $ImageTag was not found. Building and pushing it now."
  & $Aws ecr get-login-password --region $AwsRegion | & $Docker login --username AWS --password-stdin $registry
  if ($LASTEXITCODE -ne 0) {
    throw "Docker login to ECR failed."
  }
  Invoke-Native $Docker @("build", "-t", $imageUri, (Join-Path $ProjectRoot "app"))
  Invoke-Native $Docker @("push", $imageUri)
} else {
  Write-Host "Using existing ECR image: $imageUri"
}

Invoke-Native $Aws @("eks", "update-kubeconfig", "--region", $AwsRegion, "--name", $ClusterName)

$currentContext = & $Kubectl config current-context
if ($LASTEXITCODE -ne 0 -or $currentContext -notmatch [regex]::Escape($ClusterName)) {
  throw "kubectl is not pointing at the expected EKS cluster context after update-kubeconfig. Current context: $currentContext"
}

Invoke-Native $Kubectl @("apply", "-k", (Join-Path $ProjectRoot "k8s\aws"))
Invoke-Native $Kubectl @("-n", "feastops", "set", "image", "deployment/feastops-app", "feastops-app=$imageUri")
Invoke-Native $Kubectl @("-n", "feastops", "set", "env", "deployment/feastops-app", "PUBLIC_APP_URL=pending-aws-load-balancer")
Invoke-Native $Kubectl @("-n", "feastops", "rollout", "status", "deployment/feastops-app", "--timeout=300s")

Write-Host "Waiting for AWS LoadBalancer hostname"
for ($attempt = 1; $attempt -le 60; $attempt++) {
  $hostName = & $Kubectl -n feastops get svc feastops-app-public -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null
  if ($hostName) {
    Write-Host ""
    Write-Host "Public AWS URL:"
    Write-Host "http://$hostName"
    exit 0
  }
  Start-Sleep -Seconds 10
}

Invoke-Native $Kubectl @("-n", "feastops", "get", "svc", "feastops-app-public")
throw "AWS LoadBalancer was created but no public hostname was assigned within the wait window."
