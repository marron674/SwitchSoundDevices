# Optional state file (keeps last-chosen index between runs)
$stateFile = ".\current_device.txt"

# Get playback devices (sorted by Index)
$playbacks = Get-AudioDevice -List | Where-Object { $_.Type -eq 'Playback' } | Sort-Object Index

if ($playbacks.Count -lt 1) {
    Write-Error "No playback devices found."
    exit 1
}

# Show available playback devices
$playbacks | Format-Table Index,Name,Default -AutoSize

# Detect current default playback device (object)
$current = $playbacks | Where-Object { $_.Default -eq $true }

if (-not $current) {
    Write-Host "No default playback device detected. Using first device in list." -ForegroundColor Yellow
    $currentIndexValue = $playbacks[0].Index
} else {
    $currentIndexValue = $current.Index
    Write-Host "Detected default device: $($current.Name) (Index $currentIndexValue)" -ForegroundColor Cyan
}

# Build array of Index values (preserves device ordering)
$indices = $playbacks | Select-Object -ExpandProperty Index

# Find position of current index in indices array
$pos = [array]::IndexOf($indices, $currentIndexValue)
if ($pos -lt 0) { $pos = 0 }

# Compute next position and corresponding Index value
$nextPos = ($pos + 1) % $indices.Count
$nextIndexValue = $indices[$nextPos]

# Show next device
$nextDevice = ($playbacks | Where-Object { $_.Index -eq $nextIndexValue }).Name
Write-Host "Switching default playback to: $nextDevice (Index $nextIndexValue)" -ForegroundColor Green

# Set default by Index (use -DefaultOnly if you want only default role)
Set-AudioDevice -Index $nextIndexValue

# Save state (optional)
$nextIndexValue | Out-File $stateFile -Encoding ascii

Write-Host "Done."
