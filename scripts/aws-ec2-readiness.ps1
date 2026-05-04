param(
  [string]$AwsRegion = "us-east-1",
  [string]$RepositoryName = "feastops-food-delivery-api",
  [string]$ImageTag = "latest"
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

function Test-AwsCommand {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & $Aws @Arguments 2>&1
  $ErrorActionPreference = $previousPreference
  if ($LASTEXITCODE -eq 0) {
    Write-Host "${Name}: OK"
    return $true
  }

  Write-Host "${Name}: BLOCKED"
  $cleanOutput = $output | ForEach-Object {
    $text = "$_"
    if ($text -and $text -ne "System.Management.Automation.RemoteException") {
      $text
    }
  }
  Write-Host ($cleanOutput -join "`n")
  return $false
}

Write-Host "FeastOps AWS EC2 readiness"
Write-Host "=========================="
Test-AwsCommand "AWS identity" @("sts", "get-caller-identity", "--output", "json") | Out-Null
Test-AwsCommand "ECR image" @("ecr", "describe-images", "--region", $AwsRegion, "--repository-name", $RepositoryName, "--image-ids", "imageTag=$ImageTag", "--output", "json") | Out-Null
Test-AwsCommand "EC2 describe regions" @("ec2", "describe-regions", "--region", $AwsRegion, "--region-names", $AwsRegion, "--output", "json") | Out-Null
Test-AwsCommand "EC2 default VPC lookup" @("ec2", "describe-vpcs", "--region", $AwsRegion, "--filters", "Name=is-default,Values=true", "--output", "json") | Out-Null
Test-AwsCommand "SSM latest Amazon Linux AMI lookup" @("ssm", "get-parameter", "--region", $AwsRegion, "--name", "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64", "--output", "json") | Out-Null
Test-AwsCommand "IAM role lookup/setup permission" @("iam", "get-role", "--role-name", "feastops-ec2-ecr-role", "--output", "json") | Out-Null

Write-Host ""
Write-Host "If EC2/IAM/SSM commands are blocked, attach docs/aws-ec2-permissions.json to the AWS principal or use a profile with equivalent permissions."
