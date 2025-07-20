# Test script syntax
try {
    Write-Host "Testing syntax of easy-usb-manager-fixed.ps1..." -ForegroundColor Cyan
    [System.Management.Automation.Language.Parser]::ParseFile('C:\Users\lpgn\Scripts\easy-usb-manager-fixed.ps1', [ref]$null, [ref]$null) | Out-Null
    Write-Host "✅ Script syntax is valid!" -ForegroundColor Green
} catch {
    Write-Host "❌ Syntax error found:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Press any key to continue..."
$null = Read-Host
