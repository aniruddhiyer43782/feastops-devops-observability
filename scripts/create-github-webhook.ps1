param(
  [Parameter(Mandatory = $true)]
  [string]$WebhookUrl,
  [string]$Repo = "aniruddhiyer43782/feastops-devops-observability",
  [string]$GhPath = ".\tools\bin\gh.exe",
  [switch]$ReplaceExisting
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $GhPath)) {
  $GhPath = "gh"
}

if ($ReplaceExisting) {
  $hooks = & $GhPath api "repos/$Repo/hooks" | ConvertFrom-Json
  foreach ($hook in $hooks) {
    if ($hook.config.url -like "*.trycloudflare.com/github-webhook/*" -or $hook.config.url -eq $WebhookUrl) {
      & $GhPath api "repos/$Repo/hooks/$($hook.id)" --method DELETE | Out-Null
    }
  }
}

& $GhPath api "repos/$Repo/hooks" `
  --method POST `
  --field name=web `
  --field active=true `
  --field events[]=push `
  --field config[url]="$WebhookUrl" `
  --field config[content_type]=json `
  --field config[insecure_ssl]=0

Write-Host "GitHub webhook created for $Repo -> $WebhookUrl"
