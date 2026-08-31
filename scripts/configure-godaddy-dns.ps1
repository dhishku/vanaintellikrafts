# Update GoDaddy DNS for vanaintellikrafts.in → GitHub Pages (www) with apex A records.
# Requires GoDaddy API key: https://developer.godaddy.com/keys
# Store credentials in gitignored .env at repo root:
#   GODADDY_API_KEY=...
#   GODADDY_API_SECRET=...
param(
    [string]$Domain = "vanaintellikrafts.in",
    [string]$WwwTarget = "dhishku.github.io",
    [string]$EnvFile = "$PSScriptRoot\..\.env",
    [string]$ApiKey = $env:GODADDY_API_KEY,
    [string]$ApiSecret = $env:GODADDY_API_SECRET,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^\s*([^#=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim().Trim('"').Trim("'")
            if ($name -eq "GODADDY_API_KEY" -and -not $ApiKey) { $ApiKey = $value }
            if ($name -eq "GODADDY_API_SECRET" -and -not $ApiSecret) { $ApiSecret = $value }
        }
    }
}

# Fallback: restaurant project credentials (same GoDaddy account)
$fallbackEnv = "d:\projects\restaurant\infra\.env.godaddy"
if ((-not $ApiKey -or -not $ApiSecret) -and (Test-Path $fallbackEnv)) {
    Get-Content $fallbackEnv | ForEach-Object {
        if ($_ -match '^\s*([^#=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim().Trim('"').Trim("'")
            if ($name -eq "GODADDY_API_KEY" -and -not $ApiKey) { $ApiKey = $value }
            if ($name -eq "GODADDY_API_SECRET" -and -not $ApiSecret) { $ApiSecret = $value }
        }
    }
}

$apexIps = @(
    "185.199.108.153",
    "185.199.109.153",
    "185.199.110.153",
    "185.199.111.153"
)

$records = @(
    @{ type = "CNAME"; name = "www"; data = $WwwTarget; ttl = 600 }
) + ($apexIps | ForEach-Object { @{ type = "A"; name = "@"; data = $_; ttl = 600 } })

Write-Host "GoDaddy DNS for $Domain"
Write-Host "  CNAME www -> $WwwTarget"
foreach ($ip in $apexIps) { Write-Host "  A @ -> $ip" }

if ($WhatIf) {
    Write-Host "WhatIf: no API calls made."
    exit 0
}

if (-not $ApiKey -or -not $ApiSecret) {
    throw "GoDaddy API credentials missing. Add GODADDY_API_KEY and GODADDY_API_SECRET to .env"
}

$headers = @{
    Authorization  = "sso-key ${ApiKey}:${ApiSecret}"
    Accept         = "application/json"
    "Content-Type" = "application/json"
}

foreach ($r in $records) {
    $uri = "https://api.godaddy.com/v1/domains/$Domain/records/$($r.type)/$($r.name)"
    $payload = @(@{ data = $r.data; ttl = $r.ttl })
    $body = $payload | ConvertTo-Json -Compress -Depth 3
    if (-not $body.TrimStart().StartsWith("[")) { $body = "[$body]" }
    Write-Host "PUT $uri"
    Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -Body $body
}

Write-Host ""
Write-Host "DNS updated. Allow up to 60 minutes for propagation."
Write-Host "  https://www.$Domain"
Write-Host "  https://$Domain"
