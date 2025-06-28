# Direct USB Manager - runs in current window
# Shows status and options before elevating

# Helper function to parse device list from usbipd
function Get-USBDevices {
    $usbOutput = usbipd list 2>&1
    $devices = @()
    
    $inConnected = $false
    foreach ($line in $usbOutput) {
        if ($line -match "Connected:") { $inConnected = $true; continue }
        if ($line -match "Persisted:") { $inConnected = $false; continue }
        
        if ($inConnected -and $line -match "^\s*([\d-]+)\s+([\da-fA-F:]+)\s+(.*?)\s+((?:Not shared|Shared|Attached)(?:\s+to .*)?)$") {
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

# Helper function to attach a device
function Attach-USBDevice {
    param([PSCustomObject]$Device)
    
    Write-Host ""
    Write-Host "Attaching device: $($Device.Description)" -ForegroundColor Green
    
    if ($Device.State -match "Attached") {
        Write-Host "✅ Device is already attached to WSL!" -ForegroundColor Green
        return
    }
    
    # Force binding, as it's harmless to re-bind
    Write-Host "Binding device..." -ForegroundColor Gray
    $bindOutput = usbipd bind --busid $Device.BUSID --force 2>&1
    if ($LASTEXITCODE -ne 0 -and $bindOutput -notmatch "already bound") {
        Write-Host "❌ Error binding device." -ForegroundColor Red
        Write-Host $bindOutput -ForegroundColor Gray
        return
    }

    Write-Host "Attaching to WSL..." -ForegroundColor Gray
    $attachOutput = usbipd attach --wsl --busid $Device.BUSID 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Device attached to WSL successfully!" -ForegroundColor Green
    } elseif ($attachOutput -match "is already attached") {
        Write-Host "✅ Device is already attached." -ForegroundColor Green
    }
    else {
        Write-Host "❌ Error attaching device." -ForegroundColor Red
        Write-Host $attachOutput -ForegroundColor Gray
    }
}


while ($true) {
    Clear-Host
    Write-Host "USB Device Manager for WSL" -ForegroundColor Cyan
    Write-Host "==========================" -ForegroundColor Cyan
    Write-Host ""

    # Check current privileges
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($isAdmin) {
        Write-Host "✅ Running with Administrator privileges" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Not running as Administrator" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Current USB devices:" -ForegroundColor Cyan

    try {
        # Show current USB status
        $usbOutput = usbipd list
        
        Write-Host ""
        $usbOutput | ForEach-Object {
            if ($_ -match "^(\d+-\d+)\s+.*\s+(Not shared|Shared|Attached)") {
                $color = switch ($matches[2]) {
                    "Not shared" { "White" }
                    "Shared" { "Yellow" }
                    "Attached" { "Green" }
                }
                Write-Host $_ -ForegroundColor $color
            } else {
                Write-Host $_ -ForegroundColor Gray
            }
        }
        
        Write-Host ""
        Write-Host "Legend:" -ForegroundColor Yellow
        Write-Host "  White = Not shared" -ForegroundColor White
        Write-Host "  Yellow = Shared (bound)" -ForegroundColor Yellow
        Write-Host "  Green = Attached to WSL" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Could not list USB devices. usbipd may not be installed." -ForegroundColor Red
        Write-Host "Install with: winget install usbipd" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "1. Launch Interactive USB Manager (requires admin)" -ForegroundColor White
    Write-Host "2. Quick attach specific device (requires admin)" -ForegroundColor White
    Write-Host "3. Install usbipd-win tool" -ForegroundColor White
    Write-Host "4. Show help" -ForegroundColor White
    Write-Host "Q. Quit" -ForegroundColor White
    Write-Host ""

    $choice = Read-Host "Enter your choice"
    $shouldContinue = $true

    switch ($choice) {
        "1" {
            if ($isAdmin) {
                Write-Host "Starting Interactive USB Manager..." -ForegroundColor Green
                $managerPath = Join-Path $PSScriptRoot "simple-usb-manager.ps1"
                if (Test-Path $managerPath) {
                    # This will block until the other script exits
                    & powershell -ExecutionPolicy Bypass -File $managerPath
                } else {
                    Write-Host "❌ simple-usb-manager.ps1 not found!" -ForegroundColor Red
                }
            } else {
                Write-Host "Elevating to Administrator..." -ForegroundColor Yellow
                $managerPath = Join-Path $PSScriptRoot "simple-usb-manager.ps1"
                # This starts a new window and does not block
                Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$managerPath`""
            }
        }
        "2" {
            if ($isAdmin) {
                $devices = Get-USBDevices
                if ($devices.Count -eq 0) {
                    Write-Host "No USB devices found." -ForegroundColor Red
                    break # breaks from switch
                }

                Write-Host ""
                Write-Host "Available devices to attach:" -ForegroundColor Yellow
                for ($i = 0; $i -lt $devices.Count; $i++) {
                    $device = $devices[$i]
                    $stateColor = switch ($device.State) {
                        "Not shared" { "White" }
                        "Shared"   { "Yellow" }
                        "Attached" { "Green" }
                        default    { "Gray" }
                    }
                    Write-Host "[$($i + 1)] " -NoNewline -ForegroundColor Cyan
                    Write-Host "$($device.BUSID) - $($device.Description) " -NoNewline -ForegroundColor White
                    Write-Host "($($device.State))" -ForegroundColor $stateColor
                }
                Write-Host "  Q - Cancel" -ForegroundColor White
                Write-Host ""

                $choice = Read-Host "Enter device number to attach (or Q to cancel)"
                if ($choice -match '^[qQ]$') {
                    break # breaks from switch
                }

                if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $devices.Count) {
                    $selectedDevice = $devices[[int]$choice - 1]
                    Attach-USBDevice -Device $selectedDevice
                } else {
                    Write-Host "❌ Invalid selection." -ForegroundColor Red
                }
            } else {
                Write-Host "❌ Administrator privileges required for this operation" -ForegroundColor Red
            }
        }
        "3" {
            Write-Host "Installing usbipd-win..." -ForegroundColor Yellow
            try {
                # Using -Wait to ensure the main script pauses during installation
                Start-Process winget "install --interactive --exact dorssel.usbipd-win" -Wait
            }
            catch {
                Write-Host "❌ Error installing usbipd-win" -ForegroundColor Red
            }
        }
        "4" {
            Write-Host ""
            Write-Host "USB Device Manager Help" -ForegroundColor Cyan
            Write-Host "=======================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "This tool helps you share USB devices between Windows and WSL." -ForegroundColor White
            Write-Host ""
            Write-Host "Steps:" -ForegroundColor Yellow
            Write-Host "1. Connect your USB device to Windows" -ForegroundColor White
            Write-Host "2. Run this tool as Administrator" -ForegroundColor White
            Write-Host "3. Select the device to share" -ForegroundColor White
            Write-Host "4. The device will appear in WSL at /dev/ttyUSB0 or similar" -ForegroundColor White
            Write-Host ""
            Write-Host "Files created:" -ForegroundColor Yellow
            Write-Host "- run-cp2102-admin.ps1 (this file)" -ForegroundColor White
            Write-Host "- simple-usb-manager.ps1 (interactive manager)" -ForegroundColor White
            Write-Host "- share-cp2102.ps1 (specific device script)" -ForegroundColor White
        }
        { $_ -match "^[qQ]$" } {
            Write-Host "Goodbye!" -ForegroundColor Green
            $shouldContinue = $false
        }
        default {
            Write-Host "❌ Invalid choice" -ForegroundColor Red
        }
    }

    if (-not $shouldContinue) {
        break
    }
    
    Write-Host ""
    Read-Host "Press Enter to continue..."
}