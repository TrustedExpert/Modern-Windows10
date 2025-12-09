Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Bulk File Renamer"
$form.Size = New-Object System.Drawing.Size(800, 620)
$form.StartPosition = "CenterScreen"
$form.MaximizeBox = $false

# --- Folder Selection ---
$lblFolder = New-Object System.Windows.Forms.Label
$lblFolder.Text = "Target Folder:"
$lblFolder.Location = New-Object System.Drawing.Point(20, 20)
$lblFolder.AutoSize = $true
$form.Controls.Add($lblFolder)

$txtFolder = New-Object System.Windows.Forms.TextBox
$txtFolder.Location = New-Object System.Drawing.Point(120, 18)
$txtFolder.Size = New-Object System.Drawing.Size(480, 25)
$txtFolder.ReadOnly = $true
$form.Controls.Add($txtFolder)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Location = New-Object System.Drawing.Point(610, 16)
$btnBrowse.Size = New-Object System.Drawing.Size(75, 29)
$btnBrowse.Text = "Browse..."
$form.Controls.Add($btnBrowse)

$btnSubmit = New-Object System.Windows.Forms.Button
$btnSubmit.Location = New-Object System.Drawing.Point(700, 16)
$btnSubmit.Size = New-Object System.Drawing.Size(75, 29)
$btnSubmit.Text = "Rename"
$btnSubmit.Enabled = $false
$btnSubmit.BackColor = "LightGreen"
$form.Controls.Add($btnSubmit)

# --- Rules Table ---
$lblRules = New-Object System.Windows.Forms.Label
$lblRules.Text = "Rename Rules (applied top to bottom):"
$lblRules.Location = New-Object System.Drawing.Point(20, 70)
$lblRules.AutoSize = $true
$form.Controls.Add($lblRules)

$dataGrid = New-Object System.Windows.Forms.DataGridView
$dataGrid.Location = New-Object System.Drawing.Point(20, 100)
$dataGrid.Size = New-Object System.Drawing.Size(740, 380)
$dataGrid.ColumnCount = 2
$dataGrid.ColumnHeadersVisible = $true
$dataGrid.Columns[0].Name = "Replace (text to find in filename)"
$dataGrid.Columns[0].Width = 360
$dataGrid.Columns[1].Name = "With (replace with - leave blank to remove)"
$dataGrid.Columns[1].Width = 360
$dataGrid.AllowUserToAddRows = $true
$dataGrid.AllowUserToDeleteRows = $true
$form.Controls.Add($dataGrid)

# --- Status ---
$status = New-Object System.Windows.Forms.Label
$status.Location = New-Object System.Drawing.Point(20, 500)
$status.Size = New-Object System.Drawing.Size(740, 60)
$status.Text = "Select a folder and add rules → then click Rename"
$status.ForeColor = "Blue"
$form.Controls.Add($status)

# --- Browse Folder ---
$btnBrowse.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select folder containing files to rename"
    if ($dialog.ShowDialog() -eq "OK") {
        $txtFolder.Text = $dialog.SelectedPath
        $btnSubmit.Enabled = $true
        $status.Text = "Ready: $($dialog.SelectedPath)"
        $status.ForeColor = "Green"
    }
})

# --- Rename Logic ---
$btnSubmit.Add_Click({
    $folder = $txtFolder.Text
    if (-not (Test-Path $folder)) {
        [System.Windows.Forms.MessageBox]::Show("Folder not found!", "Error", 0, "Error")
        return
    }

    # Collect rules
    $rules = @()
    foreach ($row in $dataGrid.Rows) {
        if ($row.IsNewRow) { continue }
        $find = $row.Cells[0].Value
        $with = $row.Cells[1].Value
        if ($find -and $find.ToString().Trim() -ne "") {
            $rules += @{
                Find = $find.ToString().Trim()
                With = if ($null -eq $with) { "" } else { $with.ToString() }
            }
        }
    }

    if ($rules.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Add at least one rule!", "No Rules", 0, "Warning")
        return
    }

    $btnSubmit.Enabled = $false
    $status.Text = "Renaming files... (this may take a while)"
    $status.ForeColor = "Orange"
    $form.Refresh()

    $renamed = 0
    $errors  = 0

    Get-ChildItem -Path $folder -File -Recurse | ForEach-Object {
        $oldName = $_.Name
        $newName = $oldName

        foreach ($rule in $rules) {
            # Case-sensitive? Change to -creplace if you want case-sensitive
            $newName = $newName -replace [regex]::Escape($rule.Find), $rule.With
        }

        if ($newName -ne $oldName) {
            $newFullPath = Join-Path $_.Directory.FullName $newName
            try {
                Rename-Item -Path $_.FullName -NewName $newName -ErrorAction Stop
                $renamed++
            }
            catch {
                $errors++
                Write-Host "Failed: $($_.FullName) → $newName  | Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }

    $status.Text = "Done! Renamed: $renamed file(s).  Errors: $errors"
    $status.ForeColor = if ($errors -eq 0) { "DarkGreen" } else { "Red" }
    $btnSubmit.Enabled = $true
})

# Show form
$form.ShowDialog() | Out-Null