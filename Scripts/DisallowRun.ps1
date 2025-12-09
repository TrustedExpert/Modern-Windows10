<#
DisallowRun.ps1
Blocks executable filenames via Group Policy DisallowRun.
Reads DisallowRun.txt from C:\Scripts and enforces in HKLM + HKCU.
Run as Administrator for machine-wide enforcement.
#>

# Hard-coded location — non-negotiable
$ScriptDir   = 'C:\Scripts'
$BlockFile   = Join-Path $ScriptDir 'DisallowRun.txt'

if (-not (Test-Path $BlockFile)) {
    Write-Error "DisallowRun.txt not found at $BlockFile"
    pause
    exit 1
}

# Load and sanitize (comments with #, empty lines ignored, deduped)
$Programs = Get-Content -Path $BlockFile -Encoding UTF8 |
            ForEach-Object { ($_ -split '#',2)[0].Trim() } |
            Where-Object { $_ } |
            Sort-Object -Unique

if ($Programs.Count -eq 0) { Write-Host "No programs listed." ; exit 0 }

# Registry paths for Explorer DisallowRun
$RegHKLM = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\DisallowRun'
$RegHKCU = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\DisallowRun'

function Update-DisallowRun($Path) {
    # Ensure key exists
    if (-not (Test-Path $Path)) { New-Item $Path -Force | Out-Null }
    
    # Wipe old numbered entries
    Get-Item $Path | ForEach-Object {
        $_.Property | Where-Object { $_ -match '^\d+$' } | ForEach-Object {
            Remove-ItemProperty -Path $Path -Name $_ -ErrorAction SilentlyContinue
        }
    }
    
    # Write fresh 1-based list
    for ($i = 0; $i -lt $Programs.Count; $i++) {
        Set-ItemProperty -Path $Path -Name ($i+1) -Value $Programs[$i] -Type String
    }
}

# Enable the policy itself (required or the list is ignored)
$PolicyHKLM = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
$PolicyHKCU = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'

if (-not (Get-ItemProperty -Path $PolicyHKLM -Name 'DisallowRun' -ErrorAction SilentlyContinue)) {
    New-ItemProperty -Path $PolicyHKLM -Name 'DisallowRun' -Value 1 -PropertyType DWord -Force | Out-Null
}
if (-not (Get-ItemProperty -Path $PolicyHKCU -Name 'DisallowRun' -ErrorAction SilentlyContinue)) {
    New-ItemProperty -Path $PolicyHKCU -Name 'DisallowRun' -Value 1 -PropertyType DWord -Force | Out-Null
}

# HKLM (admin required)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("Administrators")
if ($isAdmin) {
    Update-DisallowRun $RegHKLM
    Write-Host "HKLM updated with $($Programs.Count) blocked programs"
} else {
    Write-Warning "Not Administrator - skipping HKLM"
}

# HKCU (always)
Update-DisallowRun $RegHKCU
Write-Host "HKCU updated with $($Programs.Count) blocked programs"
Write-Host "Done. Log off/on or restart Explorer for changes to take effect."