# ============================================================
# NK Movie Render Launcher - PowerShell GUI
# ============================================================
# This script creates a modern dark-themed Windows Forms GUI 
# for launching Unreal Engine Movie Render Queue renders.
# It reads RenderConfig.bat for engine/project paths and 
# calls MRQ_Python_Executor.py via UnrealEditor-Cmd.exe.
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

# Default paths (will be overridden by RenderConfig.bat if it exists)
$EnginePath = "C:\Program Files\Epic Games\UE_5.7\Engine\Binaries\Win64\UnrealEditor-Cmd.exe"
$ProjectPath = "D:\Cloud Repositories-NK26\NK2026\NK2026.uproject"

# Read existing config
if (Test-Path $ConfigFile) {
    $configContent = Get-Content $ConfigFile
    foreach ($line in $configContent) {
        if ($line -match 'set ENGINE=(.+)') { $EnginePath = $Matches[1].Trim('"') }
        if ($line -match 'set PROJECT=(.+)') { $ProjectPath = $Matches[1].Trim('"') }
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

$Passes = @("Song", "Env", "House", "House_Back", "LightPass")

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
# MAIN FORM
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "NK Movie Render Launcher"
$form.Size = New-Object System.Drawing.Size(620, 780)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $cBack
$form.ForeColor = $cText
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.Font = $fontBody

# Dark title bar
$form.Add_Shown({
    $mode = 1
    [DwmHelper]::DwmSetWindowAttribute($form.Handle, 20, [ref]$mode, 4) | Out-Null
    $form.Refresh()
})

$y = 15

# ============================================================
# TITLE
# ============================================================
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "NK Movie Render Launcher"
$lblTitle.Font = $fontTitle
$lblTitle.ForeColor = $cText
$lblTitle.Location = New-Object System.Drawing.Point(20, $y)
$lblTitle.Size = New-Object System.Drawing.Size(560, 30)
$form.Controls.Add($lblTitle)

$y += 35

# ============================================================
# PATH CONFIGURATION (always visible, at the top)
# ============================================================
$lblConfig = New-Object System.Windows.Forms.Label
$lblConfig.Text = "PATH CONFIGURATION"
$lblConfig.Font = $fontSection
$lblConfig.ForeColor = $cSection
$lblConfig.Location = New-Object System.Drawing.Point(20, $y)
$lblConfig.Size = New-Object System.Drawing.Size(300, 20)
$form.Controls.Add($lblConfig)
$y += 24

$configPanel = New-Object System.Windows.Forms.Panel
$configPanel.Location = New-Object System.Drawing.Point(20, $y)
$configPanel.Size = New-Object System.Drawing.Size(560, 122)
$configPanel.BackColor = $cSurface
$form.Controls.Add($configPanel)

$lblEngine = New-Object System.Windows.Forms.Label
$lblEngine.Text = "Engine:"
$lblEngine.Font = $fontSmall
$lblEngine.ForeColor = $cTextDim
$lblEngine.Location = New-Object System.Drawing.Point(10, 10)
$lblEngine.Size = New-Object System.Drawing.Size(55, 18)
$configPanel.Controls.Add($lblEngine)

$txtEngine = New-Object System.Windows.Forms.TextBox
$txtEngine.Font = $fontSmall
$txtEngine.BackColor = $cPanel
$txtEngine.ForeColor = $cText
$txtEngine.BorderStyle = 'FixedSingle'
$txtEngine.Location = New-Object System.Drawing.Point(70, 8)
$txtEngine.Size = New-Object System.Drawing.Size(480, 22)
$txtEngine.Text = $EnginePath
$configPanel.Controls.Add($txtEngine)

$lblProject = New-Object System.Windows.Forms.Label
$lblProject.Text = "Project:"
$lblProject.Font = $fontSmall
$lblProject.ForeColor = $cTextDim
$lblProject.Location = New-Object System.Drawing.Point(10, 42)
$lblProject.Size = New-Object System.Drawing.Size(55, 18)
$configPanel.Controls.Add($lblProject)

$txtProject = New-Object System.Windows.Forms.TextBox
$txtProject.Font = $fontSmall
$txtProject.BackColor = $cPanel
$txtProject.ForeColor = $cText
$txtProject.BorderStyle = 'FixedSingle'
$txtProject.Location = New-Object System.Drawing.Point(70, 40)
$txtProject.Size = New-Object System.Drawing.Size(480, 22)
$txtProject.Text = $ProjectPath
$configPanel.Controls.Add($txtProject)

# Sync Checkbox
$cbSync = New-Object System.Windows.Forms.CheckBox
$cbSync.Text = "Update to latest Plastic SCM workspace before rendering"
$cbSync.Font = $fontSmall
$cbSync.ForeColor = $cText
$cbSync.BackColor = $cSurface
$cbSync.Location = New-Object System.Drawing.Point(10, 72)
$cbSync.AutoSize = $true
$cbSync.Checked = $true
$configPanel.Controls.Add($cbSync)

# Revert Checkbox
$cbRevert = New-Object System.Windows.Forms.CheckBox
$cbRevert.Text = "Revert uncommitted local changes before update (Warning: Destructive)"
$cbRevert.Font = $fontSmall
$cbRevert.ForeColor = $cTextDim
$cbRevert.BackColor = $cSurface
$cbRevert.Location = New-Object System.Drawing.Point(10, 96)
$cbRevert.AutoSize = $true
$cbRevert.Checked = $false
$configPanel.Controls.Add($cbRevert)

$y += 132

# ============================================================
# SEQUENCES SECTION
# ============================================================
$lblSeq = New-Object System.Windows.Forms.Label
$lblSeq.Text = "SEQUENCES"
$lblSeq.Font = $fontSection
$lblSeq.ForeColor = $cSection
$lblSeq.Location = New-Object System.Drawing.Point(20, $y)
$lblSeq.Size = New-Object System.Drawing.Size(200, 20)
$form.Controls.Add($lblSeq)

# Select All / Deselect All for Sequences
$btnSeqAll = New-Object System.Windows.Forms.Button
$btnSeqAll.Text = "All"
$btnSeqAll.Font = $fontSmall
$btnSeqAll.FlatStyle = 'Flat'
$btnSeqAll.FlatAppearance.BorderSize = 1
$btnSeqAll.FlatAppearance.BorderColor = $cBorder
$btnSeqAll.BackColor = $cBtnBg
$btnSeqAll.ForeColor = $cTextDim
$btnSeqAll.Size = New-Object System.Drawing.Size(50, 22)
$btnSeqAll.Location = New-Object System.Drawing.Point(485, $y)
$form.Controls.Add($btnSeqAll)

$btnSeqNone = New-Object System.Windows.Forms.Button
$btnSeqNone.Text = "None"
$btnSeqNone.Font = $fontSmall
$btnSeqNone.FlatStyle = 'Flat'
$btnSeqNone.FlatAppearance.BorderSize = 1
$btnSeqNone.FlatAppearance.BorderColor = $cBorder
$btnSeqNone.BackColor = $cBtnBg
$btnSeqNone.ForeColor = $cTextDim
$btnSeqNone.Size = New-Object System.Drawing.Size(50, 22)
$btnSeqNone.Location = New-Object System.Drawing.Point(540, $y)
$form.Controls.Add($btnSeqNone)

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

$btnSeqAll.Add_Click({ foreach ($cb in $seqCheckboxes) { $cb.Checked = $true } })
$btnSeqNone.Add_Click({ foreach ($cb in $seqCheckboxes) { $cb.Checked = $false } })

$y += 152

# ============================================================
# PASSES SECTION
# ============================================================
$lblPass = New-Object System.Windows.Forms.Label
$lblPass.Text = "PASSES"
$lblPass.Font = $fontSection
$lblPass.ForeColor = $cSection
$lblPass.Location = New-Object System.Drawing.Point(20, $y)
$lblPass.Size = New-Object System.Drawing.Size(200, 20)
$form.Controls.Add($lblPass)

$btnPassAll = New-Object System.Windows.Forms.Button
$btnPassAll.Text = "All"
$btnPassAll.Font = $fontSmall
$btnPassAll.FlatStyle = 'Flat'
$btnPassAll.FlatAppearance.BorderSize = 1
$btnPassAll.FlatAppearance.BorderColor = $cBorder
$btnPassAll.BackColor = $cBtnBg
$btnPassAll.ForeColor = $cTextDim
$btnPassAll.Size = New-Object System.Drawing.Size(50, 22)
$btnPassAll.Location = New-Object System.Drawing.Point(485, $y)
$form.Controls.Add($btnPassAll)

$btnPassNone = New-Object System.Windows.Forms.Button
$btnPassNone.Text = "None"
$btnPassNone.Font = $fontSmall
$btnPassNone.FlatStyle = 'Flat'
$btnPassNone.FlatAppearance.BorderSize = 1
$btnPassNone.FlatAppearance.BorderColor = $cBorder
$btnPassNone.BackColor = $cBtnBg
$btnPassNone.ForeColor = $cTextDim
$btnPassNone.Size = New-Object System.Drawing.Size(50, 22)
$btnPassNone.Location = New-Object System.Drawing.Point(540, $y)
$form.Controls.Add($btnPassNone)

$y += 24

$passPanel = New-Object System.Windows.Forms.Panel
$passPanel.Location = New-Object System.Drawing.Point(20, $y)
$passPanel.Size = New-Object System.Drawing.Size(560, 38)
$passPanel.BackColor = $cSurface
$form.Controls.Add($passPanel)

$passCheckboxes = @()
$px = 12
foreach ($pass in $Passes) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = "  $pass"
    $cb.Font = $fontBody
    $cb.ForeColor = $cText
    $cb.BackColor = $cSurface
    $cb.Location = New-Object System.Drawing.Point($px, 9)
    $cb.AutoSize = $true
    $cb.Checked = $false
    $cb.Tag = $pass
    $passPanel.Controls.Add($cb)
    $passCheckboxes += $cb
    $px += 108
}

$btnPassAll.Add_Click({ foreach ($cb in $passCheckboxes) { $cb.Checked = $true } })
$btnPassNone.Add_Click({ foreach ($cb in $passCheckboxes) { $cb.Checked = $false } })

$y += 48

# ============================================================
# RENDER SETTINGS SECTION
# ============================================================
$lblSettings = New-Object System.Windows.Forms.Label
$lblSettings.Text = "RENDER SETTINGS"
$lblSettings.Font = $fontSection
$lblSettings.ForeColor = $cSection
$lblSettings.Location = New-Object System.Drawing.Point(20, $y)
$lblSettings.Size = New-Object System.Drawing.Size(300, 20)
$form.Controls.Add($lblSettings)

$y += 24

$settingsPanel = New-Object System.Windows.Forms.Panel
$settingsPanel.Location = New-Object System.Drawing.Point(20, $y)
$settingsPanel.Size = New-Object System.Drawing.Size(560, 165)
$settingsPanel.BackColor = $cSurface
$form.Controls.Add($settingsPanel)

# Resolution
$lblRes = New-Object System.Windows.Forms.Label
$lblRes.Text = "Resolution:"
$lblRes.Font = $fontBody
$lblRes.ForeColor = $cTextDim
$lblRes.Location = New-Object System.Drawing.Point(15, 15)
$lblRes.Size = New-Object System.Drawing.Size(130, 20)
$settingsPanel.Controls.Add($lblRes)

$cmbRes = New-Object System.Windows.Forms.ComboBox
$cmbRes.Font = $fontBody
$cmbRes.BackColor = $cPanel
$cmbRes.ForeColor = $cText
$cmbRes.FlatStyle = 'Flat'
$cmbRes.DropDownStyle = 'DropDownList'
$cmbRes.Location = New-Object System.Drawing.Point(150, 12)
$cmbRes.Size = New-Object System.Drawing.Size(390, 24)
$cmbRes.Items.AddRange(@(
    "Half Res  (4968 x 1296)  -  Default",
    "Full Res  (9936 x 2592)",
    "Quarter Res  (2484 x 648)"
))
$cmbRes.SelectedIndex = 0
$settingsPanel.Controls.Add($cmbRes)

# Spatial Sample Count
$lblSpatial = New-Object System.Windows.Forms.Label
$lblSpatial.Text = "Spatial Samples:"
$lblSpatial.Font = $fontBody
$lblSpatial.ForeColor = $cTextDim
$lblSpatial.Location = New-Object System.Drawing.Point(15, 50)
$lblSpatial.Size = New-Object System.Drawing.Size(130, 20)
$settingsPanel.Controls.Add($lblSpatial)

$txtSpatial = New-Object System.Windows.Forms.TextBox
$txtSpatial.Font = $fontBody
$txtSpatial.BackColor = $cPanel
$txtSpatial.ForeColor = $cText
$txtSpatial.BorderStyle = 'FixedSingle'
$txtSpatial.Location = New-Object System.Drawing.Point(150, 48)
$txtSpatial.Size = New-Object System.Drawing.Size(80, 22)
$txtSpatial.Text = "1"
$settingsPanel.Controls.Add($txtSpatial)

$lblSpatialHint = New-Object System.Windows.Forms.Label
$lblSpatialHint.Text = "Default: 1"
$lblSpatialHint.Font = $fontSmall
$lblSpatialHint.ForeColor = $cTextDim
$lblSpatialHint.Location = New-Object System.Drawing.Point(240, 50)
$lblSpatialHint.Size = New-Object System.Drawing.Size(200, 18)
$settingsPanel.Controls.Add($lblSpatialHint)

# Temporal Sample Count
$lblTemporal = New-Object System.Windows.Forms.Label
$lblTemporal.Text = "Temporal Samples:"
$lblTemporal.Font = $fontBody
$lblTemporal.ForeColor = $cTextDim
$lblTemporal.Location = New-Object System.Drawing.Point(15, 85)
$lblTemporal.Size = New-Object System.Drawing.Size(130, 20)
$settingsPanel.Controls.Add($lblTemporal)

$txtTemporal = New-Object System.Windows.Forms.TextBox
$txtTemporal.Font = $fontBody
$txtTemporal.BackColor = $cPanel
$txtTemporal.ForeColor = $cText
$txtTemporal.BorderStyle = 'FixedSingle'
$txtTemporal.Location = New-Object System.Drawing.Point(150, 83)
$txtTemporal.Size = New-Object System.Drawing.Size(80, 22)
$txtTemporal.Text = "1"
$settingsPanel.Controls.Add($txtTemporal)

$lblTemporalHint = New-Object System.Windows.Forms.Label
$lblTemporalHint.Text = "Default: 1"
$lblTemporalHint.Font = $fontSmall
$lblTemporalHint.ForeColor = $cTextDim
$lblTemporalHint.Location = New-Object System.Drawing.Point(240, 85)
$lblTemporalHint.Size = New-Object System.Drawing.Size(200, 18)
$settingsPanel.Controls.Add($lblTemporalHint)

# Warm-Up Frames
$lblWarmup = New-Object System.Windows.Forms.Label
$lblWarmup.Text = "Warm-Up Frames:"
$lblWarmup.Font = $fontBody
$lblWarmup.ForeColor = $cTextDim
$lblWarmup.Location = New-Object System.Drawing.Point(15, 120)
$lblWarmup.Size = New-Object System.Drawing.Size(130, 20)
$settingsPanel.Controls.Add($lblWarmup)

$txtWarmup = New-Object System.Windows.Forms.TextBox
$txtWarmup.Font = $fontBody
$txtWarmup.BackColor = $cPanel
$txtWarmup.ForeColor = $cText
$txtWarmup.BorderStyle = 'FixedSingle'
$txtWarmup.Location = New-Object System.Drawing.Point(150, 118)
$txtWarmup.Size = New-Object System.Drawing.Size(80, 22)
$txtWarmup.Text = "32"
$settingsPanel.Controls.Add($txtWarmup)

$lblWarmupHint = New-Object System.Windows.Forms.Label
$lblWarmupHint.Text = "Default: 32"
$lblWarmupHint.Font = $fontSmall
$lblWarmupHint.ForeColor = $cTextDim
$lblWarmupHint.Location = New-Object System.Drawing.Point(240, 120)
$lblWarmupHint.Size = New-Object System.Drawing.Size(200, 18)
$settingsPanel.Controls.Add($lblWarmupHint)

$y += 175

# ============================================================
# BOTTOM BUTTONS
# ============================================================
$y += 10

# Status label
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = ""
$lblStatus.Font = $fontSmall
$lblStatus.ForeColor = $cTextDim
$lblStatus.Location = New-Object System.Drawing.Point(20, $y)
$lblStatus.Size = New-Object System.Drawing.Size(560, 18)
$lblStatus.TextAlign = 'MiddleCenter'
$form.Controls.Add($lblStatus)

$y += 22

# Open Render Output Folder button
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

$btnOpenFolder.Add_Click({
    # Derive the project root from the .uproject path
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

# LAUNCH RENDER button
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
# LAUNCH LOGIC
# ============================================================
$btnLaunch.Add_Click({
    # Validate selection
    $selectedSeqs = $seqCheckboxes | Where-Object { $_.Checked }
    $selectedPasses = $passCheckboxes | Where-Object { $_.Checked }
    
    if ($selectedSeqs.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one sequence.", "No Sequences Selected", 'OK', 'Warning')
        return
    }
    if ($selectedPasses.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one pass.", "No Passes Selected", 'OK', 'Warning')
        return
    }

    # Save config
    $engineVal = $txtEngine.Text
    $projectVal = $txtProject.Text
    "set ENGINE=`"$engineVal`"" | Out-File -FilePath $ConfigFile -Encoding ascii
    "set PROJECT=`"$projectVal`"" | Out-File -FilePath $ConfigFile -Encoding ascii -Append

    # Resolution mapping
    switch ($cmbRes.SelectedIndex) {
        0 { $resX = "4968"; $resY = "1296" }
        1 { $resX = "9936"; $resY = "2592" }
        2 { $resX = "2484"; $resY = "648" }
    }

    # Build base args (editor mode, PIEExecutor requires this)
    $baseArgs = "-log -notexturestreaming -unattended -nosound"
    
    # Build override args
    $overrideArgs = "-RenderResX=$resX -RenderResY=$resY"
    if ($txtSpatial.Text.Trim() -ne "") { $overrideArgs += " -Spatial=$($txtSpatial.Text.Trim())" }
    if ($txtTemporal.Text.Trim() -ne "") { $overrideArgs += " -Temporal=$($txtTemporal.Text.Trim())" }
    if ($txtWarmup.Text.Trim() -ne "") { $overrideArgs += " -WarmUp=$($txtWarmup.Text.Trim())" }

    # Build pass filter (only if not ALL passes are selected)
    $allPassesSelected = ($selectedPasses.Count -eq $passCheckboxes.Count)

    # Count total render tasks
    $totalTasks = 0
    foreach ($seqCb in $selectedSeqs) {
        if ($allPassesSelected) { $totalTasks++ }
        else { $totalTasks += $selectedPasses.Count }
    }

    # Log what we're about to do
    $seqList = ($selectedSeqs | ForEach-Object { $_.Tag.Code }) -join ", "
    $passList = if ($allPassesSelected) { "ALL" } else { ($selectedPasses | ForEach-Object { $_.Tag }) -join ", " }
    # Sync Plastic SCM
    if ($cbSync.Checked) {
        $lblStatus.Text = "Syncing latest changes from Plastic SCM..."
        $form.Refresh()
        
        $projDir = Split-Path -Parent $projectVal
        Push-Location -Path $projDir
        try {
            if ($cbRevert.Checked) {
                $lblStatus.Text = "Reverting local changes in Plastic SCM..."
                $form.Refresh()
                & "cm" undo . -R
            }
            $lblStatus.Text = "Syncing latest changes from Plastic SCM..."
            $form.Refresh()
            & "cm" update
        } catch {
            Write-Host "Plastic SCM sync failed or 'cm' not found. Continuing..."
        }
        Pop-Location
    }

    $lblStatus.Text = "Starting $totalTasks task(s): Seq[$seqList] Pass[$passList] @ ${resX}x${resY}"
    $form.Refresh()

    # Minimize the form
    $form.WindowState = 'Minimized'

    $taskNum = 0
    foreach ($seqCb in $selectedSeqs) {
        $seq = $seqCb.Tag
        $queue = $seq.Queue

        if ($allPassesSelected) {
            # Render all passes at once (no filter)
            $taskNum++
            $lblStatus.Text = "Rendering $taskNum / $totalTasks : $($seq.Name) - ALL passes..."
            $form.Refresh()

            $cmdArgs = "`"$projectVal`" $baseArgs -ExecutePythonScript=`"$PythonScript`" -Queue=`"$queue`" $overrideArgs"
            $process = Start-Process -FilePath $engineVal -ArgumentList $cmdArgs -Wait -PassThru
        }
        else {
            # Render each selected pass individually
            foreach ($passCb in $selectedPasses) {
                $passName = $passCb.Tag
                $taskNum++
                $lblStatus.Text = "Rendering $taskNum / $totalTasks : $($seq.Name) - $passName..."
                $form.Refresh()

                $passArg = "-PassFilter=$passName"
                $cmdArgs = "`"$projectVal`" $baseArgs -ExecutePythonScript=`"$PythonScript`" -Queue=`"$queue`" $overrideArgs $passArg"
                $process = Start-Process -FilePath $engineVal -ArgumentList $cmdArgs -Wait -PassThru
            }
        }
    }

    # Done
    $form.WindowState = 'Normal'
    $lblStatus.Text = "Completed $totalTasks render task(s)."
})

# ============================================================
# SHOW FORM
# ============================================================
[void]$form.ShowDialog()
