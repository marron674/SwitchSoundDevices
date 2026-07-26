# Path to nircmd
$nircmd = "C:\nircmd64\nircmd.exe"

# Config files
$deviceListFile = ".\devices.txt"
$stateFile = ".\current_device.txt"

# Load device list
if (-not (Test-Path $deviceListFile)) {
    Write-Error "Device list file not found: $deviceListFile"
    exit
}

$devices = Get-Content $deviceListFile | Where-Object { $_.Trim() -ne "" }

if ($devices.Count -eq 0) {
    Write-Error "Device list is empty."
    exit
}

# Detect current default audio output device using nircmd
$currentDevice = (& $nircmd showsounddevices) |
    Select-String "Default" -Context 0,1 |
    ForEach-Object {
        $_.Context.PostContext |
        Select-String "Name" |
        ForEach-Object { $_.ToString().Split(":")[1].Trim() }
    }

if (-not $currentDevice) {
    Write-Error "Unable to detect current audio device."
    exit
}

Write-Host "Detected current device: $currentDevice" -ForegroundColor Yellow

# Load saved index
if (Test-Path $stateFile) {
    $savedIndex = [int](Get-Content $stateFile)
} else {
    $savedIndex = 0
}

# Validate saved index
if ($savedIndex -ge $devices.Count -or $savedIndex -lt 0) {
    Write-Host "Saved index is invalid. Resetting to 0." -ForegroundColor Red
    $savedIndex = 0
}

$savedDevice = $devices[$savedIndex]

Write-Host "Saved device from current_device.txt: $savedDevice" -ForegroundColor Yellow

# Compare detected device with saved device
if ($currentDevice -ne $savedDevice) {
    Write-Host "Mismatch detected — correcting index..." -ForegroundColor Red

    # Find actual index
    $actualIndex = $devices.IndexOf($currentDevice)

    if ($actualIndex -ge 0) {
        $savedIndex = $actualIndex
        Write-Host "Corrected index to $savedIndex ($currentDevice)" -ForegroundColor Green
    } else {
        Write-Host "Current device not found in devices.txt. Cannot correct index." -ForegroundColor Red
    }
}

# Compute next index
$nextIndex = ($savedIndex + 1) % $devices.Count
$nextDevice = $devices[$nextIndex]

Write-Host "Switching audio output to: $nextDevice" -ForegroundColor Cyan

# Run nircmd to set default device
& $nircmd setdefaultsounddevice "$nextDevice" 1
& $nircmd setdefaultsounddevice "$nextDevice" 2

# Save new index
$nextIndex | Out-File $stateFile -Encoding ascii

Write-Host "Done."
