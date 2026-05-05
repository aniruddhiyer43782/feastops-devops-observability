param(
  [string]$AwsRegion = "us-east-1",
  [string]$RepositoryName = "feastops-food-delivery-api",
  [string]$ImageTag = "latest",
  [string]$InstanceType = "t3.medium",
  [string]$Name = "feastops-aws-devops-stack",
  [string]$GitRepoUrl = "https://github.com/aniruddhiyer43782/feastops-devops-observability.git",
  [switch]$ReplaceExisting
)

$ErrorActionPreference = "Stop"

function Resolve-Tool {
  param([string]$Name, [string[]]$Fallbacks = @())
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }
  foreach ($fallback in $Fallbacks) {
    if (Test-Path $fallback) { return $fallback }
  }
  throw "$Name is not installed or not on PATH."
}

$Aws = Resolve-Tool "aws" @("C:\Program Files\Amazon\AWSCLIV2\aws.exe")

function Invoke-AwsJson {
  param([string[]]$Arguments)
  $output = & $Aws @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) { throw ($output -join "`n") }
  return $output | ConvertFrom-Json
}

function Invoke-Aws {
  param([string[]]$Arguments)
  & $Aws @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "aws $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
  }
}

function Allow-Port {
  param([string]$SecurityGroupId, [int]$Port)
  try {
    Invoke-Aws @("ec2", "authorize-security-group-ingress", "--region", $AwsRegion, "--group-id", $SecurityGroupId, "--protocol", "tcp", "--port", "$Port", "--cidr", "0.0.0.0/0")
  } catch {
    Write-Host "Ingress for port $Port may already exist; continuing."
  }
}

$caller = Invoke-AwsJson @("sts", "get-caller-identity", "--output", "json")
$accountId = $caller.Account
$registry = "$accountId.dkr.ecr.$AwsRegion.amazonaws.com"
$imageUri = "$registry/$RepositoryName`:$ImageTag"

Write-Host "FeastOps AWS DevOps stack deploy"
Write-Host "================================"
Write-Host "AWS principal: $($caller.Arn)"
Write-Host "AWS region:    $AwsRegion"
Write-Host "ECR image:     $imageUri"
Write-Host "Instance type: $InstanceType"

Invoke-AwsJson @("ecr", "describe-images", "--region", $AwsRegion, "--repository-name", $RepositoryName, "--image-ids", "imageTag=$ImageTag", "--output", "json") | Out-Null

$roleName = "feastops-ec2-ecr-role"
$profileName = "feastops-ec2-instance-profile"
$assumeRolePolicy = '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
$instanceProfileArgs = @()
$ecrLoginPassword = $null

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
  throw "No default VPC found in $AwsRegion."
}
$vpcId = $vpcs.Vpcs[0].VpcId

$subnets = Invoke-AwsJson @("ec2", "describe-subnets", "--region", $AwsRegion, "--filters", "Name=vpc-id,Values=$vpcId", "Name=default-for-az,Values=true", "--output", "json")
if (-not $subnets.Subnets -or $subnets.Subnets.Count -eq 0) {
  throw "No default subnet found in VPC $vpcId."
}
$subnetId = $subnets.Subnets[0].SubnetId

$sgName = "feastops-devops-public"
$groups = Invoke-AwsJson @("ec2", "describe-security-groups", "--region", $AwsRegion, "--filters", "Name=vpc-id,Values=$vpcId", "Name=group-name,Values=$sgName", "--output", "json")
if ($groups.SecurityGroups -and $groups.SecurityGroups.Count -gt 0) {
  $securityGroupId = $groups.SecurityGroups[0].GroupId
  Write-Host "Security group exists: $securityGroupId"
} else {
  $createdGroup = Invoke-AwsJson @("ec2", "create-security-group", "--region", $AwsRegion, "--group-name", $sgName, "--description", "FeastOps public DevOps demo stack", "--vpc-id", $vpcId, "--output", "json")
  $securityGroupId = $createdGroup.GroupId
  Invoke-Aws @("ec2", "create-tags", "--region", $AwsRegion, "--resources", $securityGroupId, "--tags", "Key=Name,Value=$sgName", "Key=Project,Value=FeastOps")
}

80, 3000, 8080, 9000, 9090 | ForEach-Object { Allow-Port -SecurityGroupId $securityGroupId -Port $_ }

try {
  $amiParam = Invoke-AwsJson @("ssm", "get-parameter", "--region", $AwsRegion, "--name", "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64", "--output", "json")
  $amiId = $amiParam.Parameter.Value
} catch {
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
exec > >(tee /var/log/feastops-devops-bootstrap.log|logger -t feastops-devops-bootstrap -s 2>/dev/console) 2>&1

echo "Starting FeastOps AWS DevOps stack bootstrap"
dnf update -y
dnf install -y docker git awscli
systemctl enable --now docker
usermod -aG docker ec2-user || true
sysctl -w vm.max_map_count=262144
grep -q "vm.max_map_count" /etc/sysctl.conf || echo "vm.max_map_count=262144" >> /etc/sysctl.conf
fallocate -l 2G /swapfile || true
chmod 600 /swapfile || true
mkswap /swapfile || true
swapon /swapfile || true
grep -q "/swapfile" /etc/fstab || echo "/swapfile swap swap defaults 0 0" >> /etc/fstab

TOKEN=`$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_IP=`$(curl -H "X-aws-ec2-metadata-token: `$TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Public IP: `$PUBLIC_IP"

mkdir -p /opt/feastops
if [ -d /opt/feastops/.git ]; then
  git -C /opt/feastops pull --ff-only
else
  git clone $GitRepoUrl /opt/feastops
fi
cd /opt/feastops

echo "Logging in to ECR"
$loginCommand
docker pull $imageUri

cat > .env.aws-devops <<ENVEOF
FEASTOPS_APP_IMAGE=$imageUri
PUBLIC_HOST=`$PUBLIC_IP
ENVEOF

echo "Starting Docker Compose DevOps stack"
docker compose --env-file .env.aws-devops -f docker-compose.aws-devops.yml up -d --build

echo "Waiting for app health"
for i in {1..60}; do
  if curl -fsS http://localhost/health; then
    break
  fi
  sleep 5
done

echo "Waiting for Grafana health"
for i in {1..60}; do
  if curl -fsS http://localhost:3000/api/health; then
    break
  fi
  sleep 5
done

echo "Waiting for Prometheus health"
for i in {1..60}; do
  if curl -fsS http://localhost:9090/-/healthy; then
    break
  fi
  sleep 5
done

echo "Stack status"
docker compose --env-file .env.aws-devops -f docker-compose.aws-devops.yml ps
curl -fsS http://localhost/api/devops/status || true
"@

$userDataPath = Join-Path ([System.IO.Path]::GetTempPath()) "feastops-aws-devops-user-data-$([guid]::NewGuid().ToString('N')).sh"
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

if ($instanceId -and $ReplaceExisting) {
  Write-Host "Replacing existing EC2 instance: $instanceId"
  Invoke-Aws @("ec2", "terminate-instances", "--region", $AwsRegion, "--instance-ids", $instanceId)
  Invoke-Aws @("ec2", "wait", "instance-terminated", "--region", $AwsRegion, "--instance-ids", $instanceId)
  $instanceId = $null
}

if (-not $instanceId) {
  $runArgs = @(
    "ec2", "run-instances",
    "--region", $AwsRegion,
    "--image-id", $amiId,
    "--instance-type", $InstanceType,
    "--subnet-id", $subnetId,
    "--security-group-ids", $securityGroupId,
    "--associate-public-ip-address",
    "--user-data", "file://$userDataPath",
    "--block-device-mappings", "DeviceName=/dev/xvda,Ebs={VolumeSize=30,VolumeType=gp3,DeleteOnTermination=true}",
    "--tag-specifications", "ResourceType=instance,Tags=[{Key=Name,Value=$Name},{Key=Project,Value=FeastOps},{Key=Role,Value=DevOpsStack}]",
    "--output", "json"
  ) + $instanceProfileArgs
  $run = Invoke-AwsJson $runArgs
  $instanceId = $run.Instances[0].InstanceId
  Write-Host "Created EC2 instance: $instanceId"
} else {
  Write-Host "Using existing EC2 instance: $instanceId"
  $state = (Invoke-AwsJson @("ec2", "describe-instances", "--region", $AwsRegion, "--instance-ids", $instanceId, "--output", "json")).Reservations[0].Instances[0].State.Name
  if ($state -eq "stopped") {
    Invoke-Aws @("ec2", "start-instances", "--region", $AwsRegion, "--instance-ids", $instanceId)
  } else {
    Write-Host "Existing running instances do not rerun user-data. Use -ReplaceExisting for a fresh deployment."
  }
}

Remove-Item -LiteralPath $userDataPath -Force -ErrorAction SilentlyContinue

Invoke-Aws @("ec2", "wait", "instance-running", "--region", $AwsRegion, "--instance-ids", $instanceId)
Invoke-Aws @("ec2", "wait", "instance-status-ok", "--region", $AwsRegion, "--instance-ids", $instanceId)

$instance = (Invoke-AwsJson @("ec2", "describe-instances", "--region", $AwsRegion, "--instance-ids", $instanceId, "--output", "json")).Reservations[0].Instances[0]
$publicIp = $instance.PublicIpAddress
$publicDns = $instance.PublicDnsName

Write-Host ""
Write-Host "AWS DevOps stack created:"
Write-Host "Instance:   $instanceId"
Write-Host "Public IP:  $publicIp"
Write-Host ""
Write-Host "Public URLs:"
Write-Host "App:        http://$publicIp"
Write-Host "Jenkins:    http://$publicIp`:8080"
Write-Host "Grafana:    http://$publicIp`:3000"
Write-Host "Prometheus: http://$publicIp`:9090"
Write-Host "SonarQube:  http://$publicIp`:9000"
Write-Host ""
Write-Host "DNS URLs:"
Write-Host "App:        http://$publicDns"
Write-Host ""
Write-Host "Run scripts\\aws-devops-stack-status.cmd to check bootstrap and service health."
