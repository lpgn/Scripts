# Project Information for USB Manager Scripts

## Build/Lint/Test Commands

### PowerShell Script Validation
```bash
# Check syntax of PowerShell scripts
pwsh -Command "Get-ChildItem *.ps1 | ForEach-Object { Write-Host \"Checking \$($_.Name)\"; [System.Management.Automation.Language.Parser]::ParseFile(\$_, [ref]\$null, [ref]\$null) | Out-Null; Write-Host \"✅ Syntax OK\" }"

# Run specific script syntax check
pwsh -Command "[System.Management.Automation.Language.Parser]::ParseFile('optimized-usb-manager.ps1', [ref]\$null, [ref]\$null) | Out-Null"
```

### Single Test Execution
```bash
# Test USB device listing function only
pwsh -Command "& ./optimized-usb-manager.ps1 -AutoAdmin"  # Runs in non-interactive mode
```

## Code Style Guidelines

### PowerShell Conventions
1. Use PascalCase for function names (e.g., `Get-USBDevices`)
2. Use camelCase for variables (e.g., `$selectedDevice`)
3. Use proper indentation (4 spaces)
4. Comment functions and complex logic
5. Use strongly typed parameters where possible
6. Error handling with try/catch blocks
7. Use Verbose/Debug preferences appropriately

### Script Structure
1. Parameter validation at start
2. Function definitions before main code
3. Clear separation of concerns
4. Modular design with reusable functions
5. Consistent error handling and user feedback
6. Color-coded output for better UX (Cyan=Info, Green=Success, Red=Error, Yellow=Warning)

### Naming Conventions
1. Verbs for actions (Get-, Invoke-, Show-)
2. Nouns for objects (Device, Menu, Action)
3. Boolean variables with Is/Can prefixes (IsAttached, CanAttach)
4. Arrays with plural names (Devices, Actions)

### Error Handling
1. All external commands should check `$LASTEXITCODE`
2. Use try/catch for error-prone operations
3. Provide meaningful error messages to users
4. Graceful degradation when possible

### Performance Considerations
1. Minimize calls to external programs
2. Cache results when appropriate
3. Use efficient filtering methods
4. Optimize loops and iterations

### UX Principles
1. Clear, actionable messages
2. Color-coded feedback
3. Simple keyboard navigation
4. Progress indication for long operations
5. Helpful error recovery suggestions

## Git Ignore
Add this to .gitignore:
```
*.db
*.db-shm
*.db-wal
.crush/
```