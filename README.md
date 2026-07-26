# Switch Audio Rotation

A robust PowerShell script that seamlessly cycles through your preferred Windows audio playback devices. Perfect for quickly switching between headphones, speakers, and virtual audio cables using a desktop shortcut or a macro key.

## Features

* **Customizable Rotation:** Automatically generates a master list of all your audio devices and lets you choose exactly which ones to include in the rotation.
* **Smart Synchronization:** If you manually change your audio device through Windows, the script detects the change and aligns its rotation index accordingly.
* **Robust Device Matching:** Safely identifies devices by Name, Index, or GUID to prevent errors when Windows updates or devices are plugged in/out.
* **State Tracking:** Keeps a detailed log of your currently active device.

## Prerequisites

This script requires the **AudioDeviceCmdlets** PowerShell module to interact with Windows audio devices. 

To install the module, open PowerShell as Administrator and run:
```powershell
Install-Module -Name AudioDeviceCmdlets -Force
```

## Setup & First Run

1. Place `switch-audio.ps1` in a dedicated folder.
2. Run the script for the first time:
   ```powershell
   .\switch-audio.ps1
   ```
3. On the first run, the script will generate several text files in the same directory. 
4. Open **`devices.txt`** and delete any audio devices you *do not* want to be part of the rotation (e.g., monitor speakers or inactive virtual cables).

## How It Works

The script uses a directory-based configuration system. It creates and manages the following files in the same folder as the script:

| File | Purpose |
| :--- | :--- |
| `devices_master.txt` | A complete, auto-generated list of every playback device detected on your system. Useful for finding a device's exact ID or Index. |
| `devices.txt` | **The editable rotation list.** The script cycles through the devices listed in this file. You can leave the exact names, or specify by `ID: <guid>` or `Index: <number>`. |
| `current_device.txt` | A human-readable log of the currently active default playback device, complete with a timestamp. |
| `current_index.txt` | A lightweight state file that remembers where you are in the rotation sequence. |

## Configuration (`devices.txt`)

By default, `devices.txt` is populated with the names of your devices. The script is smart enough to read the devices in a few different formats. You can edit the file to use any of the following:

* **Exact Name:** `Speakers (High Definition Audio Device)`
* **By Index:** `Index: 1`
* **By ID:** `ID: {0.0.0.00000000}.{12345678-abcd-1234-abcd-123456789abc}`
* **Master Format:** `1 | Speakers | {ID} | Playback | True` (You can copy/paste lines directly from `devices_master.txt`).

## Troubleshooting

* **Script won't run due to execution policies:** You may need to bypass the execution policy to run local scripts. Run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` in PowerShell, or run the script using `powershell.exe -ExecutionPolicy Bypass -File .\switch-audio.ps1`.
* **Skipped Devices:** If a device in `devices.txt` is unplugged or unavailable, the script will log a warning and seamlessly skip to the next available device in the rotation.