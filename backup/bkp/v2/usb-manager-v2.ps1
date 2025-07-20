#Requires -Version 5.1
<#
.SYNOPSIS
    Modern USB Device Manager for WSL
.DESCRIPTION
    A clean, intuitive PowerShell script for managing USB devices in WSL environments.
    Features modern UI, smart device detection, and streamlined workflows.
.AUTHOR
    Generated for improved USB management workflow
#>

# Enable modern PowerShell features
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

#region Classes and Types
Add-Type -AssemblyName System.Console

class USBDevice {
    [string]$BusID
    [string]$VendorProductID
    [string]$Description
    [string]$RawState
    [string]$Status
    [bool]$IsShared
    [bool]$IsAttached
    [bool]$CanAttach
    [string]$DeviceType
    
    USBDevice([string]$busid, [string]$vidpid, [string]$desc, [string]$state) {
        $this.BusID = $busid
        $this.VendorProductID = $vidpid
        $this.Description = $desc.Trim()
        $this.RawState = $state.Trim()
        $this.UpdateStatus()
        $this.DeviceType = $this.DetectDeviceType()
    }
    
    [void]UpdateStatus() {
        $this.IsAttached = $this.RawState -match "Attached"
        $this.IsShared = $this.RawState -match "Shared"
        $this.CanAttach = $this.IsShared -and -not $this.IsAttached
        
        $this.Status = switch -Regex ($this.RawState) {
            "Attached" { "🟢 Attached to WSL" }
            "Shared.*forced" { "🟡 Shared (Forced)" }
            "Shared" { "🟡 Shared (Ready)" }
            "Not shared" { "⚫ Not Shared" }
            default { "❓ Unknown" }
        }
    }
    
    [string]DetectDeviceType() {
        $vid = $this.VendorProductID.Split(':')[0].ToLower()
        $result = switch ($vid) {
            '0403' { "📡 FTDI Serial" }
            '10c4' { "📡 Silicon Labs Serial" }
            '1a86' { "📡 WCH Serial" }
            '067b' { "🖨️ Prolific Serial" }
            '2341' { "🤖 Arduino" }
            '1d50' { "🛠️ Development Board" }
            default { "🔌 USB Device" }
        }
        return $result
    }
    
    [string]GetDisplayText() {
        return "$($this.DeviceType) $($this.Description) [$($this.Status)]"
    }
}

class MenuSystem {
    [int]$SelectedIndex = 0
    [bool]$Running = $true
    [string]$Title
    [array]$Items
    [hashtable]$Actions = @{}
    
    MenuSystem([string]$title) {
        $this.Title = $title
    }
    
    [void]AddMenuItem([string]$text, [scriptblock]$action) {
        if (-not $this.Items) { $this.Items = @() }
        $this.Items += $text
        $this.Actions[$text] = $action
    }
    
    [void]Display() {
        Clear-Host
        $this.ShowHeader()
        $this.ShowItems()
        $this.ShowFooter()
    }
    
    [void]ShowHeader() {
        Write-Host ""
        Write-Host "  $($this.Title)" -ForegroundColor Cyan -BackgroundColor DarkBlue
        Write-Host ("  " + "═" * $this.Title.Length) -ForegroundColor DarkCyan
        Write-Host ""
    }
    
    [void]ShowItems() {
        for ($i = 0; $i -lt $this.Items.Count; $i++) {
            $prefix = if ($i -eq $this.SelectedIndex) { "  ▶ " } else { "    " }
            $color = if ($i -eq $this.SelectedIndex) { "Yellow" } else { "White" }
            $bg = if ($i -eq $this.SelectedIndex) { "DarkBlue" } else { "Black" }
            
            Write-Host $prefix -NoNewline -ForegroundColor Green
            Write-Host $this.Items[$i] -ForegroundColor $color -BackgroundColor $bg
        }
    }
    
    [void]ShowFooter() {
        Write-Host ""
        Write-Host "  ↑↓ Navigate  " -NoNewline -ForegroundColor Gray
        Write-Host "Enter" -NoNewline -ForegroundColor Green
        Write-Host " Select  " -NoNewline -ForegroundColor Gray
        Write-Host "Q" -NoNewline -ForegroundColor Red
        Write-Host " Quit  " -NoNewline -ForegroundColor Gray
        Write-Host "Esc" -NoNewline -ForegroundColor Yellow
        Write-Host " Back" -ForegroundColor Gray
        Write-Host ""
    }
    
    [string]Show() {
        while ($this.Running) {
            $this.Display()
            $key = [Console]::ReadKey($true)
            
            switch ($key.Key) {
                'UpArrow' { 
                    $this.SelectedIndex = if ($this.SelectedIndex -eq 0) { $this.Items.Count - 1 } else { $this.SelectedIndex - 1 }
                }
                'DownArrow' { 
                    $this.SelectedIndex = if ($this.SelectedIndex -eq $this.Items.Count - 1) { 0 } else { $this.SelectedIndex + 1 }
                }
                'Enter' { 
                    $selectedItem = $this.Items[$this.SelectedIndex]
                    if ($this.Actions.ContainsKey($selectedItem)) {
                        $result = & $this.Actions[$selectedItem]
                        if ($result -eq 'EXIT') { return 'EXIT' }
                        if ($result -eq 'BACK') { return 'BACK' }
                    }
                    return $selectedItem
                }
                'Q' { return 'EXIT' }
                'Escape' { return 'BACK' }
            }
        }
        return 'EXIT'
    }
}
#endregion

#region Core Functions
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║        🔌 USB Manager v2.0           ║" -ForegroundColor Cyan
    Write-Host "  ║      Modern WSL Device Control       ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    if (Test-Administrator) {
        Write-Host "  ✅ Administrator privileges detected" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Not running as Administrator - limited functionality" -ForegroundColor Yellow
    }
    Write-Host ""
}

function Get-USBDevices {
    [OutputType([USBDevice[]])]
    param()
    
    try {
        $output = usbipd list 2>&1
        $devices = @()
        $inConnectedSection = $false
        
        foreach ($line in $output) {
            if ($line -match "Connected:") { 
                $inConnectedSection = $true
                continue 
            }
            if ($line -match "Persisted:") { 
                $inConnectedSection = $false
                continue 
            }
            
            if ($inConnectedSection -and $line -match '^\s*([\d-]+)\s+([\da-fA-F:]+)\s+(.*?)\s+((?:Not shared|Shared|Attached).*?)$') {
                $devices += [USBDevice]::new($matches[1], $matches[2], $matches[3], $matches[4])
            }
        }
        
        return $devices | Sort-Object { $_.IsAttached }, { $_.IsShared }, Description
    }
    catch {
        Write-Warning "Failed to enumerate USB devices: $($_.Exception.Message)"
        return @()
    }
}

function Show-DeviceStatus {
    param([USBDevice[]]$Devices)
    
    if (-not $Devices -or $Devices.Count -eq 0) {
        Write-Host "  📭 No USB devices found" -ForegroundColor Yellow
        Write-Host "     Make sure USB devices are connected and usbipd is installed" -ForegroundColor Gray
        return
    }
    
    Write-Host "  📋 Device Summary:" -ForegroundColor Cyan
    Write-Host ""
    
    $attached = $Devices | Where-Object IsAttached
    $shared = $Devices | Where-Object { $_.IsShared -and -not $_.IsAttached }
    $unshared = $Devices | Where-Object { -not $_.IsShared }
    
    Write-Host "     🟢 Attached to WSL: $($attached.Count)" -ForegroundColor Green
    Write-Host "     🟡 Shared (Ready):  $($shared.Count)" -ForegroundColor Yellow  
    Write-Host "     ⚫ Not Shared:      $($unshared.Count)" -ForegroundColor Gray
    Write-Host ""
}

function Invoke-AttachDevice {
    param([USBDevice]$Device)
    
    if (-not $Device.CanAttach) {
        Show-Message "❌ Cannot attach device" "Device must be shared first" "Error"
        return $false
    }
    
    Show-ProgressMessage "🔗 Attaching device to WSL..."
    
    try {
        $result = usbipd attach --busid $Device.BusID 2>&1
        if ($LASTEXITCODE -eq 0) {
            Show-Message "✅ Device attached successfully" "$($Device.Description) is now available in WSL" "Success"
            return $true
        } else {
            Show-Message "❌ Attachment failed" $result "Error"
            return $false
        }
    }
    catch {
        Show-Message "❌ Attachment error" $_.Exception.Message "Error"
        return $false
    }
}

function Invoke-DetachDevice {
    param([USBDevice]$Device)
    
    if (-not $Device.IsAttached) {
        Show-Message "ℹ️ Device not attached" "Device is already detached from WSL" "Info"
        return $true
    }
    
    Show-ProgressMessage "🔌 Detaching device from WSL..."
    
    try {
        $result = usbipd detach --busid $Device.BusID 2>&1
        if ($LASTEXITCODE -eq 0) {
            Show-Message "✅ Device detached successfully" "$($Device.Description) is no longer in WSL" "Success"
            return $true
        } else {
            Show-Message "❌ Detachment failed" $result "Error"
            return $false
        }
    }
    catch {
        Show-Message "❌ Detachment error" $_.Exception.Message "Error"
        return $false
    }
}

function Invoke-ShareDevice {
    param([USBDevice]$Device)
    
    if ($Device.IsShared) {
        Show-Message "ℹ️ Already shared" "Device is already shared" "Info"
        return $true
    }
    
    if (-not (Test-Administrator)) {
        Show-Message "❌ Administrator required" "Sharing devices requires administrator privileges" "Error"
        return $false
    }
    
    Show-ProgressMessage "🔄 Sharing device..."
    
    try {
        $result = usbipd bind --busid $Device.BusID 2>&1
        if ($LASTEXITCODE -eq 0) {
            Show-Message "✅ Device shared successfully" "$($Device.Description) is now available for WSL attachment" "Success"
            return $true
        } else {
            Show-Message "❌ Sharing failed" $result "Error"
            return $false
        }
    }
    catch {
        Show-Message "❌ Sharing error" $_.Exception.Message "Error"
        return $false
    }
}

function Test-WSLConnection {
    Show-ProgressMessage "🔍 Testing WSL connection..."
    
    try {
        $result = wsl.exe --status 2>&1
        if ($LASTEXITCODE -eq 0) {
            return $true
        } else {
            Show-Message "❌ WSL not available" "Windows Subsystem for Linux is not running or installed" "Error"
            return $false
        }
    }
    catch {
        Show-Message "❌ WSL connection failed" $_.Exception.Message "Error"
        return $false
    }
}

function Invoke-LinuxSetup {
    param([USBDevice]$Device)
    
    if (-not $Device.IsAttached) {
        Show-Message "❌ Device not attached" "Device must be attached to WSL before Linux setup" "Error"
        return $false
    }
    
    if (-not (Test-WSLConnection)) {
        return $false
    }
    
    $menu = [MenuSystem]::new("Linux Device Setup - $($Device.Description)")
    $menu.AddMenuItem("🚀 Quick Setup (Recommended)", { 
        Invoke-QuickLinuxSetup $Device
        Read-Host "`n  Press Enter to continue"
        return 'BACK'
    })
    $menu.AddMenuItem("🔧 Advanced Setup", { 
        Invoke-AdvancedLinuxSetup $Device
        Read-Host "`n  Press Enter to continue"
        return 'BACK'
    })
    $menu.AddMenuItem("📋 Show Device Info", { 
        Show-LinuxDeviceInfo $Device
        Read-Host "`n  Press Enter to continue"
        return 'BACK'
    })
    $menu.AddMenuItem("🔙 Back to Device Menu", { return 'BACK' })
    
    $result = $menu.Show()
    return $result -eq 'BACK'
}

function Invoke-QuickLinuxSetup {
    param([USBDevice]$Device)
    
    Show-ProgressBanner "🚀 Quick Linux Setup" $Device.Description
    
    # Step 1: Load drivers
    Show-Step 1 "Loading USB serial drivers"
    $drivers = Get-DriversForDevice $Device
    foreach ($driver in $drivers) {
        Show-SubStep "Loading $driver"
        $result = wsl.exe bash -c "sudo modprobe $driver 2>/dev/null || echo 'already loaded'"
    }
    Start-Sleep 1
    
    # Step 2: User groups
    Show-Step 2 "Configuring user permissions"
    Show-SubStep "Adding user to dialout group"
    wsl.exe bash -c "sudo usermod -a -G dialout `$USER 2>/dev/null || true"
    Start-Sleep 1
    
    # Step 3: Find and configure device
    Show-Step 3 "Configuring device permissions"
    $devicePath = Find-LinuxDeviceNode
    if ($devicePath) {
        Show-SubStep "Setting permissions on $devicePath"
        wsl.exe bash -c "sudo chmod 666 '$devicePath' 2>/dev/null || true"
        Start-Sleep 1
        
        # Step 4: Verify
        Show-Step 4 "Verifying setup"
        Show-SubStep "Testing device access"
        $testResult = wsl.exe bash -c "ls -la '$devicePath' 2>/dev/null || echo 'not found'"
        Write-Host "     📄 $testResult" -ForegroundColor Gray
    } else {
        Show-SubStep "⚠️ Device node not found - may appear after reconnection"
    }
    
    Write-Host ""
    Write-Host "  ✅ Quick setup completed!" -ForegroundColor Green
    Write-Host "     Your device should now be accessible in WSL" -ForegroundColor Gray
}

function Find-LinuxDeviceNode {
    $searchScript = @"
# Look in dmesg first
DEVICE=`$(dmesg | grep -i "now attached to tty" | tail -n 1 | sed -n 's/.*attached to //p' 2>/dev/null)
if [ -n "`$DEVICE" ]; then
    echo "/dev/`$DEVICE"
    exit 0
fi

# Look for USB serial devices
for dev in /dev/ttyUSB* /dev/ttyACM* 2>/dev/null; do
    if [ -e "`$dev" ]; then
        echo "`$dev"
        exit 0
    fi
done

echo ""
"@
    
    $result = wsl.exe bash -c $searchScript 2>/dev/null
    return if ($result -and $result.Trim()) { $result.Trim() } else { $null }
}

function Get-DriversForDevice {
    param([USBDevice]$Device)
    
    $vid = $Device.VendorProductID.Split(':')[0].ToLower()
    $result = switch ($vid) {
        '0403' { @('ftdi_sio') }
        '10c4' { @('cp210x') }  
        '1a86' { @('ch341') }
        '067b' { @('pl2303') }
        default { @('usbserial', 'ftdi_sio', 'cp210x') }
    }
    return $result
}

function Show-LinuxDeviceInfo {
    param([USBDevice]$Device)
    
    Clear-Host
    Write-Host ""
    Write-Host "  📋 Linux Device Information" -ForegroundColor Cyan
    Write-Host "  ═══════════════════════════" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  Device: $($Device.Description)" -ForegroundColor Yellow
    Write-Host "  VID:PID: $($Device.VendorProductID)" -ForegroundColor Gray
    Write-Host ""
    
    Show-ProgressMessage "🔍 Gathering Linux information..."
    
    Write-Host "  📄 Recent kernel messages:" -ForegroundColor Cyan
    $dmesg = wsl.exe bash -c "dmesg | grep -iE 'usb|serial|tty' | tail -5 2>/dev/null || echo 'No recent messages'"
    $dmesg -split "`n" | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
    
    Write-Host ""
    Write-Host "  🔌 Available serial devices:" -ForegroundColor Cyan
    $devices = wsl.exe bash -c "ls -la /dev/tty{USB,ACM}* 2>/dev/null || echo 'No serial devices found'"
    $devices -split "`n" | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
    
    Write-Host ""
    Write-Host "  👥 User group membership:" -ForegroundColor Cyan
    $groups = wsl.exe bash -c "groups `$USER 2>/dev/null || echo 'Cannot check groups'"
    Write-Host "     $groups" -ForegroundColor Gray
    
    Write-Host ""
}

function Show-Message {
    param([string]$Title, [string]$Message, [string]$Type = "Info")
    
    Clear-Host
    Write-Host ""
    
    $color = switch ($Type) {
        "Success" { "Green" }
        "Error" { "Red" }
        "Warning" { "Yellow" }
        default { "Cyan" }
    }
    
    Write-Host "  $Title" -ForegroundColor $color
    Write-Host "  $("─" * $Title.Length)" -ForegroundColor DarkGray
    Write-Host ""
    
    if ($Message) {
        $Message -split "`n" | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    Write-Host "  Press Enter to continue..." -ForegroundColor DarkGray
    Read-Host | Out-Null
}

function Show-ProgressMessage {
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor Yellow
}

function Show-ProgressBanner {
    param([string]$Title, [string]$Subtitle)
    Clear-Host
    Write-Host ""
    Write-Host "  $Title" -ForegroundColor Cyan -BackgroundColor DarkBlue
    Write-Host "  $("═" * $Title.Length)" -ForegroundColor DarkCyan
    if ($Subtitle) {
        Write-Host "  $Subtitle" -ForegroundColor Gray
    }
    Write-Host ""
}

function Show-Step {
    param([int]$Number, [string]$Description)
    Write-Host ""
    Write-Host "  [$Number/4] $Description" -ForegroundColor Cyan
}

function Show-SubStep {
    param([string]$Description)
    Write-Host "     • $Description" -ForegroundColor Gray
}
#endregion

#region Main Application
function Start-DeviceManager {
    Show-Banner
    Start-Sleep 1
    
    while ($true) {
        try {
            $devices = Get-USBDevices
            
            if (-not $devices -or $devices.Count -eq 0) {
                $menu = [MenuSystem]::new("🔌 USB Manager - No Devices Found")
                $menu.AddMenuItem("🔄 Refresh Device List", { return 'REFRESH' })
                $menu.AddMenuItem("❌ Exit", { return 'EXIT' })
                
                $result = $menu.Show()
                if ($result -eq 'EXIT') { break }
                continue
            }
            
            Show-DeviceStatus $devices
            
            $menu = [MenuSystem]::new("🔌 USB Device Manager - Select Device")
            
            foreach ($device in $devices) {
                $menu.AddMenuItem($device.GetDisplayText(), {
                    param($selectedDevice)
                    return Show-DeviceMenu $selectedDevice
                }.GetNewClosure())
            }
            
            $menu.AddMenuItem("🔄 Refresh Device List", { return 'REFRESH' })
            $menu.AddMenuItem("❌ Exit Application", { return 'EXIT' })
            
            # Store devices for action callbacks
            $script:CurrentDevices = $devices
            
            $result = $menu.Show()
            
            if ($result -eq 'EXIT') {
                break
            } elseif ($result -eq 'REFRESH') {
                continue
            } else {
                # Find selected device
                $selectedDevice = $devices | Where-Object { $_.GetDisplayText() -eq $result }
                if ($selectedDevice) {
                    Show-DeviceMenu $selectedDevice
                }
            }
        }
        catch {
            Show-Message "❌ Application Error" $_.Exception.Message "Error"
        }
    }
    
    Clear-Host
    Write-Host ""
    Write-Host "  👋 Thanks for using USB Manager v2.0!" -ForegroundColor Green
    Write-Host ""
}

function Show-DeviceMenu {
    param([USBDevice]$Device)
    
    while ($true) {
        $menu = [MenuSystem]::new("Device Actions - $($Device.Description)")
        
        # Dynamic menu based on device state
        if ($Device.IsAttached) {
            $menu.AddMenuItem("🔌 Detach from WSL", { 
                Invoke-DetachDevice $Device
                $Device.UpdateStatus()
                return 'CONTINUE'
            })
            $menu.AddMenuItem("🛠️ Configure for Linux", { 
                Invoke-LinuxSetup $Device
                return 'CONTINUE'
            })
        } elseif ($Device.CanAttach) {
            $menu.AddMenuItem("🔗 Attach to WSL", { 
                if (Invoke-AttachDevice $Device) {
                    $Device.UpdateStatus()
                }
                return 'CONTINUE'
            })
        } else {
            $menu.AddMenuItem("📤 Share Device", { 
                if (Invoke-ShareDevice $Device) {
                    $Device.UpdateStatus()
                }
                return 'CONTINUE'
            })
        }
        
        $menu.AddMenuItem("ℹ️ Device Information", { 
            Show-DeviceInfo $Device
            return 'CONTINUE'
        })
        $menu.AddMenuItem("🔙 Back to Device List", { return 'BACK' })
        
        $result = $menu.Show()
        if ($result -eq 'BACK') {
            break
        }
    }
}

function Show-DeviceInfo {
    param([USBDevice]$Device)
    
    Clear-Host
    Write-Host ""
    Write-Host "  📋 Device Information" -ForegroundColor Cyan
    Write-Host "  ════════════════════" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  Name:        $($Device.Description)" -ForegroundColor White
    Write-Host "  Type:        $($Device.DeviceType)" -ForegroundColor Gray
    Write-Host "  Bus ID:      $($Device.BusID)" -ForegroundColor Gray
    Write-Host "  VID:PID:     $($Device.VendorProductID)" -ForegroundColor Gray
    Write-Host "  Status:      $($Device.Status)" -ForegroundColor Gray
    Write-Host "  Raw State:   $($Device.RawState)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Capabilities:" -ForegroundColor Cyan
    Write-Host "    Can Attach:   $($Device.CanAttach)" -ForegroundColor Gray
    Write-Host "    Is Shared:    $($Device.IsShared)" -ForegroundColor Gray
    Write-Host "    Is Attached:  $($Device.IsAttached)" -ForegroundColor Gray
    Write-Host ""
    
    if ($Device.IsAttached) {
        Show-LinuxDeviceInfo $Device
    }
    
    Write-Host "  Press Enter to continue..." -ForegroundColor DarkGray
    Read-Host | Out-Null
}

# Advanced setup function (placeholder for future expansion)
function Invoke-AdvancedLinuxSetup {
    param([USBDevice]$Device)
    
    Show-Message "🔧 Advanced Setup" "Advanced setup options coming soon!`n`nFor now, please use Quick Setup." "Info"
}
#endregion

# Application Entry Point
if ($MyInvocation.InvocationName -ne '.') {
    Start-DeviceManager
}
