# SwitchSoundDevices

A small PowerShell utility that cycles through configured Windows audio output devices using NirCmd.

## What it does

- Reads a device list from `devices.txt`
- Tracks the current output device in `current_device.txt`
- Switches the default playback device to the next entry in the list
- Uses NirCmd to set the default sound device for both roles

## Requirements

- Windows PowerShell
- [NirCmd](https://www.nirsoft.net/utils/nircmd.html)
- The device names must match the exact output device names used by Windows

## Files

- `switch-audio.ps1` - main script
- `devices.txt` - list of audio output device names, one per line
- `current_device.txt` - stores the current device index and is created automatically

## Setup

1. Install NirCmd and update the `$nircmd` path in `switch-audio.ps1` if needed.
2. Add your audio device names to `devices.txt`, for example:
   ```text
   Speakers
   Headphones
   HDMI Output
   ```
3. Run the script:
   ```powershell
   .\switch-audio.ps1
   ```

## Notes

- If `devices.txt` is missing or empty, the script exits with an error.
- `current_device.txt` is created automatically if it does not exist.
- The script advances to the next device in the list on every run and wraps around to the first device.

## Customization

- Change the `devices.txt` entries to match the exact names shown in Windows Sound settings.
- Adjust the `nircmd` executable path in `switch-audio.ps1` if you install NirCmd in a different location.
