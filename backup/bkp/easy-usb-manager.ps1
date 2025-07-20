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
        [string]$Title = "Select an option",
        [switch]$AllowEscape
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
    if ($AllowEscape) {
        Write-Host "Use ↑↓ arrow keys to navigate, Enter to select, ESC to go back, Q to quit" -ForegroundColor Gray
    } else {
        Write-Host "Use ↑↓ arrow keys to navigate, Enter to select, Q to quit" -ForegroundColor Gray
    }
}

function Get-UserChoice {
    param(
        [array]$Items,
        [string]$Title = "Select an option",
        [switch]$AllowEscape
    )
    
    $selectedIndex = 0
    
    while ($true) {
        Show-Menu -Items $Items -SelectedIndex $selectedIndex -Title $Title -AllowEscape:$AllowEscape
        
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
            27 { # Escape
                if ($AllowEscape) {
                    return -2  # Special code for escape
                }
            }
            81 { # Q key
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
        
# Status colors handled by menu display
        
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
        $actions += "🔌 Detach from WSL"
        $actions += "🐧 Setup in Linux"
    } elseif ($Device.CanAttach) {
        $actions += "🔗 Attach to WSL"
    } else {
        $actions += "⚠️  Cannot attach (device not shared - need admin)"
    }
    
    $title = "Device: $($Device.Description) [$($Device.State)] - ESC to go back"
    $choice = Get-UserChoice -Items $actions -Title $title -AllowEscape
    
    return $choice
}

function Attach-Device {
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

function Detach-Device {
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

function Setup-LinuxDevice {
    param([PSCustomObject]$Device)
    
    Clear-Host
    Write-Host "Setting up Device in Linux" -ForegroundColor Cyan
    Write-Host "==========================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Device: $($Device.Description)" -ForegroundColor Cyan
    Write-Host "BUSID:  $($Device.BUSID)" -ForegroundColor Cyan
    Write-Host ""
    
    $confirm = Get-UserChoice -Items @("Yes, setup the device", "No, go back") -Title "Setup device drivers and permissions in Linux?" -AllowEscape
    
    if ($confirm -ne 0) {
        return
    }
    
    Clear-Host
    Write-Host "Linux Device Setup" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Device: $($Device.Description)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This will:" -ForegroundColor White
    Write-Host "1. Load USB serial drivers" -ForegroundColor Gray
    Write-Host "2. Add your user to dialout group" -ForegroundColor Gray
    Write-Host "3. Set device permissions" -ForegroundColor Gray
    Write-Host ""
    Write-Host "You will be prompted for your WSL password..." -ForegroundColor Yellow
    Write-Host ""
    
    # Test WSL first
    Write-Host "Testing WSL connection..." -ForegroundColor Yellow
    try {
        $wslTest = wsl.exe echo "WSL is working" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ WSL is not responding properly" -ForegroundColor Red
            Write-Host "WSL output: $wslTest" -ForegroundColor Gray
            Start-Sleep 3
            return
        }
        Write-Host "✅ WSL connection OK" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Error testing WSL: $($_.Exception.Message)" -ForegroundColor Red
        Start-Sleep 3
        return
    }
    
    Write-Host ""
    Write-Host "Running setup commands..." -ForegroundColor Yellow
    Write-Host ""
    
    # Run commands step by step to see what's happening
    try {
        Write-Host "[1/4] Loading USB serial drivers..." -ForegroundColor Cyan
        
        # Determine which driver to load based on VID:PID
        $driverCmd = switch -wildcard ($Device.VIDPID) {
            "0403:*" { "sudo modprobe ftdi_sio" }
            "10c4:*" { "sudo modprobe cp210x" }
            "1a86:*" { "sudo modprobe ch341" }
            default  { "sudo modprobe usbserial; sudo modprobe ftdi_sio; sudo modprobe cp210x" }
        }
        
        Write-Host "      Running: $driverCmd" -ForegroundColor Gray
        $driverResult = wsl.exe bash -c $driverCmd 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "      ✅ Drivers loaded successfully" -ForegroundColor Green
        } else {
            Write-Host "      ⚠️  Driver loading result: $driverResult" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "[2/4] Checking user groups..." -ForegroundColor Cyan
        $groupCheck = wsl.exe bash -c "groups `$USER | grep -q dialout && echo 'already_in_group' || echo 'need_to_add'" 2>&1
        
        if ($groupCheck -match "already_in_group") {
            Write-Host "      ✅ User is already in dialout group" -ForegroundColor Green
        } else {
            Write-Host "      Adding user to dialout group..." -ForegroundColor Yellow
            Write-Host "      Running: sudo usermod -a -G dialout `$USER" -ForegroundColor Gray
            $groupResult = wsl.exe bash -c "sudo usermod -a -G dialout `$USER" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "      ✅ User added to dialout group" -ForegroundColor Green
                Write-Host "      ℹ️  You may need to restart WSL for this to take full effect" -ForegroundColor Yellow
            } else {
                Write-Host "      ❌ Failed to add user to group: $groupResult" -ForegroundColor Red
            }
        }
        
        Write-Host ""
        Write-Host "[3/4] Looking for device file..." -ForegroundColor Cyan
        
        # Wait a moment for device to appear
        Start-Sleep 2
        
        # Look for the device in multiple ways
        $deviceSearchScript = @'
DEVICE_NAME=$(dmesg | grep -i "now attached to tty" | tail -n 1 | sed -n 's/.*attached to //p')
if [ -n "$DEVICE_NAME" ]; then
    echo "found_in_dmesg:/dev/$DEVICE_NAME"
else
    if ls /dev/ttyUSB* 2>/dev/null; then
        echo "found_ttyusb:$(ls /dev/ttyUSB* 2>/dev/null | tail -n 1)"
    elif ls /dev/ttyACM* 2>/dev/null; then
        echo "found_ttyacm:$(ls /dev/ttyACM* 2>/dev/null | tail -n 1)"
    else
        echo "not_found"
    fi
fi
'@
        
        $deviceSearch = wsl.exe bash -c $deviceSearchScript 2>&1
        
        if ($deviceSearch -match "found_in_dmesg:(.+)") {
            $devicePath = $matches[1]
            Write-Host "      ✅ Found device in dmesg: $devicePath" -ForegroundColor Green
        } elseif ($deviceSearch -match "found_ttyusb:(.+)") {
            $devicePath = $matches[1]
            Write-Host "      ✅ Found USB device: $devicePath" -ForegroundColor Green
        } elseif ($deviceSearch -match "found_ttyacm:(.+)") {
            $devicePath = $matches[1]
            Write-Host "      ✅ Found ACM device: $devicePath" -ForegroundColor Green
        } else {
            Write-Host "      ⚠️  Device file not found automatically" -ForegroundColor Yellow
            Write-Host "      Available devices:" -ForegroundColor Gray
            wsl.exe bash -c 'ls -la /dev/tty{USB,ACM}* 2>/dev/null || echo "No serial devices found"'
            $devicePath = $null
        }
        
        Write-Host ""
        Write-Host "[4/4] Setting device permissions..." -ForegroundColor Cyan
        
        if ($devicePath) {
            Write-Host "      Running: sudo chmod 666 $devicePath" -ForegroundColor Gray
            $permResult = wsl.exe bash -c "sudo chmod 666 '$devicePath'; ls -l '$devicePath'" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "      ✅ Permissions set successfully" -ForegroundColor Green
                Write-Host "      Device info: $permResult" -ForegroundColor Gray
            } else {
                Write-Host "      ❌ Failed to set permissions: $permResult" -ForegroundColor Red
            }
        } else {
            Write-Host "      ⚠️  Skipping permission setting (device path unknown)" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "✅ Linux setup completed!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Recent kernel messages:" -ForegroundColor Cyan
        wsl.exe bash -c "dmesg | grep -iE 'usb|serial|tty' | tail -n 3"
        
    }
    catch {
        Write-Host "❌ Error during Linux setup: $($_.Exception.Message)" -ForegroundColor Red
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
    Write-Host "✅ Running with Administrator privileges" -ForegroundColor Green
} else {
    Write-Host "⚠️  Not running as Administrator - some operations may fail" -ForegroundColor Yellow
}

Write-Host "Starting up..." -ForegroundColor Cyan
Start-Sleep 1

while ($true) {
    $devices = Get-USBDevices
    
    if ($devices.Count -eq 0) {
        Clear-Host
        Write-Host "❌ No USB devices found!" -ForegroundColor Red
        Write-Host ""
        $choice = Get-UserChoice -Items @("🔄 Refresh", "❌ Exit") -Title "No USB devices detected"
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
                    
                    if ($action -eq -2) {
                        # ESC pressed - go back to device list
                        break
                    }
                    
                    switch ($action) {
                        0 { # First action (attach or detach)
                            if ($selectedDevice.IsAttached) {
                                Detach-Device -Device $selectedDevice
                            } elseif ($selectedDevice.CanAttach) {
                                if (Attach-Device -Device $selectedDevice) {
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
                                Setup-LinuxDevice -Device $selectedDevice
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
