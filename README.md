# USB Device Manager for WSL

This folder contains PowerShell scripts for managing USB devices between Windows and WSL (Windows Subsystem for Linux).

## Scripts Overview

### 🚀 Main Scripts

1. **`direct-usb-manager.ps1`** - **RECOMMENDED**
   - Shows USB device status without requiring admin privileges
   - Provides menu options for different operations
   - Best starting point for most users

2. **`run-cp2102-admin.ps1`** 
   - Auto-elevates to administrator privileges
   - Launches the interactive USB manager
   - Good for creating shortcuts

3. **`simple-usb-manager.ps1`**
   - Full-featured interactive USB manager
   - Number-based device selection (no arrow key issues)
   - Requires administrator privileges

## Quick Start

1. **For first-time users:**
   ```powershell
   .\direct-usb-manager.ps1
   ```

2. **For regular use:**
   ```powershell
   .\run-cp2102-admin.ps1
   ```

## Features

### ✅ What these scripts do:
- List all connected USB devices
- Show current sharing status (Not shared / Shared / Attached)
- Bind and attach USB devices to WSL
- Detach USB devices from WSL
- Automatically load appropriate Linux drivers
- Support for common USB-to-serial chips (FTDI, CP210x, CH341)

### 🎯 Device Status Colors:
- **White** = Not shared with WSL
- **Yellow** = Shared (bound) but not attached
- **Green** = Attached and available in WSL

### 🎮 Controls (simple-usb-manager.ps1):
- `1-9` = Select device by number
- `A` = Switch to ATTACH mode
- `D` = Switch to DETACH mode  
- `R` = Refresh device list
- `Q` = Quit

## Requirements

- **Windows 10/11** with WSL 2
- **Administrator privileges** (for USB device management)
- **usbipd-win** tool (scripts can install this automatically)

## Installation

1. Copy scripts to a folder (like `C:\Users\[username]\Scripts\`)
2. Run PowerShell as Administrator
3. Navigate to the folder
4. Run `.\direct-usb-manager.ps1` to get started

## Common Use Cases

### Sharing a USB-to-Serial Converter
1. Connect your device to Windows
2. Run `.\direct-usb-manager.ps1`
3. Select option 1 (Interactive Manager)
4. Choose your device from the list
5. Device will appear in WSL at `/dev/ttyUSB0` or similar

### Arduino/ESP32 Development
- Works with CP2102, FTDI FT232, CH340/CH341 chips
- Automatically loads correct drivers in Linux
- Compatible with Arduino IDE, PlatformIO, esptool, etc.

### Removing Device Sharing
1. Run the interactive manager
2. Press `D` to switch to DETACH mode
3. Select the device to remove

## Troubleshooting

### "usbipd not found"
- Run option 3 in direct-usb-manager.ps1 to install usbipd-win
- Or manually: `winget install usbipd`

### "Administrator privileges required"
- Right-click PowerShell and select "Run as Administrator"
- Or use `run-cp2102-admin.ps1` which auto-elevates

### Device not appearing in WSL
- Check if device shows as "Attached" in Windows
- Run the Linux setup option when prompted
- Verify with `wsl ls /dev/ttyUSB*`

## Technical Details

### Supported Device Types
- **FTDI** (VID:0403) → `ftdi_sio` driver
- **CP210x** (VID:10c4) → `cp210x` driver  
- **CH341** (VID:1a86) → `ch341` driver
- **Generic** → loads common USB serial drivers

### Linux Device Paths
- USB-to-serial devices typically appear as:
  - `/dev/ttyUSB0`, `/dev/ttyUSB1`, etc.
  - `/dev/ttyACM0`, `/dev/ttyACM1`, etc.

### Usage in WSL
```bash
# Test connection
sudo screen /dev/ttyUSB0 115200

# Alternative terminal
sudo minicom -D /dev/ttyUSB0

# Allow user access (optional)
sudo chmod 666 /dev/ttyUSB0
sudo usermod -a -G dialout $USER
```

## Created by
USB Manager scripts for WSL device sharing - Created $(Get-Date -Format "yyyy-MM-dd")
