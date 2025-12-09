# ==================== Reg to Bat Converter + Optional Cleanup ====================

Add-Type -AssemblyName System.Windows.Forms

# Modern folder picker (with address bar you can type/paste into)
$FolderPicker = New-Object System.Windows.Forms.OpenFileDialog
$FolderPicker.InitialDirectory = [Environment]::GetFolderPath('Desktop')
$FolderPicker.Filter = "Folders|`n"
$FolderPicker.FileName = "Select this folder and press Open"
$FolderPicker.Title = "Select the folder containing .reg files to convert"
$FolderPicker.ValidateNames = $false
$FolderPicker.CheckFileExists = $false
$FolderPicker.CheckPathExists = $true

if ($FolderPicker.ShowDialog() -ne "OK") {
    Write-Host "No folder selected. Exiting." -ForegroundColor Yellow
    exit
}

$SearchPath   = [System.IO.Path]::GetDirectoryName($FolderPicker.FileName)
$RegConverter = "C:\Program Files (x86)\RegConverter\RegConvert.exe"

Write-Host "Selected folder: $SearchPath`n" -ForegroundColor Cyan

# Verify RegConverter exists
if (-not (Test-Path $RegConverter)) {
    Write-Error "RegConverter not found at '$RegConverter'"
    Read-Host "Press Enter to exit"
    exit
}

$RegFiles = Get-ChildItem -Path $SearchPath -Filter *.reg -Recurse -File -ErrorAction SilentlyContinue

if ($RegFiles.Count -eq 0) {
    Write-Host "No .reg files found." -ForegroundColor Yellow
    Read-Host "Press Enter to close"
    exit
}

Write-Host "Found $($RegFiles.Count) .reg file(s). Processing..." -ForegroundColor Green

$SuccessCount = 0
$SkipCount    = 0
$FailCount    = 0
$CandidatesForDeletion = @()

foreach ($file in $RegFiles) {
    $RegFile = $file.FullName
    $BatFile = [System.IO.Path]::ChangeExtension($RegFile, ".bat")

    if (Test-Path $BatFile) {
        Write-Host "$($file.Name) → .bat already exists, skipping" -ForegroundColor Yellow
        $SkipCount++
        $CandidatesForDeletion += $RegFile   # safe to delete later
        continue
    }

    Write-Host "Converting $($file.Name)" -NoNewline

    $Arguments = "/S=`"$RegFile`" /O=`"$BatFile`" /T"
    $proc = Start-Process -FilePath $RegConverter -ArgumentList $Arguments -Wait -PassThru -NoNewWindow

    if ($proc.ExitCode -eq 0) {
        Write-Host " → SUCCESS" -ForegroundColor Green
        $SuccessCount++
        $CandidatesForDeletion += $RegFile   # conversion worked → safe to delete later
    } else {
        Write-Host " → FAILED (code $($proc.ExitCode))" -ForegroundColor Red
        $FailCount++
        # Do NOT add to deletion list if conversion failed
    }
}

# ==================== Summary ====================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Conversion complete!" -ForegroundColor Cyan
Write-Host "Converted : $SuccessCount" -ForegroundColor Green
Write-Host "Skipped   : $SkipCount (already existed)" -ForegroundColor Yellow
Write-Host "Failed    : $FailCount" -ForegroundColor Red
Write-Host "========================================`n" -ForegroundColor Cyan

# ==================== Optional Cleanup ====================
if ($CandidatesForDeletion.Count -gt 0) {
    Write-Host "$($CandidatesForDeletion.Count) .reg file(s) have a matching .bat and can be safely deleted." -ForegroundColor Magenta
    $answer = Read-Host "Do you want to delete all processed .reg files now? (Y/N)"

    if ($answer -match "^(y|yes|$)" -or $answer -eq "") {
        Write-Host "Deleting $($CandidatesForDeletion.Count) .reg files..." -ForegroundColor Red
        foreach ($reg in $CandidatesForDeletion) {
            Remove-Item -Path $reg -Force
            Write-Host "Deleted: $(Split-Path $reg -Leaf)"
        }
        Write-Host "`nAll done — .reg files removed!" -ForegroundColor Green
    } else {
        Write-Host "Cleanup skipped. .reg files remain untouched." -ForegroundColor Yellow
    }
} else {
    Write-Host "No .reg files are eligible for deletion." -ForegroundColor Yellow
}

Read-Host "`nPress Enter to close"