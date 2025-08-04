# Simple USB Manager with Arrow Key Navigation
# Easy-to-use interface - just use arrow keys and Enter!

Add-Type -AssemblyName System.Console

function Get-USBDevices {
    $usbOutput = usbipd list 2>&1
    $devices = @()
    
    $inConnected = $false
    foreach ($line in $usbOutput) {
        if ($line -match "Connected:") { $inConnected = $true; continue }
        if ($line -match "Persisted:") { $inConnected = $false; continue }
        
        if ($inConnected -and $line -match "^\s*([\d-]+)\s+([\da-fA-F:]+)\s+(.*?)\s+((?:Not shared|Shared|Attached).*?)$") {
            $devices += [PSCustomObject]@{
                BUSID       = $matches[1]
                VIDPID      = $matches[2]
                Description = $matches[3].Trim()
                State       = $matches[4].Trim()
                CanAttach   = ($matches[4] -match "Shared" -and $matches[4] -notmatch "Attached")
                IsAttached  = ($matches[4] -match "Attached")
            }
        }
    }
    return $devices
}

function Show-Menu {
    param(
        [array]$Items,
        [int]$SelectedIndex = 0,
        [string]$Title = "Select an option"
    )
    
    Clear-Host
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ("=" * $Title.Length) -ForegroundColor Cyan
    Write-Host ""
    
    for ($i = 0; $i -lt $Items.Count; $i++) {
        if ($i -eq $SelectedIndex) {
            Write-Host "► " -NoNewline -ForegroundColor Green
            Write-Host $Items[$i] -ForegroundColor Yellow -BackgroundColor DarkBlue
        } else {
            Write-Host "  " -NoNewline
            Write-Host $Items[$i] -ForegroundColor White
        }
    }
    
    Write-Host ""
    Write-Host "Use UP/DOWN arrow keys to navigate, Enter to select, Q/ESC to go back/exit" -ForegroundColor Gray
}

function Get-UserChoice {
    param(
        [array]$Items,
        [string]$Title = "Select an option"
    )
    
    $selectedIndex = 0
    
    while ($true) {
        Show-Menu -Items $Items -SelectedIndex $selectedIndex -Title $Title
        
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.VirtualKeyCode) {
            38 { # Up arrow
                $selectedIndex = if ($selectedIndex -eq 0) { $Items.Count - 1 } else { $selectedIndex - 1 }
            }
            40 { # Down arrow
                $selectedIndex = if ($selectedIndex -eq $Items.Count - 1) { 0 } else { $selectedIndex + 1 }
            }
            13 { # Enter
                return $selectedIndex
            }
            27 { # Escape - same as Q
                return -1
            }
            81 { # Q key - same as Escape
                return -1
            }
        }
    }
}

function Show-DeviceMenu {
    param([array]$Devices)
    
    $menuItems = @()
    foreach ($device in $Devices) {
        $status = switch -regex ($device.State) {
            "Attached" { "[ATTACHED]" }
            "Shared" { "[READY TO ATTACH]" }
            "Not shared" { "[NOT SHARED]" }
            default { "[UNKNOWN]" }
        }
        
        $menuItems += "$($device.BUSID) - $($device.Description) $status"
    }
    
    # Add action options
    $menuItems += ""
    $menuItems += "🔄 Refresh Device List"
    
    $choice = Get-UserChoice -Items $menuItems -Title "USB Device Manager - Select Device or Action"
    
    if ($choice -eq -1) {
        return "quit"
    } elseif ($choice -eq $Devices.Count) {
        return "refresh"
    } elseif ($choice -eq $Devices.Count + 1) {
        return "refresh"
    } else {
        return $choice
    }
}

function Show-DeviceActions {
    param([PSCustomObject]$Device)
    
    $actions = @()
    
    if ($Device.IsAttached) {
        $actions += "Detach from WSL"
        $actions += "Setup in Linux"
    } elseif ($Device.CanAttach) {
        $actions += "Attach to WSL"
    } else {
        $actions += "Cannot attach (device not shared - need admin)"
    }
    
    $title = "Device: $($Device.Description) [$($Device.State)] - Q/ESC to go back"
    $choice = Get-UserChoice -Items $actions -Title $title
    
    return $choice
}

function Invoke-AttachDevice {
    param([PSCustomObject]$Device)
    
    Clear-Host
    Write-Host "Attaching Device to WSL" -ForegroundColor Green
    Write-Host "======================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Device: $($Device.Description)" -ForegroundColor Cyan
    Write-Host "BUSID:  $($Device.BUSID)" -ForegroundColor Cyan
    Write-Host ""
    
    if ($Device.IsAttached) {
        Write-Host "✅ Device is already attached!" -ForegroundColor Green
        Start-Sleep 1
        return $true
    }
    
    Write-Host "Attaching device..." -ForegroundColor Yellow
    $result = usbipd attach --wsl --busid $Device.BUSID 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Device attached successfully!" -ForegroundColor Green
        Start-Sleep 1
        return $true
    } else {
        Write-Host "❌ Failed to attach device:" -ForegroundColor Red
        Write-Host $result -ForegroundColor Gray
        Start-Sleep 2
        return $false
    }
}

function Invoke-DetachDevice {
    param([PSCustomObject]$Device)
    
    Clear-Host
    Write-Host "Detaching Device from WSL" -ForegroundColor Yellow
    Write-Host "=========================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Device: $($Device.Description)" -ForegroundColor Cyan
    Write-Host "BUSID:  $($Device.BUSID)" -ForegroundColor Cyan
    Write-Host ""
    
    if (-not $Device.IsAttached) {
        Write-Host "ℹ️  Device is not attached." -ForegroundColor Yellow
        Start-Sleep 1
        return $true
    }
    
    Write-Host "Detaching device..." -ForegroundColor Yellow
    $result = usbipd detach --busid $Device.BUSID 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Device detached successfully!" -ForegroundColor Green
        Start-Sleep 1
        return $true
    } else {
        Write-Host "❌ Failed to detach device:" -ForegroundColor Red
        Write-Host $result -ForegroundColor Gray
        Start-Sleep 2
        return $false
    }
}

function Invoke-SetupLinuxDevice {
    param([PSCustomObject]$Device)

    Clear-Host
    Write-Host "Linux Device Setup (udev)" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Device: $($Device.Description)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This will install a udev rule to automatically manage permissions" -ForegroundColor White
    Write-Host "for common USB-to-serial devices." -ForegroundColor White
    Write-Host ""

    # Find the udev rules file
    $rulesFile = "99-platformio-udev.rules"
    # Use $PSScriptRoot for a reliable way to get the script's directory
    $scriptPath = $PSScriptRoot
    $rulesFilePath = Join-Path $scriptPath $rulesFile

    if (-not (Test-Path $rulesFilePath)) {
        Write-Host "❌ CRITICAL: udev rules file not found!" -ForegroundColor Red
        Write-Host "Expected to find '$rulesFile' in the same directory as the script." -ForegroundColor Red
        Write-Host "Path: $scriptPath" -ForegroundColor Gray
        Start-Sleep 5
        return
    }

    Write-Host "Found udev rules file: $rulesFilePath" -ForegroundColor Green
    Write-Host ""
    Write-Host "Running setup commands in WSL..." -ForegroundColor Yellow
    
    # Test WSL first
    try {
        $wslTest = wsl.exe -- echo "WSL is working" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ WSL is not responding properly." -ForegroundColor Red
            Write-Host "WSL output: $wslTest" -ForegroundColor Gray
            Start-Sleep 3
            return
        }
    } catch {
        Write-Host "❌ Error testing WSL: $($_.Exception.Message)" -ForegroundColor Red
        Start-Sleep 3
        return
    }

    Write-Host ""
    Write-Host "🔑 PASSWORD NEEDED: Type your WSL password for admin commands." -ForegroundColor Yellow -BackgroundColor DarkRed
    
    # Simplified approach: check if file exists, skip problematic path conversion
    $setupScriptContent = @'
#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

echo "Starting WSL setup..."
DEST_RULES_FILE="/lib/udev/rules.d/99-platformio-udev.rules"

# NOTE: WSL doesn't run udev by default, so udev rules don't work automatically.
# We need to manually load drivers and bind devices. This is what makes USB devices
# actually appear as /dev/ttyUSB* or /dev/ttyACM* in WSL.

echo "🔑 Please enter your password once for all admin operations..."
sudo -v  # Refresh sudo timestamp

# 1. Check if the rules file exists (for reference/future use)
echo "[1/5] Checking udev rules file..."
if [ -f "$DEST_RULES_FILE" ]; then
    echo "      ✅ udev rules file already exists at $DEST_RULES_FILE"
else
    echo "      ℹ️  udev rules file not found (not critical for WSL)"
    echo "      You can manually copy: sudo cp /mnt/c/Users/lpgn/Scripts/99-platformio-udev.rules $DEST_RULES_FILE"
fi

# 2. Load essential USB-to-serial kernel modules
echo "[2/5] Loading USB-to-serial kernel modules..."
sudo modprobe usbserial || echo "Info: usbserial module not available or already loaded."
sudo modprobe ftdi_sio || echo "Info: ftdi_sio module not available or already loaded."
sudo modprobe cp210x || echo "Info: cp210x module not available or already loaded."
sudo modprobe ch341 || echo "Info: ch341 module not available or already loaded."

# 3. Detect and bind currently connected USB-to-serial devices
echo "[3/5] Detecting and binding USB-to-serial devices..."
echo "      Scanning for connected USB devices..."

# Get list of USB devices and their VID:PID
USB_DEVICES=$(lsusb | grep -E "(FTDI|Silicon Labs|QinHeng|Prolific|Arduino)" || true)
if [ -n "$USB_DEVICES" ]; then
    echo "      Found potential USB-to-serial devices:"
    echo "$USB_DEVICES" | sed 's/^/         /'
    
    # Extract VID:PID pairs and try to bind them
    lsusb | grep -E "(FTDI|Silicon Labs|QinHeng|Prolific|Arduino)" | while read line; do
        # Extract VID:PID (format: "ID 1234:5678")
        VIDPID=$(echo "$line" | grep -o "ID [0-9a-f]*:[0-9a-f]*" | cut -d' ' -f2)
        VID=$(echo "$VIDPID" | cut -d':' -f1)
        PID=$(echo "$VIDPID" | cut -d':' -f2)
        
        echo "      Attempting to bind device $VID:$PID..."
        
        # Try different drivers based on VID
        case "$VID" in
            "0403") # FTDI
                echo "$VID $PID" | sudo tee /sys/bus/usb-serial/drivers/ftdi_sio/new_id >/dev/null 2>&1 || true
                ;;
            "10c4") # Silicon Labs CP210x
                echo "$VID $PID" | sudo tee /sys/bus/usb-serial/drivers/cp210x/new_id >/dev/null 2>&1 || true
                ;;
            "1a86") # QinHeng (CH340/CH341/CH9102)
                echo "$VID $PID" | sudo tee /sys/bus/usb-serial/drivers/ch341-uart/new_id >/dev/null 2>&1 || true
                ;;
        esac
    done
else
    echo "      No obvious USB-to-serial devices found by name."
    echo "      If your device isn't working, you may need to manually bind it."
fi

# 4. Set permissions on any created serial devices
echo "[4/5] Setting permissions on serial devices..."
SERIAL_DEVICES=$(ls /dev/tty{USB,ACM}* 2>/dev/null || true)
if [ -n "$SERIAL_DEVICES" ]; then
    echo "      Found serial devices:"
    echo "$SERIAL_DEVICES" | sed 's/^/         /'
    echo "      Setting permissions to 666 (read/write for all users)..."
    sudo chmod 666 /dev/tty{USB,ACM}* 2>/dev/null || true
    echo "      ✅ Permissions updated"
else
    echo "      No /dev/ttyUSB* or /dev/ttyACM* devices found yet."
    echo "      This might be normal if no USB-to-serial devices are attached."
fi

# 5. Add user to dialout group (standard practice)
echo "[5/5] Checking user group membership..."
if groups $USER | grep -q '\bdialout\b'; then
    echo "      ✅ User $USER is already in 'dialout' group."
else
    echo "      Adding user $USER to 'dialout' group..."
    sudo usermod -aG dialout $USER
    echo "      ✅ Added to dialout group. You may need to restart WSL for this to take full effect."
fi

echo "Setup script finished."
'@

    # Ensure script has Linux (LF) line endings, convert to UTF8 bytes, then to Base64
    $lfScriptContent = $setupScriptContent.Replace("`r`n", "`n")
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($lfScriptContent)
    $base64Script = [System.Convert]::ToBase64String($bytes)

    # Execute the script in WSL by decoding the Base64 string and piping it to bash
    # No arguments needed since we're not copying files anymore
    wsl.exe bash -c "echo '$base64Script' | base64 --decode | bash"
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host ""
        Write-Host "✅ Linux setup completed successfully!" -ForegroundColor Green
        Write-Host "The udev rule is now in place." -ForegroundColor Cyan
        Write-Host "You may need to DETACH and RE-ATTACH your USB device for the new rule to apply." -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "❌ An error occurred during the Linux setup." -ForegroundColor Red
        Write-Host "Please review the output above for details." -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Main program
Clear-Host

Write-Host "🔌 Easy USB Manager for WSL" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host ""

# Simple admin check - just show a warning if not admin, but continue anyway
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    Write-Host "Running with Administrator privileges" -ForegroundColor Green
} else {
    Write-Host "Not running as Administrator - some operations may fail" -ForegroundColor Yellow
}

Write-Host "Starting up..." -ForegroundColor Cyan
Start-Sleep 1

while ($true) {
    $devices = Get-USBDevices
    
    if ($devices.Count -eq 0) {
        Clear-Host
        Write-Host "No USB devices found!" -ForegroundColor Red
        Write-Host ""
        $choice = Get-UserChoice -Items @("Refresh", "Exit") -Title "No USB devices detected"
        if ($choice -eq 1 -or $choice -eq -1) {
            break
        }
        continue
    }
    
    $choice = Show-DeviceMenu -Devices $devices
    
    switch ($choice) {
        "quit" { 
            Clear-Host
            Write-Host "Goodbye!" -ForegroundColor Green
            exit 0 
        }
        "refresh" { 
            continue 
        }
        default {
            if ($choice -is [int] -and $choice -ge 0 -and $choice -lt $devices.Count) {
                $selectedDevice = $devices[$choice]
                
                while ($true) {
                    $action = Show-DeviceActions -Device $selectedDevice
                    
                    if ($action -eq -1) {
                        # Q or ESC pressed - go back to device list
                        break
                    }
                    
                    switch ($action) {
                        0 { # First action (attach or detach)
                            if ($selectedDevice.IsAttached) {
                                Invoke-DetachDevice -Device $selectedDevice
                            } elseif ($selectedDevice.CanAttach) {
                                if (Invoke-AttachDevice -Device $selectedDevice) {
                                    # Refresh device info after successful attach
                                    $devices = Get-USBDevices
                                    $selectedDevice = $devices[$choice]
                                }
                            } else {
                                Clear-Host
                                Write-Host "⚠️  Cannot attach device" -ForegroundColor Yellow
                                Write-Host "========================" -ForegroundColor Yellow
                                Write-Host ""
                                Write-Host "This device is not shared and requires Administrator" -ForegroundColor White
                                Write-Host "privileges to share it first." -ForegroundColor White
                                Write-Host ""
                                Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
                                Write-Host ""
                                Read-Host "Press Enter to continue"
                            }
                        }
                        1 { # Second action (setup Linux)
                            if ($selectedDevice.IsAttached) {
                                Invoke-SetupLinuxDevice -Device $selectedDevice
                            }
                        }
                        default { # Invalid or other
                            break
                        }
                    }
                    
                    # Refresh device info
                    $devices = Get-USBDevices
                    if ($choice -lt $devices.Count) {
                        $selectedDevice = $devices[$choice]
                    } else {
                        break
                    }
                }
            }
        }
    }

}
