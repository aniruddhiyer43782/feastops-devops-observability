param(
  [string]$AwsRegion = "us-east-1",
  [string]$RepositoryName = "feastops-food-delivery-api",
  [string]$ImageTag = "latest",
  [string]$InstanceType = "t3.micro",
  [string]$Name = "feastops-ec2",
  [switch]$ReplaceExisting
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

function Invoke-Aws {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  & $Aws @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "aws $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
  }
}

$caller = Invoke-AwsJson @("sts", "get-caller-identity", "--output", "json")
$accountId = $caller.Account
$registry = "$accountId.dkr.ecr.$AwsRegion.amazonaws.com"
$imageUri = "$registry/$RepositoryName`:$ImageTag"
$instanceProfileArgs = @()
$ecrLoginPassword = $null

Write-Host "FeastOps AWS EC2 deploy"
Write-Host "======================="
Write-Host "AWS principal: $($caller.Arn)"
Write-Host "AWS region:    $AwsRegion"
Write-Host "ECR image:     $imageUri"

Invoke-AwsJson @("ecr", "describe-images", "--region", $AwsRegion, "--repository-name", $RepositoryName, "--image-ids", "imageTag=$ImageTag", "--output", "json") | Out-Null

$roleName = "feastops-ec2-ecr-role"
$profileName = "feastops-ec2-instance-profile"
$assumeRolePolicy = '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

try {
  try {
    Invoke-AwsJson @("iam", "get-role", "--role-name", $roleName, "--output", "json") | Out-Null
    Write-Host "IAM role exists: $roleName"
  } catch {
    Write-Host "Creating IAM role: $roleName"
    Invoke-Aws @("iam", "create-role", "--role-name", $roleName, "--assume-role-policy-document", $assumeRolePolicy)
    Invoke-Aws @("iam", "attach-role-policy", "--role-name", $roleName, "--policy-arn", "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly")
  }

  try {
    Invoke-AwsJson @("iam", "get-instance-profile", "--instance-profile-name", $profileName, "--output", "json") | Out-Null
    Write-Host "Instance profile exists: $profileName"
  } catch {
    Write-Host "Creating instance profile: $profileName"
    Invoke-Aws @("iam", "create-instance-profile", "--instance-profile-name", $profileName)
    Invoke-Aws @("iam", "add-role-to-instance-profile", "--instance-profile-name", $profileName, "--role-name", $roleName)
    Write-Host "Waiting for IAM instance profile propagation..."
    Start-Sleep -Seconds 20
  }

  $instanceProfileArgs = @("--iam-instance-profile", "Name=$profileName")
} catch {
  Write-Host "IAM instance profile setup is blocked. Falling back to a short-lived ECR Docker login token in EC2 user-data."
  $ecrLoginPassword = (& $Aws ecr get-login-password --region $AwsRegion)
  if ($LASTEXITCODE -ne 0 -or -not $ecrLoginPassword) {
    throw "Could not get ECR login password for fallback deployment."
  }
}

$vpcs = Invoke-AwsJson @("ec2", "describe-vpcs", "--region", $AwsRegion, "--filters", "Name=is-default,Values=true", "--output", "json")
if (-not $vpcs.Vpcs -or $vpcs.Vpcs.Count -eq 0) {
  throw "No default VPC found in $AwsRegion. Create/select a VPC and subnet, or extend this script with explicit subnet IDs."
}
$vpcId = $vpcs.Vpcs[0].VpcId

$subnets = Invoke-AwsJson @("ec2", "describe-subnets", "--region", $AwsRegion, "--filters", "Name=vpc-id,Values=$vpcId", "Name=default-for-az,Values=true", "--output", "json")
if (-not $subnets.Subnets -or $subnets.Subnets.Count -eq 0) {
  throw "No default subnet found in VPC $vpcId."
}
$subnetId = $subnets.Subnets[0].SubnetId

$sgName = "feastops-public-web"
$securityGroupId = $null
$groups = Invoke-AwsJson @("ec2", "describe-security-groups", "--region", $AwsRegion, "--filters", "Name=vpc-id,Values=$vpcId", "Name=group-name,Values=$sgName", "--output", "json")
if ($groups.SecurityGroups -and $groups.SecurityGroups.Count -gt 0) {
  $securityGroupId = $groups.SecurityGroups[0].GroupId
  Write-Host "Security group exists: $securityGroupId"
} else {
  $createdGroup = Invoke-AwsJson @("ec2", "create-security-group", "--region", $AwsRegion, "--group-name", $sgName, "--description", "FeastOps public HTTP access", "--vpc-id", $vpcId, "--output", "json")
  $securityGroupId = $createdGroup.GroupId
  Invoke-Aws @("ec2", "create-tags", "--region", $AwsRegion, "--resources", $securityGroupId, "--tags", "Key=Name,Value=$sgName", "Key=Project,Value=FeastOps")
}

try {
  Invoke-Aws @("ec2", "authorize-security-group-ingress", "--region", $AwsRegion, "--group-id", $securityGroupId, "--protocol", "tcp", "--port", "80", "--cidr", "0.0.0.0/0")
} catch {
  Write-Host "HTTP ingress rule may already exist; continuing."
}

try {
  $amiParam = Invoke-AwsJson @("ssm", "get-parameter", "--region", $AwsRegion, "--name", "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64", "--output", "json")
  $amiId = $amiParam.Parameter.Value
} catch {
  Write-Host "SSM AMI lookup is blocked. Falling back to EC2 describe-images for latest Amazon Linux 2023."
  $amiId = (& $Aws ec2 describe-images --region $AwsRegion --owners amazon --filters "Name=name,Values=al2023-ami-2023*-x86_64" "Name=architecture,Values=x86_64" "Name=state,Values=available" --query "sort_by(Images,&CreationDate)[-1].ImageId" --output text)
  if ($LASTEXITCODE -ne 0 -or -not $amiId -or $amiId -eq "None") {
    throw "Could not resolve an Amazon Linux 2023 AMI."
  }
}

if ($ecrLoginPassword) {
  $loginCommand = "echo '$ecrLoginPassword' | docker login --username AWS --password-stdin $registry"
} else {
  $loginCommand = "aws ecr get-login-password --region $AwsRegion | docker login --username AWS --password-stdin $registry"
}

$userData = @"
#!/bin/bash
set -euo pipefail
echo "Starting FeastOps EC2 bootstrap"
dnf update -y
dnf install -y docker awscli
systemctl enable --now docker
TOKEN=`$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_IP=`$(curl -H "X-aws-ec2-metadata-token: `$TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 || true)
echo "Logging in to ECR"
$loginCommand
echo "Pulling FeastOps image"
docker pull $imageUri
docker rm -f feastops-app || true
echo "Starting FeastOps container"
docker run -d --name feastops-app --restart unless-stopped -p 80:3000 \
  -e NODE_ENV=production \
  -e DEPLOYMENT_TARGET=aws-ec2 \
  -e PUBLIC_APP_URL=http://`$PUBLIC_IP \
  $imageUri
sleep 12
echo "Container status"
docker ps -a
echo "Container logs"
docker logs feastops-app || true
echo "Local health check through published host port"
curl -v http://localhost/health || true
curl -v http://127.0.0.1/health || true
echo "Listening ports"
ss -ltnp || true
"@
$userDataPath = Join-Path ([System.IO.Path]::GetTempPath()) "feastops-ec2-user-data-$([guid]::NewGuid().ToString('N')).sh"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($userDataPath, $userData, $utf8NoBom)

$existing = Invoke-AwsJson @("ec2", "describe-instances", "--region", $AwsRegion, "--filters", "Name=tag:Name,Values=$Name", "Name=instance-state-name,Values=pending,running,stopping,stopped", "--output", "json")
$instanceId = $null
foreach ($reservation in $existing.Reservations) {
  foreach ($instance in $reservation.Instances) {
    $instanceId = $instance.InstanceId
    break
  }
  if ($instanceId) { break }
}

if ($instanceId) {
  Write-Host "Using existing EC2 instance: $instanceId"
  if ($ReplaceExisting) {
    Write-Host "Replacing existing EC2 instance: $instanceId"
    Invoke-Aws @("ec2", "terminate-instances", "--region", $AwsRegion, "--instance-ids", $instanceId)
    Invoke-Aws @("ec2", "wait", "instance-terminated", "--region", $AwsRegion, "--instance-ids", $instanceId)
    $instanceId = $null
  }
}

if ($instanceId) {
  $state = (Invoke-AwsJson @("ec2", "describe-instances", "--region", $AwsRegion, "--instance-ids", $instanceId, "--output", "json")).Reservations[0].Instances[0].State.Name
  if ($state -eq "stopped") {
    Invoke-Aws @("ec2", "start-instances", "--region", $AwsRegion, "--instance-ids", $instanceId)
  }
} else {
  $runArgs = @(
    "ec2", "run-instances",
    "--region", $AwsRegion,
    "--image-id", $amiId,
    "--instance-type", $InstanceType,
    "--subnet-id", $subnetId,
    "--security-group-ids", $securityGroupId,
    "--associate-public-ip-address",
    "--user-data", "file://$userDataPath",
    "--tag-specifications", "ResourceType=instance,Tags=[{Key=Name,Value=$Name},{Key=Project,Value=FeastOps}]",
    "--output", "json"
  ) + $instanceProfileArgs
  $run = Invoke-AwsJson $runArgs
  Remove-Item -LiteralPath $userDataPath -Force -ErrorAction SilentlyContinue
  $instanceId = $run.Instances[0].InstanceId
  Write-Host "Created EC2 instance: $instanceId"
}

Invoke-Aws @("ec2", "wait", "instance-running", "--region", $AwsRegion, "--instance-ids", $instanceId)
Invoke-Aws @("ec2", "wait", "instance-status-ok", "--region", $AwsRegion, "--instance-ids", $instanceId)

$instance = (Invoke-AwsJson @("ec2", "describe-instances", "--region", $AwsRegion, "--instance-ids", $instanceId, "--output", "json")).Reservations[0].Instances[0]
$publicDns = $instance.PublicDnsName
$publicIp = $instance.PublicIpAddress

Write-Host ""
Write-Host "AWS EC2 FeastOps URL:"
Write-Host "http://$publicDns"
Write-Host "http://$publicIp"
Write-Host ""
Write-Host "Give cloud-init a minute if /health is not ready immediately."
