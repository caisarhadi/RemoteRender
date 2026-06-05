# ============================================================
# MRQ Render Launcher - PowerShell GUI
# ============================================================
# Dark-themed Windows Forms GUI for launching Unreal Engine
# Movie Render Queue renders locally or on remote PCs via
# Plastic SCM job dispatch. Supports listening mode for
# remote PCs to auto-pick up and execute render jobs.
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Force Title Bar Dark Mode (Windows 10/11) ---
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class DwmHelper {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
}
"@

# ============================================================
# CONFIGURATION
# ============================================================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ConfigFile = Join-Path $ScriptDir "RenderConfig.bat"
$PythonScript = Join-Path $ScriptDir "MRQ_Python_Executor.py"
$CancelMarker = Join-Path $ScriptDir "render_cancelled.marker"

# Default paths (will be overridden by RenderConfig.bat if it exists)
$EnginePath = "C:\Program Files\Epic Games\UE_5.7\Engine\Binaries\Win64\UnrealEditor-Cmd.exe"
$ProjectPath = "D:\Project\MyProject.uproject"
$MyIdentity = "Local (This PC)"
$MyListen = $false

# Read existing config
if (Test-Path $ConfigFile) {
    $configContent = Get-Content $ConfigFile
    foreach ($line in $configContent) {
        if ($line -match 'set ENGINE=(.+)') { $EnginePath = $Matches[1].Trim('"') }
        if ($line -match 'set PROJECT=(.+)') { $ProjectPath = $Matches[1].Trim('"') }
        if ($line -match 'set IDENTITY=(.+)') { $MyIdentity = $Matches[1].Trim('"') }
        if ($line -match 'set LISTEN=(.+)') { $MyListen = $Matches[1].Trim('"') -eq 'TRUE' }
    }
}

# ============================================================
# QUEUE & PASS DEFINITIONS
# ============================================================
$Sequences = @(
    @{ Code="0010"; Name="Opening Sequence"; Queue="/Game/NOAH_KAHAN/NK_Sequencer_MRQ_Presets/Render_Queue/NK_RenderQueue_0010_OpeningSequence.NK_RenderQueue_0010_OpeningSequence" },
    @{ Code="0090"; Name="False Confidence"; Queue="/Game/NOAH_KAHAN/NK_Sequencer_MRQ_Presets/Render_Queue/NK_RenderQueue_0090_FalseConfidence.NK_RenderQueue_0090_FalseConfidence" },
    @{ Code="0110"; Name="Staying Still";    Queue="/Game/NOAH_KAHAN/NK_Sequencer_MRQ_Presets/Render_Queue/NK_RenderQueue_0110_StayingStill.NK_RenderQueue_0110_StayingStill" },
    @{ Code="0130"; Name="Dial Drunk";       Queue="/Game/NOAH_KAHAN/NK_Sequencer_MRQ_Presets/Render_Queue/NK_RenderQueue_0130_DialDrunk.NK_RenderQueue_0130_DialDrunk" },
    @{ Code="0190"; Name="Northern Attitude"; Queue="/Game/NOAH_KAHAN/NK_Sequencer_MRQ_Presets/Render_Queue/NK_RenderQueue_0190_NorthernAttitude.NK_RenderQueue_0190_NorthernAttitude" },
    @{ Code="0210"; Name="Orange Juice";     Queue="/Game/NOAH_KAHAN/NK_Sequencer_MRQ_Presets/Render_Queue/NK_RenderQueue_0210_OrangeJuice.NK_RenderQueue_0210_OrangeJuice" }
)

# Number of job slots (passes) per queue. Each queue is assumed to have
# jobs in the same order. The GUI shows numbered checkboxes (Pass 1..N).
$PassCount = 5

# ============================================================
# COLOR PALETTE - Dark Greyscale
# ============================================================
$cBack     = [System.Drawing.ColorTranslator]::FromHtml('#1A1A1A')
$cSurface  = [System.Drawing.ColorTranslator]::FromHtml('#252525')
$cPanel    = [System.Drawing.ColorTranslator]::FromHtml('#2F2F2F')
$cText     = [System.Drawing.ColorTranslator]::FromHtml('#E0E0E0')
$cTextDim  = [System.Drawing.ColorTranslator]::FromHtml('#888888')
$cBtnBg    = [System.Drawing.ColorTranslator]::FromHtml('#3A3A3A')
$cBtnLaunch = [System.Drawing.ColorTranslator]::FromHtml('#505050')
$cBorder   = [System.Drawing.ColorTranslator]::FromHtml('#444444')
$cSection  = [System.Drawing.ColorTranslator]::FromHtml('#CCCCCC')

# Fonts
$fontTitle   = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$fontSection = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
$fontBody    = New-Object System.Drawing.Font("Segoe UI", 9.5)
$fontSmall   = New-Object System.Drawing.Font("Segoe UI", 8.5)
$fontBtn     = New-Object System.Drawing.Font("Segoe UI Semibold", 11)

# ============================================================
# UI HELPER FUNCTIONS
# ============================================================

# Ctrl+A handler for TextBoxes (WinForms does not support this natively)
$ctrlAHandler = {
    if ($_.Control -and $_.KeyCode -eq 'A') {
        $this.SelectAll()
        $_.SuppressKeyPress = $true
    }
}

function New-StyledLabel {
    param($Text, $Font, $ForeColor, $X, $Y, $W, $H, $Parent)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Text
    $lbl.Font = $Font
    $lbl.ForeColor = $ForeColor
    $lbl.Location = New-Object System.Drawing.Point($X, $Y)
    $lbl.Size = New-Object System.Drawing.Size($W, $H)
    $Parent.Controls.Add($lbl)
    return $lbl
}

function New-StyledTextBox {
    param($Text, $Font, $X, $Y, $W, $Parent)
    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Text = $Text
    $txt.Font = $Font
    $txt.BackColor = $cPanel
    $txt.ForeColor = $cText
    $txt.BorderStyle = 'FixedSingle'
    $txt.Location = New-Object System.Drawing.Point($X, $Y)
    $txt.Size = New-Object System.Drawing.Size($W, 22)
    $txt.Add_KeyDown($ctrlAHandler)
    $Parent.Controls.Add($txt)
    return $txt
}

function New-StyledComboBox {
    param($Items, $X, $Y, $W, $Parent)
    $cmb = New-Object System.Windows.Forms.ComboBox
    $cmb.Font = $fontBody
    $cmb.BackColor = $cPanel
    $cmb.ForeColor = $cText
    $cmb.FlatStyle = 'Flat'
    $cmb.DropDownStyle = 'DropDownList'
    $cmb.Location = New-Object System.Drawing.Point($X, $Y)
    $cmb.Size = New-Object System.Drawing.Size($W, 24)
    foreach ($item in $Items) { [void]$cmb.Items.Add($item) }
    $cmb.SelectedIndex = 0
    $Parent.Controls.Add($cmb)
    return $cmb
}

function New-StyledCheckBox {
    param($Text, $Font, $ForeColor, $BackColor, $X, $Y, $Checked, $Parent)
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $Text
    $cb.Font = $Font
    $cb.ForeColor = $ForeColor
    $cb.BackColor = $BackColor
    $cb.Location = New-Object System.Drawing.Point($X, $Y)
    $cb.AutoSize = $true
    $cb.Checked = $Checked
    $Parent.Controls.Add($cb)
    return $cb
}

function New-SmallButton {
    param($Text, $X, $Y, $Parent)
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Font = $fontSmall
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 1
    $btn.FlatAppearance.BorderColor = $cBorder
    $btn.BackColor = $cBtnBg
    $btn.ForeColor = $cTextDim
    $btn.Size = New-Object System.Drawing.Size(50, 22)
    $btn.Location = New-Object System.Drawing.Point($X, $Y)
    $Parent.Controls.Add($btn)
    return $btn
}

function New-SectionHeader {
    param($Text, $Y, $Parent)
    return (New-StyledLabel -Text $Text -Font $fontSection -ForeColor $cSection -X 20 -Y $Y -W 300 -H 20 -Parent $Parent)
}

# ============================================================
# SHARED FUNCTIONS
# ============================================================

function Save-RenderConfig {
    "set ENGINE=`"$($txtEngine.Text)`"" | Out-File -FilePath $ConfigFile -Encoding ascii
    "set PROJECT=`"$($txtProject.Text)`"" | Out-File -FilePath $ConfigFile -Encoding ascii -Append
    "set IDENTITY=`"$($global:CachedIdentity)`"" | Out-File -FilePath $ConfigFile -Encoding ascii -Append
    $listenVal = if ($cbListen.Checked) { 'TRUE' } else { 'FALSE' }
    "set LISTEN=`"$listenVal`"" | Out-File -FilePath $ConfigFile -Encoding ascii -Append
}

function Sync-PlasticSCM {
    param($ProjectPath, $ShouldRevert)
    $lblStatus.Text = "Syncing latest changes from Plastic SCM..."
    $form.Refresh()

    $projDir = Split-Path -Parent $ProjectPath
    Push-Location -Path $projDir
    try {
        if ($ShouldRevert) {
            $lblStatus.Text = "Reverting local changes in Plastic SCM..."
            $form.Refresh()
            & "cm" undo "$ScriptDir" -R
        }
        $lblStatus.Text = "Syncing latest changes from Plastic SCM..."
        $form.Refresh()
        & "cm" update
    } catch {
        Write-Host "Plastic SCM sync failed or 'cm' not found. Continuing..."
    }
    Pop-Location
}

function Submit-RemoteJobs {
    param($TargetName, $SelectedSeqs, $BaseArgs, $OverrideArgs, $JobIndicesArg)
    $jobsDir = Join-Path $ScriptDir "Jobs"
    if (-not (Test-Path $jobsDir)) { New-Item -ItemType Directory -Force -Path $jobsDir | Out-Null }

    $lblStatus.Text = "Generating jobs for $TargetName..."
    $form.Refresh()

    foreach ($seqCb in $SelectedSeqs) {
        $seq = $seqCb.Tag
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmssfff"
        $jobFile = Join-Path $jobsDir "${TargetName}_$($seq.Code)_${timestamp}.json"

        $jobObj = @{
            TargetMachine = $TargetName
            SequenceCode = $seq.Code
            SequenceName = $seq.Name
            Queue = $seq.Queue
            BaseArgs = $BaseArgs
            OverrideArgs = $OverrideArgs
            JobIndicesArg = $JobIndicesArg
            SubmittedAt = (Get-Date -Format "o")
        }
        $jobObj | ConvertTo-Json | Out-File -FilePath $jobFile -Encoding UTF8
    }

    $lblStatus.Text = "Pushing jobs to Plastic SCM..."
    $form.Refresh()

    Push-Location -Path $ScriptDir
    try {
        & "cm" add "$jobsDir" -R 2>$null
        & "cm" checkin "$jobsDir" -m "Submitting render jobs to $TargetName"
        $lblStatus.Text = "Successfully queued $($SelectedSeqs.Count) sequence(s) to $TargetName."
    } catch {
        $lblStatus.Text = "Failed to push jobs to Plastic SCM."
    }
    Pop-Location
}

function Invoke-LocalRender {
    param($SelectedSeqs, $SelectedPasses, $EnginePath, $ProjectPath, $BaseArgs, $OverrideArgs, $JobIndicesArg, $PassList)

    $totalSeqs = $SelectedSeqs.Count
    $totalJobs = $SelectedSeqs.Count * $SelectedPasses.Count
    $cancelled = $false
    $taskNum = 0

    foreach ($seqCb in $SelectedSeqs) {
        if ($cancelled -or $global:FormClosing) { break }

        $seq = $seqCb.Tag
        $taskNum++
        $jobsDone = ($taskNum - 1) * $SelectedPasses.Count
        $lblStatus.Text = "Sequence $taskNum / $totalSeqs : $($seq.Name) - $PassList ($jobsDone of $totalJobs jobs done)..."
        $form.Refresh()

        $cmdArgs = "`"$ProjectPath`" $BaseArgs -ExecutePythonScript=`"$PythonScript`" -Queue=`"$($seq.Queue)`" $OverrideArgs $JobIndicesArg"
        $process = Start-Process -FilePath $EnginePath -ArgumentList $cmdArgs -PassThru

        # Non-blocking wait: keep the GUI responsive via DoEvents()
        while (-not $process.HasExited) {
            [System.Windows.Forms.Application]::DoEvents()
            if ($global:FormClosing) { break }
            $lblStatus.Text = "Waiting for UnrealEditor-Cmd.exe (PID: $($process.Id)) to fully close in the background..."
            Start-Sleep -Milliseconds 500
        }

        # Check for cancel marker written by the Python script
        if (Test-Path $CancelMarker) {
            Remove-Item $CancelMarker -Force
            $cancelled = $true
            $jobsCancelled = ($taskNum - 1) * $SelectedPasses.Count + $SelectedPasses.Count
            $lblStatus.Text = "Render cancelled by user. Stopped after sequence $taskNum / $totalSeqs ($jobsCancelled of $totalJobs jobs)."
            $form.Refresh()
            break
        }
    }

    if (-not $cancelled) {
        $lblStatus.Text = "Completed all $totalSeqs sequence(s), $totalJobs job(s)."
    }
}

# ============================================================
# GLOBAL STATE
# ============================================================
$global:FormClosing = $false
$global:CachedIdentity = $MyIdentity
$global:IsRendering = $false

# ============================================================
# MAIN FORM
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "MRQ Render Launcher"
$form.Size = New-Object System.Drawing.Size(620, 950)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $cBack
$form.ForeColor = $cText
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.Font = $fontBody

$y = 15

# ============================================================
# UI LAYOUT - Title
# ============================================================
$lblTitle = New-StyledLabel -Text "MRQ Render Launcher" -Font $fontTitle -ForeColor $cText -X 20 -Y $y -W 560 -H 30 -Parent $form
$y += 35

# ============================================================
# UI LAYOUT - Path Configuration
# ============================================================
New-SectionHeader -Text "PATH CONFIGURATION" -Y $y -Parent $form | Out-Null
$y += 24

$configPanel = New-Object System.Windows.Forms.Panel
$configPanel.Location = New-Object System.Drawing.Point(20, $y)
$configPanel.Size = New-Object System.Drawing.Size(560, 140)
$configPanel.BackColor = $cSurface
$form.Controls.Add($configPanel)

New-StyledLabel -Text "PC ID:" -Font $fontSmall -ForeColor $cTextDim -X 10 -Y 10 -W 100 -H 18 -Parent $configPanel | Out-Null
$cmbIdentity = New-StyledComboBox -Items @("Local (This PC)", "PC 002", "PC 003", "PC 004") -X 115 -Y 8 -W 435 -Parent $configPanel
$idx = $cmbIdentity.Items.IndexOf($MyIdentity)
if ($idx -ge 0) { $cmbIdentity.SelectedIndex = $idx }

New-StyledLabel -Text "Engine:" -Font $fontSmall -ForeColor $cTextDim -X 10 -Y 42 -W 55 -H 18 -Parent $configPanel | Out-Null
$txtEngine = New-StyledTextBox -Text $EnginePath -Font $fontSmall -X 70 -Y 40 -W 480 -Parent $configPanel

New-StyledLabel -Text "Project:" -Font $fontSmall -ForeColor $cTextDim -X 10 -Y 74 -W 55 -H 18 -Parent $configPanel | Out-Null
$txtProject = New-StyledTextBox -Text $ProjectPath -Font $fontSmall -X 70 -Y 72 -W 480 -Parent $configPanel

$cbListen = New-StyledCheckBox -Text "Enable Listening Mode (Auto-Render Remote Jobs)" -Font $fontSmall -ForeColor $cText -BackColor $cSurface -X 10 -Y 106 -Checked $MyListen -Parent $configPanel

$y += 152

# ============================================================
# UI LAYOUT - Sequences
# ============================================================
New-SectionHeader -Text "SEQUENCES" -Y $y -Parent $form | Out-Null
$btnSeqAll  = New-SmallButton -Text "All"  -X 485 -Y $y -Parent $form
$btnSeqNone = New-SmallButton -Text "None" -X 540 -Y $y -Parent $form
$y += 24

$seqPanel = New-Object System.Windows.Forms.Panel
$seqPanel.Location = New-Object System.Drawing.Point(20, $y)
$seqPanel.Size = New-Object System.Drawing.Size(560, 142)
$seqPanel.BackColor = $cSurface
$form.Controls.Add($seqPanel)

$seqCheckboxes = @()
$sy = 8
foreach ($seq in $Sequences) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = "  [$($seq.Code)]  $($seq.Name)"
    $cb.Font = $fontBody
    $cb.ForeColor = $cText
    $cb.BackColor = $cSurface
    $cb.Location = New-Object System.Drawing.Point(12, $sy)
    $cb.Size = New-Object System.Drawing.Size(530, 20)
    $cb.Tag = $seq
    $seqPanel.Controls.Add($cb)
    $seqCheckboxes += $cb
    $sy += 21
}

$y += 152

# ============================================================
# UI LAYOUT - Passes
# ============================================================
New-SectionHeader -Text "PASSES (Job Index)" -Y $y -Parent $form | Out-Null
$btnPassAll  = New-SmallButton -Text "All"  -X 485 -Y $y -Parent $form
$btnPassNone = New-SmallButton -Text "None" -X 540 -Y $y -Parent $form
$y += 24

$passPanel = New-Object System.Windows.Forms.Panel
$passPanel.Location = New-Object System.Drawing.Point(20, $y)
$passPanel.Size = New-Object System.Drawing.Size(560, 38)
$passPanel.BackColor = $cSurface
$form.Controls.Add($passPanel)

$passCheckboxes = @()
$px = 12
for ($i = 1; $i -le $PassCount; $i++) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = "  Pass $i"
    $cb.Font = $fontBody
    $cb.ForeColor = $cText
    $cb.BackColor = $cSurface
    $cb.Location = New-Object System.Drawing.Point($px, 9)
    $cb.AutoSize = $true
    $cb.Checked = $false
    $cb.Tag = $i  # Store the 1-based index
    $passPanel.Controls.Add($cb)
    $passCheckboxes += $cb
    $px += 108
}

$y += 48

# ============================================================
# UI LAYOUT - Render Settings
# ============================================================
New-SectionHeader -Text "RENDER SETTINGS" -Y $y -Parent $form | Out-Null
$y += 24

$settingsPanel = New-Object System.Windows.Forms.Panel
$settingsPanel.Location = New-Object System.Drawing.Point(20, $y)
$settingsPanel.Size = New-Object System.Drawing.Size(560, 190)
$settingsPanel.BackColor = $cSurface
$form.Controls.Add($settingsPanel)

New-StyledLabel -Text "Resolution:" -Font $fontBody -ForeColor $cTextDim -X 15 -Y 15 -W 130 -H 20 -Parent $settingsPanel | Out-Null
$cmbRes = New-StyledComboBox -Items @("Half Res  (4968 x 1296)  -  Default", "Full Res  (9936 x 2592)", "Quarter Res  (2484 x 648)") -X 150 -Y 12 -W 390 -Parent $settingsPanel

New-StyledLabel -Text "Spatial Samples:" -Font $fontBody -ForeColor $cTextDim -X 15 -Y 50 -W 130 -H 20 -Parent $settingsPanel | Out-Null
$txtSpatial = New-StyledTextBox -Text "1" -Font $fontBody -X 150 -Y 48 -W 80 -Parent $settingsPanel
New-StyledLabel -Text "Default: 1" -Font $fontSmall -ForeColor $cTextDim -X 240 -Y 50 -W 200 -H 18 -Parent $settingsPanel | Out-Null

New-StyledLabel -Text "Temporal Samples:" -Font $fontBody -ForeColor $cTextDim -X 15 -Y 85 -W 130 -H 20 -Parent $settingsPanel | Out-Null
$txtTemporal = New-StyledTextBox -Text "1" -Font $fontBody -X 150 -Y 83 -W 80 -Parent $settingsPanel
New-StyledLabel -Text "Default: 1" -Font $fontSmall -ForeColor $cTextDim -X 240 -Y 85 -W 200 -H 18 -Parent $settingsPanel | Out-Null

New-StyledLabel -Text "Warm-Up Frames:" -Font $fontBody -ForeColor $cTextDim -X 15 -Y 120 -W 130 -H 20 -Parent $settingsPanel | Out-Null
$txtWarmup = New-StyledTextBox -Text "32" -Font $fontBody -X 150 -Y 118 -W 80 -Parent $settingsPanel
New-StyledLabel -Text "Default: 32" -Font $fontSmall -ForeColor $cTextDim -X 240 -Y 120 -W 200 -H 18 -Parent $settingsPanel | Out-Null

$cbNoSound = New-StyledCheckBox -Text "  No Sound  (disable audio - required for silent headless renders, disables WAV export)" -Font $fontSmall -ForeColor $cText -BackColor $cSurface -X 12 -Y 155 -Checked $true -Parent $settingsPanel

$y += 200

# ============================================================
# UI LAYOUT - Dispatch Options
# ============================================================
$y += 10

$cbSync   = New-StyledCheckBox -Text "Update to latest Plastic SCM workspace before rendering" -Font $fontSmall -ForeColor $cText -BackColor $cBack -X 20 -Y $y -Checked $true -Parent $form
$y += 24

$cbRevert = New-StyledCheckBox -Text "Revert uncommitted local changes before update (Warning: Destructive)" -Font $fontSmall -ForeColor $cTextDim -BackColor $cBack -X 20 -Y $y -Checked $false -Parent $form
$y += 30

New-StyledLabel -Text "TARGET PC:" -Font $fontSmall -ForeColor $cTextDim -X 20 -Y ($y + 2) -W 100 -H 18 -Parent $form | Out-Null
$cmbTarget = New-StyledComboBox -Items @("Local (This PC)", "PC 002", "PC 003", "PC 004") -X 125 -Y $y -W 455 -Parent $form
$y += 40

# ============================================================
# UI LAYOUT - Bottom Buttons
# ============================================================
$y += 10

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = ""
$lblStatus.Font = $fontSmall
$lblStatus.ForeColor = $cTextDim
$lblStatus.Location = New-Object System.Drawing.Point(20, $y)
$lblStatus.Size = New-Object System.Drawing.Size(560, 18)
$lblStatus.TextAlign = 'MiddleCenter'
$form.Controls.Add($lblStatus)

$y += 22

$btnOpenFolder = New-Object System.Windows.Forms.Button
$btnOpenFolder.Text = "Output Folder"
$btnOpenFolder.Font = $fontBtn
$btnOpenFolder.FlatStyle = 'Flat'
$btnOpenFolder.FlatAppearance.BorderSize = 1
$btnOpenFolder.FlatAppearance.BorderColor = $cBorder
$btnOpenFolder.BackColor = $cBtnBg
$btnOpenFolder.ForeColor = $cText
$btnOpenFolder.Size = New-Object System.Drawing.Size(180, 48)
$btnOpenFolder.Location = New-Object System.Drawing.Point(20, $y)
$btnOpenFolder.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnOpenFolder)

$btnLaunch = New-Object System.Windows.Forms.Button
$btnLaunch.Text = "Launch Render"
$btnLaunch.Font = $fontBtn
$btnLaunch.FlatStyle = 'Flat'
$btnLaunch.FlatAppearance.BorderSize = 0
$btnLaunch.BackColor = $cBtnLaunch
$btnLaunch.ForeColor = $cText
$btnLaunch.Size = New-Object System.Drawing.Size(370, 48)
$btnLaunch.Location = New-Object System.Drawing.Point(210, $y)
$btnLaunch.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnLaunch)

# ============================================================
# LISTENER TIMER
# ============================================================
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 30000 # 30 seconds

# ============================================================
# EVENT HANDLERS
# All event wiring is grouped here, after every control exists.
# ============================================================

# --- Form Events ---
$form.Add_Shown({
    $mode = 1
    [DwmHelper]::DwmSetWindowAttribute($form.Handle, 20, [ref]$mode, 4) | Out-Null
    $form.Refresh()
    # Auto-start timer if Listen Mode was saved as enabled
    if ($cbListen.Checked -and $global:CachedIdentity -ne "Local (This PC)") {
        $timer.Start()
        $lblStatus.Text = "Listening Mode enabled. Polling every 30s..."
    }
})

$form.Add_FormClosing({
    $global:FormClosing = $true
    $timer.Stop()
})

# --- Dropdown flicker prevention ---
# Pausing the timer while any ComboBox is open prevents the tick
# handler from interfering with the dropdown popup on the UI thread.
$cmbIdentity.Add_DropDown({ $timer.Stop() })
$cmbIdentity.Add_DropDownClosed({ if ($cbListen.Checked) { $timer.Start() } })
$cmbRes.Add_DropDown({ $timer.Stop() })
$cmbRes.Add_DropDownClosed({ if ($cbListen.Checked) { $timer.Start() } })
$cmbTarget.Add_DropDown({ $timer.Stop() })
$cmbTarget.Add_DropDownClosed({ if ($cbListen.Checked) { $timer.Start() } })

# --- Config auto-save on PC ID change ---
$cmbIdentity.Add_SelectedIndexChanged({
    $global:CachedIdentity = $cmbIdentity.SelectedItem.ToString()
    Save-RenderConfig
})

# --- Listen Mode toggle ---
$cbListen.Add_CheckedChanged({
    Save-RenderConfig
    if ($cbListen.Checked -and $cmbIdentity.SelectedItem.ToString() -ne "Local (This PC)") {
        $timer.Start()
        $lblStatus.Text = "Listening Mode enabled. Polling every 30s..."
    } else {
        $timer.Stop()
        if (-not $cbListen.Checked) { $lblStatus.Text = "" }
    }
})

# --- Select All / Deselect All ---
$btnSeqAll.Add_Click({ foreach ($cb in $seqCheckboxes) { $cb.Checked = $true } })
$btnSeqNone.Add_Click({ foreach ($cb in $seqCheckboxes) { $cb.Checked = $false } })
$btnPassAll.Add_Click({ foreach ($cb in $passCheckboxes) { $cb.Checked = $true } })
$btnPassNone.Add_Click({ foreach ($cb in $passCheckboxes) { $cb.Checked = $false } })

# --- Output Folder button ---
$btnOpenFolder.Add_Click({
    $projDir = Split-Path -Parent $txtProject.Text
    $renderDir = Join-Path $projDir "Saved\MovieRenders"
    if (Test-Path $renderDir) {
        Start-Process "explorer.exe" $renderDir
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Render output folder not found:`n$renderDir`n`nIt will be created after the first render.",
            "Folder Not Found", 'OK', 'Information')
    }
})

# --- Launch Render button ---
$btnLaunch.Add_Click({
    $global:IsRendering = $true

    # Validate selection
    $selectedSeqs = $seqCheckboxes | Where-Object { $_.Checked }
    $selectedPasses = $passCheckboxes | Where-Object { $_.Checked }

    if ($selectedSeqs.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one sequence.", "No Sequences Selected", 'OK', 'Warning')
        $global:IsRendering = $false
        return
    }
    if ($selectedPasses.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one pass.", "No Passes Selected", 'OK', 'Warning')
        $global:IsRendering = $false
        return
    }

    Save-RenderConfig

    # Resolution mapping
    switch ($cmbRes.SelectedIndex) {
        0 { $resX = "4968"; $resY = "1296" }
        1 { $resX = "9936"; $resY = "2592" }
        2 { $resX = "2484"; $resY = "648" }
    }

    # Build command arguments
    $baseArgs = "-log -notexturestreaming -unattended"
    if ($cbNoSound.Checked) { $baseArgs += " -nosound" }

    $overrideArgs = "-RenderResX=$resX -RenderResY=$resY"
    if ($txtSpatial.Text.Trim() -ne "") { $overrideArgs += " -Spatial=$($txtSpatial.Text.Trim())" }
    if ($txtTemporal.Text.Trim() -ne "") { $overrideArgs += " -Temporal=$($txtTemporal.Text.Trim())" }
    if ($txtWarmup.Text.Trim() -ne "") { $overrideArgs += " -WarmUp=$($txtWarmup.Text.Trim())" }

    # Build job indices filter (only if not ALL passes are selected)
    $allPassesSelected = ($selectedPasses.Count -eq $passCheckboxes.Count)
    $jobIndicesArg = ""
    if (-not $allPassesSelected) {
        $indices = ($selectedPasses | ForEach-Object { $_.Tag }) -join ","
        $jobIndicesArg = "-JobIndices=$indices"
    }

    $totalSeqs = $selectedSeqs.Count
    $totalJobs = $selectedSeqs.Count * $selectedPasses.Count
    $seqList = ($selectedSeqs | ForEach-Object { $_.Tag.Code }) -join ", "
    $passList = if ($allPassesSelected) { "ALL" } else { ($selectedPasses | ForEach-Object { "Pass $($_.Tag)" }) -join ", " }

    # Clean up any stale cancel marker
    if (Test-Path $CancelMarker) { Remove-Item $CancelMarker -Force }

    # Optional Plastic SCM sync
    if ($cbSync.Checked) {
        Sync-PlasticSCM -ProjectPath $txtProject.Text -ShouldRevert $cbRevert.Checked
    }

    $lblStatus.Text = "Starting $totalSeqs sequence(s), $totalJobs total job(s): Seq[$seqList] Pass[$passList] @ ${resX}x${resY}"
    $form.Refresh()

    $targetName = $cmbTarget.SelectedItem.ToString()
    if ($targetName -ne "Local (This PC)") {
        Submit-RemoteJobs -TargetName $targetName -SelectedSeqs $selectedSeqs -BaseArgs $baseArgs -OverrideArgs $overrideArgs -JobIndicesArg $jobIndicesArg
    } else {
        Invoke-LocalRender -SelectedSeqs $selectedSeqs -SelectedPasses $selectedPasses -EnginePath $txtEngine.Text -ProjectPath $txtProject.Text -BaseArgs $baseArgs -OverrideArgs $overrideArgs -JobIndicesArg $jobIndicesArg -PassList $passList
    }

    $global:IsRendering = $false
})

# --- Listener Timer Tick ---
$timer.Add_Tick({
    if ($global:IsRendering) { return }
    if (-not $cbListen.Checked) { return }
    $identity = $global:CachedIdentity
    if ($identity -eq "Local (This PC)") { return }

    # Sync workspace to pull any new Jobs
    # cm update is workspace-wide (no subfolder path arg) - it detects the workspace from cwd
    $lblStatus.Text = "Listening: Polling Plastic SCM..."
    $form.Refresh()
    Push-Location -Path $ScriptDir
    try { & "cm" update } catch {}
    Pop-Location

    $jobsDir = Join-Path $ScriptDir "Jobs"
    if (-not (Test-Path $jobsDir)) { return }

    $pendingJobs = Get-ChildItem -Path $jobsDir -Filter "${identity}_*.json" | Sort-Object CreationTime
    if ($pendingJobs.Count -gt 0) {
        $jobFile = $pendingJobs[0].FullName

        # Check human activity
        $uiOpen = Get-Process "UnrealEditor" -ErrorAction SilentlyContinue
        if ($uiOpen) { return }

        $global:IsRendering = $true
        $lblStatus.Text = "Listening Mode: Found remote job. Syncing heavy project..."
        $form.Refresh()

        # Parse job
        $jobData = Get-Content -Path $jobFile -Raw | ConvertFrom-Json
        $projectVal = $txtProject.Text
        $engineVal = $txtEngine.Text

        # Claim job immediately: remove from Plastic SCM before rendering.
        # This prevents re-execution if this PC crashes or another PC picks it up.
        $lblStatus.Text = "Listening Mode: Claiming job $($jobData.SequenceName)..."
        $form.Refresh()
        Push-Location -Path $ScriptDir
        try {
            & "cm" remove "$jobFile"
            & "cm" checkin "$jobsDir" -m "Claimed render job for $($jobData.SequenceName)"
        } catch {}
        Pop-Location

        # Sync the heavy Unreal project before rendering
        $projDir = Split-Path -Parent $projectVal
        Push-Location -Path $projDir
        try { & "cm" update } catch {}
        Pop-Location

        $lblStatus.Text = "Listening Mode: Executing remote job $($jobData.SequenceName)..."
        $form.Refresh()

        $cmdArgs = "`"$projectVal`" $($jobData.BaseArgs) -ExecutePythonScript=`"$PythonScript`" -Queue=`"$($jobData.Queue)`" $($jobData.OverrideArgs) $($jobData.JobIndicesArg)"
        $process = Start-Process -FilePath $engineVal -ArgumentList $cmdArgs -PassThru

        while (-not $process.HasExited) {
            [System.Windows.Forms.Application]::DoEvents()
            if ($global:FormClosing) { break }
            $lblStatus.Text = "Listening Mode: Waiting for Unreal (PID: $($process.Id)) to fully close..."
            Start-Sleep -Milliseconds 500
        }


        $lblStatus.Text = "Listening Mode: Finished remote job. Waiting for next..."
        $global:IsRendering = $false
    } else {
        $lblStatus.Text = "Listening: No pending jobs. Last check $(Get-Date -Format 'HH:mm:ss')"
    }
})

# ============================================================
# SHOW FORM
# ============================================================
[void]$form.ShowDialog()
