param(
  [Parameter(Mandatory = $true)]
  [string]$RegistryImage,

  [string]$LocalImage = "feastops-food-delivery-api:latest"
)

$ErrorActionPreference = "Stop"
if (Get-Variable PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
  $PSNativeCommandUseErrorActionPreference = $true
}

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

function Invoke-Native {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Command,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
  )

  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Command $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
  }
}

Write-Host "Publishing FeastOps app image"
Write-Host "============================="
Write-Host "Local image:    $LocalImage"
Write-Host "Registry image: $RegistryImage"

Invoke-Native docker build -t $LocalImage (Join-Path $ProjectRoot "app")
Invoke-Native docker tag $LocalImage $RegistryImage
Invoke-Native docker push $RegistryImage

Write-Host ""
Write-Host "Published: $RegistryImage"
Write-Host ""
Write-Host "Anyone with registry access can now run:"
Write-Host "docker run --rm -p 3100:3000 $RegistryImage"
Write-Host ""
Write-Host "Or with compose:"
Write-Host "`$env:FEASTOPS_IMAGE='$RegistryImage'; docker compose -f docker-compose.app-image.yml up -d"
