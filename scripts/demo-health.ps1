$ErrorActionPreference = "Stop"

$checks = @(
  @{ Name = "FeastOps app"; Url = "http://localhost:3100/health" },
  @{ Name = "Prometheus"; Url = "http://localhost:9091/-/healthy" },
  @{ Name = "Grafana"; Url = "http://localhost:3001/api/health" },
  @{ Name = "Jenkins"; Url = "http://localhost:8081/login" },
  @{ Name = "SonarQube"; Url = "http://localhost:9001" }
)

Write-Host "FeastOps demo health check"
Write-Host "=========================="

foreach ($check in $checks) {
  try {
    $response = Invoke-WebRequest -Uri $check.Url -UseBasicParsing -TimeoutSec 10
    if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400) {
      Write-Host ("[OK]   {0} -> HTTP {1}" -f $check.Name, $response.StatusCode)
    } else {
      Write-Host ("[WARN] {0} -> HTTP {1}" -f $check.Name, $response.StatusCode)
    }
  } catch {
    Write-Host ("[FAIL] {0} -> {1}" -f $check.Name, $_.Exception.Message)
  }
}

Write-Host ""
Write-Host "Docker containers:"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$dockerOutput = & docker compose ps 2>&1
$dockerExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference

if ($dockerExitCode -eq 0) {
  $dockerOutput
} else {
  Write-Host "[WARN] Docker status unavailable from this shell."
  Write-Host "       Run 'docker compose ps' in a Docker-enabled terminal if you need container details."
}

Write-Host ""
Write-Host "Prometheus alert rules:"
$rules = Invoke-RestMethod -Uri "http://localhost:9091/api/v1/rules"
$rules.data.groups | ForEach-Object {
  $_.rules | ForEach-Object {
    Write-Host ("[{0}] {1}" -f $_.state.ToUpperInvariant(), $_.name)
  }
}
