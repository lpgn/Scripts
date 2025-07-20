# WSL USB Bridge

A set of PowerShell scripts to seamlessly share USB devices, especially serial devices like Arduino, ESP32, and FTDI converters, from Windows to WSL (Windows Subsystem for Linux).

This tool automates the entire process of binding the device on Windows and setting it up with the correct drivers and permissions in WSL.

## Key Features

- **Interactive Menu**: A simple, number-based menu to view, attach, and detach devices.
- **Automated WSL Setup**: When you attach a device, the script automatically:
  - Loads the necessary kernel modules in WSL (`ftdi_sio`, `cp210x`, etc.).
  - Adds your user to the `dialout` group for permanent serial port access.
  - Sets temporary `read/write` permissions on the device file (`/dev/ttyUSB0`, etc.) so it works immediately.
- **`sudo` Password Prompt**: Securely prompts for your password within the WSL terminal for commands that require elevation.
- **No More "Permission Denied"**: Solves the common `[Errno 13] Permission denied` error when accessing serial ports in WSL.
- **Self-Contained**: Can automatically install the required `usbipd-win` dependency using `winget`.

---

## Scripts Overview

1.  **`direct-usb-manager.ps1` - (Recommended Start Point)**
    - The main launcher script. It displays the current device status and provides a menu to access all other functionality. It does not require admin rights to run, but will prompt for them when needed.

2.  **`simple-usb-manager.ps1` - (The Interactive Core)**
    - The core interactive manager that allows you to select devices to attach or detach. It is launched automatically by the main script.

3.  **`run-cp2102-admin.ps1` - (Admin Shortcut)**
    - A simple convenience script that re-launches the main `direct-usb-manager.ps1` with Administrator privileges. Useful for creating desktop shortcuts.

---

## Quick Start

1.  Open a PowerShell terminal.
2.  Navigate to the script directory.
3.  Run the main launcher:

    ```powershell
    .\direct-usb-manager.ps1
    ```

4.  Select **Option 2 (Quick attach)** to see a list of devices.
5.  Choose the device you want to share.
6.  When prompted to **"Setup device in Linux?"**, type `y` and press Enter.
7.  Enter your **Linux `sudo` password** when prompted in the terminal.

Your device is now ready to use in WSL!

## How It Works

The process involves two stages:

1.  **Windows Host**: The PowerShell script uses the `usbipd-win` tool to bind the USB device's interface, making it available for sharing over an IP network (in this case, the local virtual network for WSL).

2.  **WSL Guest**: The script then executes a temporary `bash` script inside WSL. This script:
    a. Probes the appropriate kernel modules (`modprobe`).
    b. Adds the user to the `dialout` group (`usermod`).
    c. Finds the device name (e.g., `ttyUSB0`) from kernel messages (`dmesg`).
    d. Sets permissions on the device file (`chmod 666`).

This two-step process ensures the device is not only connected but also immediately usable.

## Requirements

- Windows 10/11 with WSL 2 installed.
- `usbipd-win` (the script can install this for you via `winget`).
- Administrator privileges in PowerShell for sharing operations.
- Your user password for `sudo` commands within WSL.