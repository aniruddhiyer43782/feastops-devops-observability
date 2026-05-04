param(
  [string]$ImageName = "feastops-food-delivery-api:latest"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

Write-Host "Building reusable FeastOps app image"
Write-Host "===================================="
Write-Host "Image: $ImageName"
docker build -t $ImageName (Join-Path $ProjectRoot "app")

Write-Host ""
Write-Host "Image built successfully."
docker images $ImageName
