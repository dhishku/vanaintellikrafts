# Update GoDaddy DNS for vanaintellikrafts.in → Vercel.
# Requires GoDaddy API key: https://developer.godaddy.com/keys
# Store credentials in gitignored .env at repo root:
#   GODADDY_API_KEY=...
#   GODADDY_API_SECRET=...
param(
    [string]$Domain = "vanaintellikrafts.in",
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

$records = @(
    @{ type = "A"; name = "@"; data = "76.76.21.21"; ttl = 600 }
    @{ type = "A"; name = "www"; data = "76.76.21.21"; ttl = 600 }
)

Write-Host "GoDaddy DNS for $Domain -> Vercel"
Write-Host "  A @ -> 76.76.21.21"
Write-Host "  A www -> 76.76.21.21"

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
