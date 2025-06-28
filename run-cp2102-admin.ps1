# Auto-elevate and run Simple USB Manager
# This script will automatically request administrator privileges and keep window open

$scriptPath = Join-Path $PSScriptRoot "simple-usb-manager.ps1"

# Check if the target script exists
if (-not (Test-Path $scriptPath)) {
    Write-Host "Error: simple-usb-manager.ps1 not found!" -ForegroundColor Red
    Write-Host "Expected location: $scriptPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Available scripts in this directory:" -ForegroundColor Cyan
    Get-ChildItem -Path $PSScriptRoot -Filter "*.ps1" | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor White }
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host "USB Device Manager for WSL" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
Write-Host ""

if (-not $isAdmin) {
    Write-Host "⚠️  Administrator privileges required!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This script needs Administrator rights to manage USB devices." -ForegroundColor White
    Write-Host "Opening elevated PowerShell window..." -ForegroundColor Yellow
    Write-Host ""
    
    try {
        # Re-run with elevated privileges but don't wait - let it run independently
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        $process = Start-Process PowerShell -Verb RunAs -ArgumentList $arguments -PassThru
        
        Write-Host "✅ Elevated PowerShell window opened!" -ForegroundColor Green
        Write-Host "Check the new window for the USB Manager interface." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "If no window appeared, you may have declined the UAC prompt." -ForegroundColor Yellow
        Write-Host "Run this script again and accept the Administrator request." -ForegroundColor Yellow
    }
    catch {
        Write-Host "❌ Failed to elevate privileges: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Try running PowerShell as Administrator manually:" -ForegroundColor Yellow
        Write-Host "1. Right-click PowerShell" -ForegroundColor White
        Write-Host "2. Select 'Run as Administrator'" -ForegroundColor White
        Write-Host "3. Navigate to: $PSScriptRoot" -ForegroundColor White
        Write-Host "4. Run: .\simple-usb-manager.ps1" -ForegroundColor White
    }
    
    Write-Host ""
    Read-Host "Press Enter to exit"
} else {
    # Already running as admin, execute the USB manager
    Write-Host "✅ Running with Administrator privileges" -ForegroundColor Green
    Write-Host "Starting USB Manager..." -ForegroundColor Cyan
    Write-Host ""
    
    try {
        & $scriptPath
    }
    catch {
        Write-Host "❌ Error running USB Manager: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Read-Host "Press Enter to exit"
    }
}
