# switch-audio-rotation.ps1
# Requires: AudioDeviceCmdlets module (Get-AudioDevice, Set-AudioDevice)

Import-Module AudioDeviceCmdlets -ErrorAction Stop

# Files (in script folder)
$scriptDir        = Split-Path -Parent $MyInvocation.MyCommand.Path
$deviceListFile   = Join-Path $scriptDir 'devices.txt'          # editable rotation list
$masterListFile   = Join-Path $scriptDir 'devices_master.txt'   # auto-generated full list
$stateFile        = Join-Path $scriptDir 'current_device.txt'   # detailed current device info
$indexStateFile   = Join-Path $scriptDir 'current_index.txt'    # saved rotation index (int)

# --- Helper: export full playback device list to master file (one exact name per line)
function Export-MasterDeviceList {
    $playbacks = Get-AudioDevice -List | Where-Object { $_.Type -eq 'Playback' } | Sort-Object Index
    $playbacks | ForEach-Object { $_.Name } | Out-File -FilePath $masterListFile -Encoding utf8
    return $playbacks
}

# --- Ensure master list exists (auto-generate if missing)
if (-not (Test-Path $masterListFile)) {
    Write-Host "Generating master device list: $masterListFile" -ForegroundColor Yellow
    $allPlaybacks = Export-MasterDeviceList
} else {
    # still load current playback objects for detection
    $allPlaybacks = Get-AudioDevice -List | Where-Object { $_.Type -eq 'Playback' } | Sort-Object Index
}

# --- If devices.txt missing, create it from master (user can edit to exclude devices)
if (-not (Test-Path $deviceListFile)) {
    Write-Host "Creating devices.txt from master list. Edit devices.txt to exclude devices you don't want in rotation." -ForegroundColor Yellow
    $allPlaybacks | ForEach-Object { $_.Name } | Out-File -FilePath $deviceListFile -Encoding utf8
}

# --- Load rotation list (exact names)
$devices = Get-Content $deviceListFile | Where-Object { $_.Trim() -ne "" }

if ($devices.Count -eq 0) {
    Write-Error "devices.txt is empty. Populate it with exact playback device names (one per line)."
    exit 1
}

# --- Detect current default playback device (object)
$playbacks = $allPlaybacks
$currentObj = $playbacks | Where-Object { $_.Default -eq $true }

# Write detailed current_device.txt for auditing
$timestamp = (Get-Date).ToString("o")
if ($currentObj) {
    $currentInfo = @{
        Timestamp = $timestamp
        Name      = $currentObj.Name
        Index     = $currentObj.Index
        ID        = $currentObj.ID
        Type      = $currentObj.Type
        Default   = $currentObj.Default
    }
} else {
    $currentInfo = @{
        Timestamp = $timestamp
        Name      = "<none detected>"
        Index     = -1
        ID        = ""
        Type      = "Playback"
        Default   = $false
    }
}
# Save human-readable and machine-friendly info
$currentInfo.GetEnumerator() | ForEach-Object { "{0}: {1}" -f $_.Key, $_.Value } | Out-File -FilePath $stateFile -Encoding utf8

Write-Host "Wrote current device info to $stateFile" -ForegroundColor Cyan
Write-Host "Detected current device: $($currentInfo.Name)" -ForegroundColor Yellow

# --- Load saved rotation index (if present)
if (Test-Path $indexStateFile) {
    try {
        $savedIndex = [int](Get-Content $indexStateFile -ErrorAction Stop)
    } catch {
        $savedIndex = 0
    }
} else {
    $savedIndex = 0
}

if ($savedIndex -lt 0 -or $savedIndex -ge $devices.Count) { $savedIndex = 0 }

# --- If system default changed outside script, correct savedIndex if possible
if ($currentInfo.Name -ne "<none detected>") {
    $foundInRotation = $devices.IndexOf($currentInfo.Name)
    if ($foundInRotation -ge 0) {
        # align savedIndex to the detected device
        $savedIndex = $foundInRotation
        Write-Host "Detected device is in rotation list; corrected saved index to $savedIndex" -ForegroundColor Green
    } else {
        # Detected device not in rotation list: record it (already in current_device.txt) and leave savedIndex unchanged.
        Write-Host "Detected device is NOT in rotation list; leaving rotation index unchanged." -ForegroundColor Yellow
    }
} else {
    Write-Host "No default playback device detected; using saved index." -ForegroundColor Yellow
}

# --- Compute next index and device from rotation list
$nextIndex = ($savedIndex + 1) % $devices.Count
$nextDevice = $devices[$nextIndex]

Write-Host "Switching default playback to: $nextDevice (rotation index $nextIndex)" -ForegroundColor Cyan

# --- Attempt to set default by matching Index or Name
# Prefer Set-AudioDevice -Index if the device exists in current playbacks; otherwise use -ID or -InputObject
$targetPlayback = $playbacks | Where-Object { $_.Name -eq $nextDevice } | Select-Object -First 1

if ($null -ne $targetPlayback) {
    # Use Index (module supports -Index)
    try {
        Set-AudioDevice -Index $targetPlayback.Index -ErrorAction Stop
        Write-Host "Set default by Index: $($targetPlayback.Index)" -ForegroundColor Green
    } catch {
        # fallback to ID
        try {
            Set-AudioDevice -ID $targetPlayback.ID -ErrorAction Stop
            Write-Host "Set default by ID: $($targetPlayback.ID)" -ForegroundColor Green
        } catch {
            Write-Error "Failed to set default device by Index or ID: $($_.Exception.Message)"
            exit 1
        }
    }
} else {
    # Device name from devices.txt not found among current playbacks (maybe unplugged or renamed)
    Write-Host "Target device '$nextDevice' not present in current playback list. Skipping switch." -ForegroundColor Red
    # Optionally: you could choose the first available playback device instead:
    # $fallback = $playbacks[0]; Set-AudioDevice -Index $fallback.Index
}

# --- Save new rotation index
$nextIndex | Out-File -FilePath $indexStateFile -Encoding ascii

Write-Host "Saved rotation index to $indexStateFile" -ForegroundColor Cyan
Write-Host "Done."
