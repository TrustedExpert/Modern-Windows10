<#
BlockChrome.ps1
Reads BlockChrome.txt from the same folder as this script and overwrites Chrome URLBlocklist in HKLM + HKCU
Run as Administrator for machine-wide (HKLM) enforcement.
#>

# Force script directory — works no matter how the script is invoked
$ScriptDir   = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
$BlockFile   = Join-Path $ScriptDir "BlockChrome.txt"

if (-not (Test-Path $BlockFile)) {
    Write-Error "BlockChrome.txt not found in script directory: $ScriptDir"
    pause
    exit 1
}

# Load and clean the list
$Domains = Get-Content -Path $BlockFile -Encoding UTF8 |
           ForEach-Object { ($_ -split '#',2)[0].Trim() } |
           Where-Object { $_ } |
           Sort-Object -Unique

if ($Domains.Count -eq 0) { Write-Host "No domains found." ; exit 0 }

# Registry paths
$RegHKLM = 'HKLM:\SOFTWARE\Policies\Google\Chrome\URLBlocklist'
$RegHKCU = 'HKCU:\SOFTWARE\Policies\Google\Chrome\URLBlocklist'

function Update-Blocklist($Path) {
    # Create key if missing
    if (-not (Test-Path $Path)) { New-Item $Path -Force | Out-Null }
    
    # Remove all existing numbered values
    Get-Item $Path | ForEach-Object {
        $_.Property | Where-Object { $_ -match '^\d+$' } | ForEach-Object { Remove-ItemProperty $Path -Name $_ -ErrorAction SilentlyContinue }
    }
    
    # Write new 1-based entries
    for ($i = 0; $i -lt $Domains.Count; $i++) {
        Set-ItemProperty -Path $Path -Name ($i+1) -Value $Domains[$i] -Type String
    }
}

# HKLM (requires elevation)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("Administrators")
if ($isAdmin) {
    Update-Blocklist $RegHKLM
    Write-Host "HKLM updated with $($Domains.Count) entries"
} else {
    Write-Warning "Not Administrator - skipping HKLM"
}

# HKCU (always)
Update-Blocklist $RegHKCU
Write-Host "HKCU updated with $($Domains.Count) entries"
Write-Host "Done. Restart Chrome or run gpupdate /force"