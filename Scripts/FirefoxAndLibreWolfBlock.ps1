<#
FirefoxAndLibreWolfBlock.ps1
Single script — blocks URLs in Firefox and/or LibreWolf (whichever is actually installed)
Uses one shared list: C:\Scripts\BrowserBlock.txt
Gracefully skips any browser whose .exe is missing.
#>

# Hard-coded location — non-negotiable
$ScriptDir   = 'C:\Scripts'
$BlockFile   = Join-Path $ScriptDir 'BrowserBlock.txt'

if (-not (Test-Path $BlockFile)) {
    Write-Error "BrowserBlock.txt not found at $BlockFile"
    pause
    exit 1
}

# Load and sanitize — one source of truth
$Domains = Get-Content -Path $BlockFile -Encoding UTF8 |
           ForEach-Object { ($_ -split '#',2)[0].Trim() } |
           Where-Object { $_ } |
           Sort-Object -Unique

if ($Domains.Count -eq 0) { Write-Host "No domains listed." ; exit 0 }

# JSON payload (identical for both browsers)
$Policy = @{
    policies = @{
        WebsiteFilter = @{
            Block = $Domains
        }
    }
}
$JsonContent = $Policy | ConvertTo-Json -Depth 10

# Function — atomic write to policies.json (only if browser exists)
function Deploy-Policy($BrowserName, $ExePath, $RootPath) {
    if (-not (Test-Path $ExePath)) {
        Write-Host "$BrowserName not installed ($ExePath missing) — skipping" -ForegroundColor Yellow
        return
    }

    $PoliciesDir  = "$RootPath\distribution"
    $PoliciesFile = "$PoliciesDir\policies.json"

    if (-not (Test-Path $PoliciesDir)) {
        New-Item -Path $PoliciesDir -ItemType Directory -Force | Out-Null
    }

    $TempFile = [System.IO.Path]::GetTempFileName()
    $JsonContent | Out-File -FilePath $TempFile -Encoding UTF8 -Force
    Move-Item -Path $TempFile -Destination $PoliciesFile -Force -ErrorAction SilentlyContinue

    Write-Host "$BrowserName → policies.json updated ($($Domains.Count) domains blocked)"
}

# Deploy only to browsers that actually exist
Deploy-Policy "Firefox"   "C:\Program Files\Mozilla Firefox\firefox.exe"   "C:\Program Files\Mozilla Firefox"
Deploy-Policy "LibreWolf" "C:\Program Files\LibreWolf\librewolf.exe"      "C:\Program Files\LibreWolf"

Write-Host "`nDone. Existing browsers updated — missing ones silently ignored."
Write-Host "Restart browsers for changes to take effect."