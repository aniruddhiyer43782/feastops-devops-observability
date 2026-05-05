param(
  [string]$AwsRegion = "us-east-1",
  [string]$Name = "feastops-aws-devops-stack"
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

$instances = Invoke-AwsJson @(
  "ec2", "describe-instances",
  "--region", $AwsRegion,
  "--filters", "Name=tag:Name,Values=$Name", "Name=instance-state-name,Values=pending,running,stopped,stopping",
  "--output", "json"
)

$instance = $null
foreach ($reservation in $instances.Reservations) {
  foreach ($entry in $reservation.Instances) {
    $instance = $entry
    break
  }
  if ($instance) { break }
}

if (-not $instance) {
  throw "No EC2 instance found with Name=$Name in $AwsRegion."
}

$publicIp = $instance.PublicIpAddress
Write-Host "Instance: $($instance.InstanceId)"
Write-Host "State:    $($instance.State.Name)"
Write-Host "Type:     $($instance.InstanceType)"
Write-Host "Public:   $publicIp"
Write-Host ""

$urls = @(
  @{ Name = "App"; Url = "http://$publicIp/health" },
  @{ Name = "Jenkins"; Url = "http://$publicIp`:8080/login" },
  @{ Name = "Grafana"; Url = "http://$publicIp`:3000/api/health" },
  @{ Name = "Prometheus"; Url = "http://$publicIp`:9090/-/healthy" },
  @{ Name = "SonarQube"; Url = "http://$publicIp`:9000/api/system/status" }
)

foreach ($target in $urls) {
  try {
    $response = Invoke-WebRequest -Uri $target.Url -UseBasicParsing -TimeoutSec 8
    Write-Host ("{0,-10} OK   {1}" -f $target.Name, $target.Url)
  } catch {
    Write-Host ("{0,-10} WAIT {1}" -f $target.Name, $target.Url)
  }
}

Write-Host ""
Write-Host "Open:"
Write-Host "App:        http://$publicIp"
Write-Host "Jenkins:    http://$publicIp`:8080"
Write-Host "Grafana:    http://$publicIp`:3000"
Write-Host "Prometheus: http://$publicIp`:9090"
Write-Host "SonarQube:  http://$publicIp`:9000"
