Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Crash Analyzer"
$form.Size = New-Object System.Drawing.Size(520, 520)
$form.StartPosition = "CenterScreen"

$resultsBox = New-Object System.Windows.Forms.TextBox
$resultsBox.Multiline = $true
$resultsBox.ScrollBars = "Vertical"
$resultsBox.Size = New-Object System.Drawing.Size(460, 200)
$resultsBox.Location = New-Object System.Drawing.Point(20, 20)
$form.Controls.Add($resultsBox)

$dumpSelector = New-Object System.Windows.Forms.ComboBox
$dumpSelector.Size = New-Object System.Drawing.Size(460, 30)
$dumpSelector.Location = New-Object System.Drawing.Point(20, 230)
$form.Controls.Add($dumpSelector)

$findDumpButton = New-Object System.Windows.Forms.Button
$findDumpButton.Text = "Find Latest Dump"
$findDumpButton.Size = New-Object System.Drawing.Size(150, 40)
$findDumpButton.Location = New-Object System.Drawing.Point(20, 280)
$form.Controls.Add($findDumpButton)

$findDumpButton.Add_Click({
    $searchPaths = @(
        "$env:USERPROFILE\Desktop\Dumps",
        "C:\Windows\Minidump",
        "C:\Windows\MEMORY.DMP"
    )

    $allDumps = @()
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $dumps = Get-ChildItem -Path $path -Filter *.dmp -ErrorAction SilentlyContinue
            $allDumps += $dumps
        }
    }

    if ($allDumps.Count -eq 0) {
        $resultsBox.Text = "⚠️ No dump files found in standard locations."
        return
    }

    $latestDump = $allDumps | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $dumpSelector.Items.Clear()
    $dumpSelector.Items.Add($latestDump.FullName)
    $dumpSelector.SelectedIndex = 0
    $resultsBox.Text = "✅ Latest dump file found:`r`n$($latestDump.FullName)"
})

$analyzeButton = New-Object System.Windows.Forms.Button
$analyzeButton.Text = "Analyze Dump"
$analyzeButton.Size = New-Object System.Drawing.Size(150, 40)
$analyzeButton.Location = New-Object System.Drawing.Point(180, 280)
$form.Controls.Add($analyzeButton)

$analyzeButton.Add_Click({
    $selectedDump = $dumpSelector.SelectedItem
    if (-not $selectedDump) {
        $resultsBox.Text = "⚠️ No dump file selected."
        return
    }

    $dumpchkPath = "C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\dumpchk.exe"
    if (-not (Test-Path $dumpchkPath)) {
        $resultsBox.Text = "⚠️ dumpchk.exe not found. Please install Windows Debugging Tools."
        return
    }

    $outputFile = "$env:TEMP\dumpchk_output.txt"
    Start-Process -FilePath $dumpchkPath -ArgumentList "`"$selectedDump`"" -RedirectStandardOutput $outputFile -NoNewWindow -Wait
    $output = Get-Content $outputFile

    $bugcheckLine = ($output | Select-String "BugCheck") | Select-Object -First 1
    $bugcheckCode = "Unknown"

    if ($bugcheckLine -and ($bugcheckLine -match "0x[0-9A-Fa-f]+")) {
        $bugcheckCode = $matches[0]
    }

    $lookup = @{
        "0x0000007E" = "System Thread Exception Not Handled"
        "0x00000050" = "PAGE_FAULT_IN_NONPAGED_AREA"
        "0x0000001A" = "MEMORY_MANAGEMENT"
        "0x0000003B" = "System Service Exception"
        "0x0000009F" = "Driver Power State Failure"
    }

    $description = if ($lookup.ContainsKey($bugcheckCode)) {
        $lookup[$bugcheckCode]
    } else {
        "⚠️ Bugcheck code not found in lookup table."
    }

    $timestamp = (Get-Item $selectedDump).LastWriteTime
    $sizeMB = [math]::Round((Get-Item $selectedDump).Length / 1MB, 2)

    $resultsBox.Text = "🧠 Dump Analysis:`r`n"
    $resultsBox.Text += "File: $([System.IO.Path]::GetFileName($selectedDump))`r`n"
    $resultsBox.Text += "Bugcheck Code: $bugcheckCode`r`n"
    $resultsBox.Text += "Meaning: $description`r`n"
    $resultsBox.Text += "Timestamp: $timestamp`r`n"
    $resultsBox.Text += "Size: $sizeMB MB"
})

$form.ShowDialog()
