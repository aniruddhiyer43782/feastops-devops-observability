param(
  [string]$AwsRegion = "us-east-1",
  [string]$AppImage = "ghcr.io/aniruddhiyer43782/feastops-food-delivery-api:latest",
  [string]$Name = "feastops-app-asg",
  [string]$InstanceType = "t3.micro",
  [int]$MinSize = 2,
  [int]$DesiredCapacity = 2,
  [int]$MaxSize = 4,
  [int]$CpuTarget = 60,
  [switch]$ReplaceExisting
)

$ErrorActionPreference = "Stop"
if (Get-Variable PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
  $PSNativeCommandUseErrorActionPreference = $false
}

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
  $outputPath = Join-Path ([IO.Path]::GetTempPath()) "aws-output-$([guid]::NewGuid().ToString('N')).txt"
  $errorPath = Join-Path ([IO.Path]::GetTempPath()) "aws-error-$([guid]::NewGuid().ToString('N')).txt"
  $process = Start-Process -FilePath $Aws -ArgumentList $Arguments -NoNewWindow -Wait -PassThru -RedirectStandardOutput $outputPath -RedirectStandardError $errorPath
  $output = if (Test-Path $outputPath) { Get-Content -LiteralPath $outputPath } else { @() }
  $errorText = if (Test-Path $errorPath) { Get-Content -LiteralPath $errorPath -Raw } else { "" }
  Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $errorPath -Force -ErrorAction SilentlyContinue
  if ($process.ExitCode -ne 0) { throw "$($output -join "`n")`n$errorText" }
  return $output | ConvertFrom-Json
}

function Invoke-Aws {
  param([string[]]$Arguments)
  $outputPath = Join-Path ([IO.Path]::GetTempPath()) "aws-output-$([guid]::NewGuid().ToString('N')).txt"
  $errorPath = Join-Path ([IO.Path]::GetTempPath()) "aws-error-$([guid]::NewGuid().ToString('N')).txt"
  $process = Start-Process -FilePath $Aws -ArgumentList $Arguments -NoNewWindow -Wait -PassThru -RedirectStandardOutput $outputPath -RedirectStandardError $errorPath
  $output = if (Test-Path $outputPath) { Get-Content -LiteralPath $outputPath -Raw } else { "" }
  $errorText = if (Test-Path $errorPath) { Get-Content -LiteralPath $errorPath -Raw } else { "" }
  Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $errorPath -Force -ErrorAction SilentlyContinue
  if ($process.ExitCode -ne 0) {
    throw "aws $($Arguments -join ' ') failed with exit code $($process.ExitCode)`n$output`n$errorText"
  }
  if ($output -and $output.Trim()) { Write-Host $output.Trim() }
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
Write-Host "FeastOps AWS Auto Scaling deploy"
Write-Host "================================"
Write-Host "AWS principal: $($caller.Arn)"
Write-Host "Image:         $AppImage"

$vpcs = Invoke-AwsJson @("ec2", "describe-vpcs", "--region", $AwsRegion, "--filters", "Name=is-default,Values=true", "--output", "json")
if (-not $vpcs.Vpcs -or $vpcs.Vpcs.Count -eq 0) { throw "No default VPC found in $AwsRegion." }
$vpcId = $vpcs.Vpcs[0].VpcId

$subnets = Invoke-AwsJson @("ec2", "describe-subnets", "--region", $AwsRegion, "--filters", "Name=vpc-id,Values=$vpcId", "Name=default-for-az,Values=true", "--query", "Subnets[].SubnetId", "--output", "json")
if (-not $subnets -or $subnets.Count -lt 2) { throw "At least two default subnets are required for an internet-facing ALB." }
$subnetIds = @($subnets | Select-Object -First 3)
$subnetCsv = $subnetIds -join ","

$sgName = "$Name-public-web"
$groups = Invoke-AwsJson @("ec2", "describe-security-groups", "--region", $AwsRegion, "--filters", "Name=vpc-id,Values=$vpcId", "Name=group-name,Values=$sgName", "--output", "json")
if ($groups.SecurityGroups -and $groups.SecurityGroups.Count -gt 0) {
  $securityGroupId = $groups.SecurityGroups[0].GroupId
} else {
  $createdGroup = Invoke-AwsJson @("ec2", "create-security-group", "--region", $AwsRegion, "--group-name", $sgName, "--description", "FeastOps ASG public web access", "--vpc-id", $vpcId, "--output", "json")
  $securityGroupId = $createdGroup.GroupId
  Invoke-Aws @("ec2", "create-tags", "--region", $AwsRegion, "--resources", $securityGroupId, "--tags", "Key=Name,Value=$sgName", "Key=Project,Value=FeastOps")
}
Allow-Port -SecurityGroupId $securityGroupId -Port 80

$amiId = (& $Aws ec2 describe-images --region $AwsRegion --owners amazon --filters "Name=name,Values=al2023-ami-2023*-x86_64" "Name=architecture,Values=x86_64" "Name=state,Values=available" --query "sort_by(Images,&CreationDate)[-1].ImageId" --output text)
if ($LASTEXITCODE -ne 0 -or -not $amiId -or $amiId -eq "None") { throw "Could not resolve Amazon Linux 2023 AMI." }

if ($ReplaceExisting) {
  try { Invoke-Aws @("autoscaling", "delete-auto-scaling-group", "--region", $AwsRegion, "--auto-scaling-group-name", $Name, "--force-delete") } catch {}
  try { Invoke-Aws @("ec2", "delete-launch-template", "--region", $AwsRegion, "--launch-template-name", $Name) } catch {}
}

$targetGroupName = "$Name-tg"
$loadBalancerName = "$Name-alb"

try {
  $targetGroupArn = (Invoke-AwsJson @("elbv2", "describe-target-groups", "--region", $AwsRegion, "--names", $targetGroupName, "--output", "json")).TargetGroups[0].TargetGroupArn
} catch {
  $targetGroupArn = (Invoke-AwsJson @(
    "elbv2", "create-target-group",
    "--region", $AwsRegion,
    "--name", $targetGroupName,
    "--protocol", "HTTP",
    "--port", "80",
    "--vpc-id", $vpcId,
    "--health-check-path", "/health",
    "--target-type", "instance",
    "--output", "json"
  )).TargetGroups[0].TargetGroupArn
}

try {
  $loadBalancer = (Invoke-AwsJson @("elbv2", "describe-load-balancers", "--region", $AwsRegion, "--names", $loadBalancerName, "--output", "json")).LoadBalancers[0]
} catch {
  $loadBalancer = (Invoke-AwsJson @(
    "elbv2", "create-load-balancer",
    "--region", $AwsRegion,
    "--name", $loadBalancerName,
    "--subnets"
  ) + $subnetIds + @(
    "--security-groups", $securityGroupId,
    "--scheme", "internet-facing",
    "--type", "application",
    "--output", "json"
  )).LoadBalancers[0]
}
$loadBalancerArn = $loadBalancer.LoadBalancerArn
$loadBalancerDns = $loadBalancer.DNSName

$listeners = Invoke-AwsJson @("elbv2", "describe-listeners", "--region", $AwsRegion, "--load-balancer-arn", $loadBalancerArn, "--output", "json")
if (-not $listeners.Listeners -or $listeners.Listeners.Count -eq 0) {
  Invoke-Aws @(
    "elbv2", "create-listener",
    "--region", $AwsRegion,
    "--load-balancer-arn", $loadBalancerArn,
    "--protocol", "HTTP",
    "--port", "80",
    "--default-actions", "Type=forward,TargetGroupArn=$targetGroupArn"
  )
}

$userData = @"
#!/bin/bash
set -euo pipefail
dnf update -y
dnf install -y docker
systemctl enable --now docker
docker pull $AppImage
docker rm -f feastops-app || true
docker run -d --name feastops-app --restart unless-stopped -p 80:3000 \
  -e NODE_ENV=production \
  -e DEPLOYMENT_TARGET=aws-ec2-auto-scaling-group \
  -e PUBLIC_APP_URL=http://$loadBalancerDns \
  $AppImage
"@
$userDataBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($userData))

$launchTemplateData = @{
  ImageId = $amiId
  InstanceType = $InstanceType
  SecurityGroupIds = @($securityGroupId)
  UserData = $userDataBase64
  TagSpecifications = @(
    @{
      ResourceType = "instance"
      Tags = @(
        @{ Key = "Name"; Value = "$Name-node" },
        @{ Key = "Project"; Value = "FeastOps" },
        @{ Key = "Role"; Value = "AutoScalingAppNode" }
      )
    }
  )
} | ConvertTo-Json -Depth 8 -Compress
$launchTemplatePath = Join-Path ([IO.Path]::GetTempPath()) "$Name-launch-template.json"
$launchTemplateData | Set-Content -LiteralPath $launchTemplatePath -Encoding utf8

try {
  Invoke-AwsJson @("ec2", "describe-launch-templates", "--region", $AwsRegion, "--launch-template-names", $Name, "--output", "json") | Out-Null
} catch {
  Invoke-Aws @("ec2", "create-launch-template", "--region", $AwsRegion, "--launch-template-name", $Name, "--launch-template-data", "file://$launchTemplatePath")
}
Remove-Item -LiteralPath $launchTemplatePath -Force -ErrorAction SilentlyContinue

try {
  Invoke-AwsJson @("autoscaling", "describe-auto-scaling-groups", "--region", $AwsRegion, "--auto-scaling-group-names", $Name, "--output", "json") | Out-Null
  Invoke-Aws @("autoscaling", "update-auto-scaling-group", "--region", $AwsRegion, "--auto-scaling-group-name", $Name, "--min-size", "$MinSize", "--desired-capacity", "$DesiredCapacity", "--max-size", "$MaxSize", "--target-group-arns", $targetGroupArn)
} catch {
  Invoke-Aws @(
    "autoscaling", "create-auto-scaling-group",
    "--region", $AwsRegion,
    "--auto-scaling-group-name", $Name,
    "--launch-template", "LaunchTemplateName=$Name,Version=`$Latest",
    "--min-size", "$MinSize",
    "--desired-capacity", "$DesiredCapacity",
    "--max-size", "$MaxSize",
    "--vpc-zone-identifier", $subnetCsv,
    "--target-group-arns", $targetGroupArn,
    "--tags", "Key=Name,Value=$Name-node,PropagateAtLaunch=true", "Key=Project,Value=FeastOps,PropagateAtLaunch=true"
  )
}

$targetTrackingConfig = @{
  PredefinedMetricSpecification = @{
    PredefinedMetricType = "ASGAverageCPUUtilization"
  }
  TargetValue = $CpuTarget
} | ConvertTo-Json -Compress

Invoke-Aws @(
  "autoscaling", "put-scaling-policy",
  "--region", $AwsRegion,
  "--auto-scaling-group-name", $Name,
  "--policy-name", "$Name-cpu-target-tracking",
  "--policy-type", "TargetTrackingScaling",
  "--target-tracking-configuration", $targetTrackingConfig
)

Write-Host ""
Write-Host "AWS Auto Scaling deployment requested."
Write-Host "ALB URL: http://$loadBalancerDns"
Write-Host "ASG:     $Name min=$MinSize desired=$DesiredCapacity max=$MaxSize cpu=$CpuTarget%"
Write-Host "Run:     .\scripts\aws-asg-status.cmd"
