param(
  [string]$AwsRegion = "us-east-1",
  [string]$Name = "feastops-app-asg"
)

$ErrorActionPreference = "Stop"
$Aws = (Get-Command aws -ErrorAction SilentlyContinue).Source
if (-not $Aws -and (Test-Path "C:\Program Files\Amazon\AWSCLIV2\aws.exe")) {
  $Aws = "C:\Program Files\Amazon\AWSCLIV2\aws.exe"
}
if (-not $Aws) { throw "aws is not installed or not on PATH." }

$asg = & $Aws autoscaling describe-auto-scaling-groups --region $AwsRegion --auto-scaling-group-names $Name --output json | ConvertFrom-Json
if (-not $asg.AutoScalingGroups -or $asg.AutoScalingGroups.Count -eq 0) {
  throw "Auto Scaling Group not found: $Name"
}

$group = $asg.AutoScalingGroups[0]
Write-Host "ASG:     $($group.AutoScalingGroupName)"
Write-Host "Desired: $($group.DesiredCapacity)"
Write-Host "Min/Max: $($group.MinSize)/$($group.MaxSize)"
Write-Host "Health:  $($group.HealthCheckType)"
Write-Host ""

$group.Instances | Select-Object InstanceId,LifecycleState,HealthStatus,AvailabilityZone | Format-Table

$targetGroupArn = $group.TargetGroupARNs[0]
if ($targetGroupArn) {
  $targetHealth = & $Aws elbv2 describe-target-health --region $AwsRegion --target-group-arn $targetGroupArn --output json | ConvertFrom-Json
  Write-Host ""
  Write-Host "Target health:"
  $targetHealth.TargetHealthDescriptions | ForEach-Object {
    [PSCustomObject]@{
      Target = $_.Target.Id
      Port = $_.Target.Port
      State = $_.TargetHealth.State
      Reason = $_.TargetHealth.Reason
    }
  } | Format-Table
}

$lbs = & $Aws elbv2 describe-load-balancers --region $AwsRegion --names "$Name-alb" --output json | ConvertFrom-Json
if ($lbs.LoadBalancers.Count -gt 0) {
  $dns = $lbs.LoadBalancers[0].DNSName
  Write-Host ""
  Write-Host "Public app URL:"
  Write-Host "http://$dns"
}
