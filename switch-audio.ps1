# switch-audio-rotation-robust.ps1
# Requires AudioDeviceCmdlets module (Get-AudioDevice, Set-AudioDevice); commented out since it is already installed

# Import-Module AudioDeviceCmdlets -ErrorAction Stop

param(
    [Alias("s")]
    [int]$SleepSeconds = 0
)

$scriptDir      = Split-Path -Parent $MyInvocation.MyCommand.Path
$masterFile     = Join-Path $scriptDir 'devices_master.txt'
$editableFile   = Join-Path $scriptDir 'devices.txt'
$currentFile    = Join-Path $scriptDir 'current_device.txt'
$indexStateFile = Join-Path $scriptDir 'current_index.txt'
$debugMode      = $false

function Write-DebugMessage {
    param([string]$Message)

    if ($debugMode) {
        Write-Host "DEBUG: $Message" -ForegroundColor DarkGray
    }
}

# --- Gather current playback devices
$playbacks = Get-AudioDevice -List | Where-Object { $_.Type -eq 'Playback' } | Sort-Object Index

if ($playbacks.Count -eq 0) {
    Write-Error "No playback devices found."
    exit 1
}

# --- Export master list (Index | Name | ID | Type | Default)
$playbacks | ForEach-Object {
    "{0} | {1} | {2} | {3} | {4}" -f $_.Index, $_.Name, $_.ID, $_.Type, $_.Default
} | Out-File -FilePath $masterFile -Encoding utf8

Write-DebugMessage "Wrote master device list to $masterFile"

# --- Create editable devices.txt from master if missing
if (-not (Test-Path $editableFile)) {
    $playbacks | ForEach-Object { $_.Name } | Out-File -FilePath $editableFile -Encoding utf8
    Write-Host "Created $editableFile (edit to exclude devices you don't want in rotation)" -ForegroundColor Yellow
}

# --- Read editable list and normalize entries
$rawEntries = Get-Content $editableFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

# Helper: resolve an entry to a playback object (prefer ID, then exact Name, then Index)
function Resolve-EntryToPlayback($entry, $playbacks) {
    # ID: <guid>
    if ($entry -match '^\s*ID\s*:\s*(\{?.+\}?)\s*$') {
        $id = $matches[1].Trim()
        return $playbacks | Where-Object { $_.ID -eq $id } | Select-Object -First 1
    }
    # Index: <number>
    if ($entry -match '^\s*Index\s*[:=]\s*(\d+)\s*$') {
        $idx = [int]$matches[1]
        return $playbacks | Where-Object { $_.Index -eq $idx } | Select-Object -First 1
    }
    # If entry contains " | " (master format), try to parse Name from it (second field)
    if ($entry -match '^\s*\d+\s*\|\s*(.+?)\s*\|') {
        $name = $matches[1].Trim()
        $found = $playbacks | Where-Object { $_.Name -eq $name } | Select-Object -First 1
        if ($found) { return $found }
    }
    # Otherwise treat as exact Name
    return $playbacks | Where-Object { $_.Name -eq $entry } | Select-Object -First 1
}

# --- Build rotation list of playback objects (resolved)
$rotation = @()
foreach ($entry in $rawEntries) {
    $resolved = Resolve-EntryToPlayback -entry $entry -playbacks $playbacks
    if ($null -ne $resolved) {
        $rotation += $resolved
    } else {
        Write-Host "Warning: entry not found or not present now: '$entry' (skipping)" -ForegroundColor Yellow
    }
}

if ($rotation.Count -eq 0) {
    Write-Error "No valid devices found in devices.txt after resolving against current system devices."
    exit 1
}

# --- Write detailed current_device.txt (human readable)
$currentObj = $playbacks | Where-Object { $_.Default -eq $true } | Select-Object -First 1
$timestamp = (Get-Date).ToString("o")
if ($currentObj) {
    $lines = @(
        "Timestamp: $timestamp"
        "Name: $($currentObj.Name)"
        "Index: $($currentObj.Index)"
        "ID: $($currentObj.ID)"
        "Type: $($currentObj.Type)"
        "Default: $($currentObj.Default)"
    )
} else {
    $lines = @(
        "Timestamp: $timestamp"
        "Name: <none detected>"
        "Index: -1"
        "ID: "
        "Type: Playback"
        "Default: False"
    )
}
$lines | Out-File -FilePath $currentFile -Encoding utf8
Write-DebugMessage "Wrote current device info to $currentFile"

# --- Load saved rotation index (index into $rotation array)
if (Test-Path $indexStateFile) {
    try { $savedIndex = [int](Get-Content $indexStateFile) } catch { $savedIndex = 0 }
} else { $savedIndex = 0 }
if ($savedIndex -lt 0 -or $savedIndex -ge $rotation.Count) { $savedIndex = 0 }

# --- If system default changed outside script and is in rotation, align savedIndex
if ($currentObj) {
    $foundPos = [array]::IndexOf($rotation, ($rotation | Where-Object { $_.ID -eq $currentObj.ID } | Select-Object -First 1))
    if ($foundPos -ge 0) {
        $savedIndex = $foundPos
        Write-DebugMessage "Detected system default is in rotation; aligning saved index to $savedIndex"
    } else {
        Write-DebugMessage "Detected system default not in rotation; continuing with saved index $savedIndex"
    }
}

# --- Compute next device in rotation
$nextIndex = ($savedIndex + 1) % $rotation.Count
$target = $rotation[$nextIndex]
Write-Host "`nSwitching to: $($target.Name) (Index $($target.Index))`n" -ForegroundColor Cyan

# --- Attempt to set default (prefer Index, fallback to ID)
try {
    Set-AudioDevice -Index $target.Index -ErrorAction Stop | Out-Null
    Write-DebugMessage "Set default by Index: $($target.Index)"
} catch {
    try {
        Set-AudioDevice -ID $target.ID -ErrorAction Stop
        Write-DebugMessage "Set default by ID: $($target.ID)"
    } catch {
        Write-Error "Failed to set default device: $($_.Exception.Message)"
        exit 1
    }
}

# --- Save new rotation index
$nextIndex | Out-File -FilePath $indexStateFile -Encoding ascii
Write-DebugMessage "Saved rotation index ($nextIndex) to $indexStateFile"
Write-DebugMessage "Done."

# --- Pause 3 seconds before closing window
if ($SleepSeconds -gt 0) {
    Start-Sleep -Seconds $SleepSeconds
}