param(
  [string]$AppImage = "ghcr.io/aniruddhiyer43782/feastops-food-delivery-api:latest",
  [string]$JenkinsImage = "ghcr.io/aniruddhiyer43782/feastops-jenkins:latest",
  [switch]$Start
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$env:FEASTOPS_APP_IMAGE = $AppImage
$env:FEASTOPS_JENKINS_IMAGE = $JenkinsImage

Write-Host "Pulling FeastOps full DevOps stack images"
Write-Host "App image:     $AppImage"
Write-Host "Jenkins image: $JenkinsImage"
Write-Host ""

docker compose -f docker-compose.full-stack.yml pull

if ($Start) {
  docker compose -f docker-compose.full-stack.yml up -d
  docker compose -f docker-compose.full-stack.yml ps
  Write-Host ""
  Write-Host "App:        http://localhost:3100"
  Write-Host "Jenkins:    http://localhost:8081"
  Write-Host "Grafana:    http://localhost:3001"
  Write-Host "Prometheus: http://localhost:9091"
  Write-Host "SonarQube:  http://localhost:9001"
} else {
  Write-Host "Images pulled. Start the stack with:"
  Write-Host ".\scripts\pull-full-stack.cmd -Start"
}
