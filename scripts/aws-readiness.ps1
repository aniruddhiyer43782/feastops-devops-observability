param(
  [string]$AwsRegion = "us-east-1",
  [string]$RepositoryName = "feastops-food-delivery-api",
  [string]$ImageTag = "latest",
  [string]$ClusterName = "feastops-eks"
)

$ErrorActionPreference = "Stop"

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
$Docker = Resolve-Tool "docker"
$Kubectl = Resolve-Tool "kubectl"

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

Write-Host "FeastOps AWS readiness"
Write-Host "======================"

$caller = Invoke-AwsJson @("sts", "get-caller-identity", "--output", "json")
$accountId = $caller.Account
$repositoryUri = "$accountId.dkr.ecr.$AwsRegion.amazonaws.com/$RepositoryName"

Write-Host "AWS identity: $($caller.Arn)"
Write-Host "AWS region:   $AwsRegion"
Write-Host "ECR image:    $repositoryUri`:$ImageTag"
Write-Host "Docker:       $(& $Docker --version)"
Write-Host "kubectl:      $((& $Kubectl version --client) -join ' ')"

try {
  Invoke-AwsJson @("ecr", "describe-repositories", "--region", $AwsRegion, "--repository-names", $RepositoryName, "--output", "json") | Out-Null
  Write-Host "ECR repository: OK"
} catch {
  Write-Host "ECR repository: MISSING or access denied"
}

try {
  Invoke-AwsJson @("ecr", "describe-images", "--region", $AwsRegion, "--repository-name", $RepositoryName, "--image-ids", "imageTag=$ImageTag", "--output", "json") | Out-Null
  Write-Host "ECR image tag: OK"
} catch {
  Write-Host "ECR image tag: MISSING or access denied"
}

try {
  $clusters = Invoke-AwsJson @("eks", "list-clusters", "--region", $AwsRegion, "--output", "json")
  Write-Host "EKS list-clusters: OK"
  if ($clusters.clusters -contains $ClusterName) {
    Write-Host "EKS cluster ${ClusterName}: FOUND"
  } else {
    Write-Host "EKS cluster ${ClusterName}: NOT FOUND"
  }
} catch {
  Write-Host "EKS list-clusters: BLOCKED"
  Write-Host "Reason: the current IAM principal does not have EKS permissions."
}
