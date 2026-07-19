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

# Load current index
if (Test-Path $stateFile) {
    $currentIndex = [int](Get-Content $stateFile)
} else {
    $currentIndex = 0
}

# Compute next index
$nextIndex = ($currentIndex + 1) % $devices.Count
$nextDevice = $devices[$nextIndex]

Write-Host "Switching audio output to: $nextDevice" -ForegroundColor Cyan

# Run nircmd to set default device
& $nircmd setdefaultsounddevice "$nextDevice" 1
& $nircmd setdefaultsounddevice "$nextDevice" 2

# Save new index
$nextIndex | Out-File $stateFile -Encoding ascii

Write-Host "Done."
