# USB Device Manager for WSL (Non-Admin Version)
# Can attach already-shared devices without Administrator privileges

param(
    [switch]$Help
)

if ($Help) {
    Write-Host "USB Device Manager for WSL (Non-Admin Version)" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This script allows you to:" -ForegroundColor Yellow
    Write-Host "1. List all connected USB devices" -ForegroundColor White
    Write-Host "2. Attach already-shared devices to WSL" -ForegroundColor White
    Write-Host "3. Detach devices from WSL" -ForegroundColor White
    Write-Host "4. Setup devices in Linux" -ForegroundColor White
    Write-Host ""
    Write-Host "Note: To share/bind new devices, use the admin version" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Usage: .\usb-manager-nonadmin.ps1" -ForegroundColor Green
    exit 0
}

function Test-AdminRights {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

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
            }
        }
    }
    return $devices
}

function Show-DeviceList {
    param(
        [array]$Devices,
        [string]$Mode = "attach"
    )
    
    Clear-Host
    $isAdmin = Test-AdminRights
    
    Write-Host "USB Device Manager for WSL " -NoNewline -ForegroundColor Cyan
    if ($isAdmin) {
        Write-Host "(Administrator Mode)" -ForegroundColor Green
    } else {
        Write-Host "(Standard Mode)" -ForegroundColor Yellow
    }
    Write-Host "==========================" -ForegroundColor Cyan
    Write-Host ""
    
    if (-not $isAdmin) {
        Write-Host "ℹ️  Running in Standard Mode - can attach already-shared devices" -ForegroundColor Yellow
        Write-Host "   For full device management, run as Administrator" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "Current mode: " -NoNewline
    if ($Mode -eq "attach") {
        Write-Host "ATTACH (sharing devices to WSL)" -ForegroundColor Green
    } else {
        Write-Host "DETACH (removing devices from WSL)" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Available USB devices:" -ForegroundColor Yellow
    Write-Host ""
    
    for ($i = 0; $i -lt $Devices.Count; $i++) {
        $device = $Devices[$i]
        $stateColor = switch -regex ($device.State) {
            "Not shared" { "White" }
            "Shared"     { "Yellow" }
            "Attached"   { "Green" }
            default      { "Gray" }
        }
        
        $canAttach = ($device.State -match "Shared") -or $isAdmin
        $canDetach = ($device.State -match "Attached") -or $isAdmin
        
        Write-Host "[$($i + 1)] " -NoNewline -ForegroundColor Cyan
        Write-Host "$($device.BUSID) - " -NoNewline -ForegroundColor Gray
        Write-Host "$($device.Description) " -NoNewline -ForegroundColor White
        Write-Host "[$($device.VIDPID)] " -NoNewline -ForegroundColor Gray
        Write-Host "($($device.State))" -NoNewline -ForegroundColor $stateColor
        
        # Show what operations are available
        if ($Mode -eq "attach" -and -not $canAttach -and $device.State -eq "Not shared") {
            Write-Host " [Admin required to share]" -ForegroundColor Red
        } elseif ($Mode -eq "detach" -and -not $canDetach) {
            Write-Host " [Admin required to detach]" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Yellow
    Write-Host "  1-$($Devices.Count) - Select device" -ForegroundColor White
    Write-Host "  A - Switch to ATTACH mode" -ForegroundColor White
    Write-Host "  D - Switch to DETACH mode" -ForegroundColor White
    Write-Host "  R - Refresh device list" -ForegroundColor White
    if (-not $isAdmin) {
        Write-Host "  E - Run as Administrator (full management)" -ForegroundColor Cyan
    }
    Write-Host "  Q - Quit" -ForegroundColor White
    Write-Host ""
}

function Attach-USBDevice {
    param([PSCustomObject]$Device)
    
    Write-Host "Attaching device: $($Device.Description)" -ForegroundColor Green
    Write-Host "BUSID: $($Device.BUSID)" -ForegroundColor Cyan
    
    if ($Device.State -match "Attached") {
        Write-Host "[OK] Device is already attached to WSL." -ForegroundColor Green
        return $true
    }
    
    $isAdmin = Test-AdminRights
    
    if ($Device.State -eq "Not shared" -and -not $isAdmin) {
        Write-Host "[-] Device is not shared. Administrator privileges required to share it first." -ForegroundColor Red
        Write-Host "    Use 'E' command to run as Administrator" -ForegroundColor Yellow
        return $false
    }
    
    if ($Device.State -eq "Not shared") {
        Write-Host "Step 1: Binding device..." -ForegroundColor Yellow
        $bindOutput = usbipd bind --busid $Device.BUSID --force 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[-] Error binding device." -ForegroundColor Red
            Write-Host $bindOutput -ForegroundColor Gray
            return $false
        }
        Write-Host "[OK] Device bound successfully." -ForegroundColor Green
    }
    
    Write-Host "Step 2: Attaching to WSL..." -ForegroundColor Yellow
    $attachOutput = usbipd attach --wsl --busid $Device.BUSID 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Device attached to WSL successfully." -ForegroundColor Green
        return $true
    }
    
    if ($attachOutput -match "is already attached") {
        Write-Host "[OK] Device is already attached to WSL." -ForegroundColor Green
        return $true
    }
    
    Write-Host "[-] Error attaching device." -ForegroundColor Red
    Write-Host $attachOutput -ForegroundColor Gray
    return $false
}

function Detach-USBDevice {
    param([PSCustomObject]$Device)
    
    Write-Host "Detaching device: $($Device.Description)" -ForegroundColor Yellow
    Write-Host "BUSID: $($Device.BUSID)" -ForegroundColor Cyan
    
    if ($Device.State -eq "Not shared") {
        Write-Host "[OK] Device is not attached or shared." -ForegroundColor Green
        return $true
    }
    
    if ($Device.State -match "Attached") {
        Write-Host "Step 1: Detaching from WSL..." -ForegroundColor Yellow
        $detachOutput = usbipd detach --busid $Device.BUSID 2>&1
        if ($LASTEXITCODE -ne 0) {
            if ($detachOutput -match "not attached") {
                Write-Host "[INFO] Device was not attached." -ForegroundColor Yellow
            } else {
                Write-Host "[-] Error detaching device." -ForegroundColor Red
                Write-Host $detachOutput -ForegroundColor Gray
                return $false
            }
        } else {
            Write-Host "[OK] Device detached successfully." -ForegroundColor Green
        }
        return $true
    }
    
    $isAdmin = Test-AdminRights
    if (-not $isAdmin) {
        Write-Host "[INFO] Device is shared but not attached. Use Administrator mode to fully unbind." -ForegroundColor Yellow
        return $true
    }
    
    Write-Host "Step 2: Unbinding device..." -ForegroundColor Yellow
    $unbindOutput = usbipd unbind --busid $Device.BUSID 2>&1
    if ($LASTEXITCODE -ne 0) {
        if ($unbindOutput -match "is not bound") {
            Write-Host "[OK] Device is already unbound." -ForegroundColor Green
            return $true
        }
        Write-Host "[-] Error unbinding device." -ForegroundColor Red
        Write-Host $unbindOutput -ForegroundColor Gray
        return $false
    }

    Write-Host "[OK] Device unbound successfully." -ForegroundColor Green
    return $true
}

function Setup-LinuxDevice {
    param([PSCustomObject]$Device)
    
    Write-Host ""
    Write-Host "Setting up device in Linux..." -ForegroundColor Cyan
    
    $scriptTemplate = @'
#!/bin/bash
set -e

echo '=== Linux Device Setup ==='
echo 'Device: ##DESCRIPTION## (##VIDPID##)'
echo ''
echo 'You may be prompted for your password to run commands with sudo.'
echo ''

echo '[1] Loading kernel drivers...'
case "##VIDPID##" in
    "0403:"*) sudo modprobe ftdi_sio ;;
    "10c4:"*) sudo modprobe cp210x ;;
    "1a86:"*) sudo modprobe ch341 ;;
    *)       sudo modprobe usbserial ftdi_sio cp210x ch341 ;;
esac
sleep 1.5

echo ''
echo '[2] Setting device permissions...'

if ! groups $USER | grep -q '\bdialout\b'; then
    echo "Adding user '$USER' to the 'dialout' group for serial port access."
    sudo usermod -a -G dialout $USER
    echo "NOTE: You may need to restart your WSL terminal for this change to take full effect."
else
    echo "User '$USER' is already in the 'dialout' group."
fi

DEVICE_NAME=$(dmesg | grep -i "now attached to tty" | tail -n 1 | sed -n 's/.*attached to //p')

if [ -n "$DEVICE_NAME" ]; then
    DEVICE_PATH="/dev/$DEVICE_NAME"
    echo "Device file found at: $DEVICE_PATH"
    echo "Applying temporary read/write permissions (666) for the current session."
    sudo chmod 666 "$DEVICE_PATH"
    echo "Permissions successfully applied:"
    ls -l "$DEVICE_PATH"
else
    echo "Could not find a newly created /dev/ttyUSB* or /dev/ttyACM* device from dmesg."
fi

echo ''
echo '[3] Verifying setup...'
dmesg | grep -iE "usb|serial|tty" | tail -n 5
echo ''
echo 'Setup complete.'
'@
    
    $setupScript = $scriptTemplate `
        -replace '##DESCRIPTION##', $Device.Description `
        -replace '##VIDPID##', $Device.VIDPID

    $tempScriptPath = Join-Path $PSScriptRoot "temp-setup-linux.sh"
    [System.IO.File]::WriteAllText($tempScriptPath, $setupScript, (New-Object System.Text.UTF8Encoding($false)))
    
    try {
        $driveLetter = $tempScriptPath.Substring(0,1).ToLower()
        $pathAfterDrive = $tempScriptPath.Substring(2).Replace('\', '/')
        $wslPath = "/mnt/$driveLetter$pathAfterDrive"

        wsl.exe bash -c "chmod +x '$wslPath' && '$wslPath'"
    }
    catch {
        Write-Host "[-] Error running Linux setup script: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        if (Test-Path $tempScriptPath) {
            Remove-Item $tempScriptPath -ErrorAction SilentlyContinue
        }
    }
}

function Start-AdminVersion {
    Write-Host "Starting Administrator version..." -ForegroundColor Yellow
    try {
        $scriptPath = Join-Path $PSScriptRoot "simple-usb-manager.ps1"
        if (Test-Path $scriptPath) {
            $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
            Start-Process PowerShell -Verb RunAs -ArgumentList $arguments
            Write-Host "Administrator window opened!" -ForegroundColor Green
        } else {
            Write-Host "Error: simple-usb-manager.ps1 not found!" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Error starting administrator version: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Main execution
$currentMode = "attach"

while ($true) {
    $devices = Get-USBDevices
    
    if ($devices.Count -eq 0) {
        Write-Host "No USB devices found!" -ForegroundColor Red
        Read-Host "Press Enter to refresh"
        continue
    }
    
    Show-DeviceList -Devices $devices -Mode $currentMode
    
    $input = Read-Host "Enter your choice"
    
    switch -regex ($input) {
        "^[qQ]$" {
            Write-Host "Goodbye!" -ForegroundColor Green
            exit 0
        }
        "^[aA]$" {
            $currentMode = "attach"
            continue
        }
        "^[dD]$" {
            $currentMode = "detach"
            continue
        }
        "^[rR]$" {
            continue
        }
        "^[eE]$" {
            if (-not (Test-AdminRights)) {
                Start-AdminVersion
                continue
            } else {
                Write-Host "Already running as Administrator!" -ForegroundColor Yellow
                Start-Sleep 1
                continue
            }
        }
        "^\d+$" {
            $deviceIndex = [int]$input - 1
            if ($deviceIndex -ge 0 -and $deviceIndex -lt $devices.Count) {
                $selectedDevice = $devices[$deviceIndex]
                
                Write-Host ""
                if ($currentMode -eq "attach") {
                    if (Attach-USBDevice -Device $selectedDevice) {
                        $setupLinux = Read-Host "Setup device in Linux? (Y/n)"
                        if ($setupLinux -eq "" -or $setupLinux -match "^[Yy]") {
                            Setup-LinuxDevice -Device $selectedDevice
                        }
                    }
                } else {
                    Detach-USBDevice -Device $selectedDevice
                }
                
                Write-Host ""
                Read-Host "Press Enter to return to the menu..."
            } else {
                Write-Host "[-] Invalid device number!" -ForegroundColor Red
                Start-Sleep 1
            }
        }
        default {
            Write-Host "[-] Invalid input! Please try again." -ForegroundColor Red
            Start-Sleep 1
        }
    }
}
