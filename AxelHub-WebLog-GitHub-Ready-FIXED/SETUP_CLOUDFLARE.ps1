$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host "=== AXEL HUB WEBLOG - CLOUDFLARE ONE-CLICK AUTO SETUP ===" -ForegroundColor Cyan
Write-Host ""

function Need-Command($cmd) {
  return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Open-Web($url) {
  try {
    Start-Process $url | Out-Null
    Write-Host "Opened: $url" -ForegroundColor DarkCyan
  } catch {
    Write-Host "Could not open browser automatically: $url" -ForegroundColor Yellow
  }
}

if (-not (Need-Command "node")) {
  Write-Host "Node.js is not installed. Install Node.js LTS, then run this again." -ForegroundColor Yellow
  exit 1
}
if (-not (Need-Command "npm")) {
  Write-Host "npm is not available. Reinstall Node.js LTS and run this again." -ForegroundColor Yellow
  exit 1
}

if (-not (Test-Path "package.json")) {
  throw "package.json not found. Run this script from the extracted project folder."
}

# Open Cloudflare immediately so the user has the correct site ready.
Open-Web "https://dash.cloudflare.com/"
Write-Host ""

Write-Host "[1/7] Installing / updating Wrangler..." -ForegroundColor Green
npm install
if ($LASTEXITCODE -ne 0) { throw "npm install failed." }

Write-Host "[2/7] Cloudflare login (browser approval only)..." -ForegroundColor Green
Write-Host "A Cloudflare authorization page will open automatically." -ForegroundColor White
# Device flow is more reliable than the localhost callback flow on current Wrangler.
npx wrangler login --device
if ($LASTEXITCODE -ne 0) { throw "Cloudflare login failed or was cancelled." }

$configPath = Join-Path $PSScriptRoot "wrangler.jsonc"
$config = Get-Content $configPath -Raw

Write-Host "[3/7] Finding or creating D1 database: axelhub-weblog..." -ForegroundColor Green
if ($config -match 'PASTE_YOUR_D1_DATABASE_ID_HERE') {
  $dbId = $null

  # Reuse an existing database with the same name when possible.
  try {
    $listOutput = npx wrangler d1 list --json 2>&1
    $joined = ($listOutput -join "`n")
    $jsonStart = $joined.IndexOf('[')
    if ($jsonStart -ge 0) {
      $jsonCandidate = $joined.Substring($jsonStart)
      $dbList = $jsonCandidate | ConvertFrom-Json
      $existing = $dbList | Where-Object { $_.name -eq 'axelhub-weblog' } | Select-Object -First 1
      if ($existing -and $existing.uuid) {
        $dbId = [string]$existing.uuid
        Write-Host "Existing D1 found: $dbId" -ForegroundColor DarkCyan
      } elseif ($existing -and $existing.database_id) {
        $dbId = [string]$existing.database_id
        Write-Host "Existing D1 found: $dbId" -ForegroundColor DarkCyan
      }
    }
  } catch {
    Write-Host "D1 list check did not return JSON; continuing with create attempt." -ForegroundColor Yellow
  }

  if ([string]::IsNullOrWhiteSpace($dbId)) {
    $createOutput = npx wrangler d1 create axelhub-weblog --json 2>&1
    $joined = ($createOutput -join "`n")
    $match = [regex]::Match($joined, '"database_id"\s*:\s*"([0-9a-fA-F-]{30,})"')
    if ($match.Success) {
      $dbId = $match.Groups[1].Value
    } else {
      $match = [regex]::Match($joined, '"uuid"\s*:\s*"([0-9a-fA-F-]{30,})"')
      if ($match.Success) { $dbId = $match.Groups[1].Value }
    }
    if ([string]::IsNullOrWhiteSpace($dbId)) {
      Write-Host "Cloudflare did not return a parsable database ID." -ForegroundColor Yellow
      Write-Host $joined
      $dbId = Read-Host "Paste the D1 database ID shown above"
    }
  }

  if ([string]::IsNullOrWhiteSpace($dbId)) { throw "Database ID is required." }
  $config = $config.Replace('PASTE_YOUR_D1_DATABASE_ID_HERE', $dbId.Trim())
  Set-Content $configPath $config -Encoding UTF8
} else {
  Write-Host "D1 database ID already configured." -ForegroundColor DarkCyan
}

Write-Host "[4/7] Setting AUTH_SECRET automatically..." -ForegroundColor Green
# Generate a secret locally. No secret prompt is needed.
$bytes = New-Object byte[] 48
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$secret = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+','-').Replace('/','_')
$secret | npx wrangler secret put AUTH_SECRET
if ($LASTEXITCODE -ne 0) { throw "Could not store AUTH_SECRET in Cloudflare." }

Write-Host "[5/7] Applying D1 migrations remotely..." -ForegroundColor Green
npx wrangler d1 migrations apply axelhub-weblog --remote
if ($LASTEXITCODE -ne 0) { throw "D1 migration failed." }

Write-Host "[6/7] Deploying Worker..." -ForegroundColor Green
$deployOutput = npx wrangler deploy 2>&1
$deployOutput | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) { throw "Worker deployment failed." }

Write-Host "[7/7] Opening the deployed Worker..." -ForegroundColor Green
$deployText = ($deployOutput -join "`n")
$workerUrl = $null
$urlMatches = [regex]::Matches($deployText, 'https://[A-Za-z0-9._-]+\.workers\.dev(?:/[^\s\)\]"'']*)?')
if ($urlMatches.Count -gt 0) {
  $workerUrl = $urlMatches[$urlMatches.Count - 1].Value.TrimEnd('.', ',', ')', ']')
}

if ($workerUrl) {
  Open-Web $workerUrl
  Write-Host ""
  Write-Host "Worker URL: $workerUrl" -ForegroundColor Cyan
  Open-Web ($workerUrl.TrimEnd('/') + "/api/health")
} else {
  Write-Host "Deployment succeeded, but Wrangler did not expose a workers.dev URL in its output." -ForegroundColor Yellow
  Write-Host "Open your Worker from the Cloudflare dashboard." -ForegroundColor White
  Open-Web "https://dash.cloudflare.com/"
}

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " AXEL HUB WEBLOG DEPLOYMENT COMPLETE" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Cloudflare Dashboard: https://dash.cloudflare.com/" -ForegroundColor White
Write-Host "The only manual step is approving the Cloudflare login in the browser." -ForegroundColor Yellow
Write-Host ""
