# Port Standardization Deployment Guide

## Objective
Change all 100 student systems from their current custom ports to the standard port **8765**.

## Overview
You need to update the `config.json` file on each student PC and restart the screen capture agent.

---

## Method 1: Automated Deployment Script (Recommended)

### Step 1: Create Deployment Script

Save this as `deploy_port_change.bat`:

```batch
@echo off
REM ========================================
REM Port Standardization Script
REM Changes screen capture agent port to 8765
REM ========================================

echo.
echo ========================================
echo Screen Capture Agent - Port Update
echo Changing port to 8765
echo ========================================
echo.

REM Define paths
set AGENT_DIR=C:\LabAssistant\ScreenCaptureAgent
set CONFIG_FILE=%AGENT_DIR%\config.json
set AGENT_EXE=ScreenCaptureAgent.exe

REM Check if agent directory exists
if not exist "%AGENT_DIR%" (
    echo ERROR: Agent directory not found: %AGENT_DIR%
    echo Please install the screen capture agent first.
    pause
    exit /b 1
)

echo [1/4] Stopping existing agent...
taskkill /F /IM %AGENT_EXE% >nul 2>&1
if %errorLevel% equ 0 (
    echo Agent stopped successfully
) else (
    echo Agent was not running
)
timeout /t 2 /nobreak >nul

echo.
echo [2/4] Updating config.json to port 8765...
echo {"port": 8765} > "%CONFIG_FILE%"
if exist "%CONFIG_FILE%" (
    echo Config updated successfully
    type "%CONFIG_FILE%"
) else (
    echo ERROR: Failed to create config file
    pause
    exit /b 1
)

echo.
echo [3/4] Updating Windows Firewall...
REM Remove old firewall rule
netsh advfirewall firewall delete rule name="Lab Assistant Screen Capture" >nul 2>&1

REM Add new firewall rule for port 8765
netsh advfirewall firewall add rule name="Lab Assistant Screen Capture" dir=in action=allow protocol=TCP localport=8765 program="%AGENT_DIR%\%AGENT_EXE%" enable=yes >nul 2>&1
if %errorLevel% equ 0 (
    echo Firewall rule updated for port 8765
) else (
    echo WARNING: Failed to update firewall rule
    echo You may need to run this script as Administrator
)

echo.
echo [4/4] Starting agent with new port...
cd /d "%AGENT_DIR%"
start "" "%AGENT_EXE%"
timeout /t 3 /nobreak >nul

REM Verify agent is running
tasklist /FI "IMAGENAME eq %AGENT_EXE%" 2>NUL | find /I /N "%AGENT_EXE%">NUL
if %errorLevel% equ 0 (
    echo ✓ Agent started successfully on port 8765
) else (
    echo ✗ Agent may not have started - check manually
)

echo.
echo ========================================
echo Port Update Complete!
echo ========================================
echo.
echo Agent is now configured for port 8765
echo.
pause
```

### Step 2: Deploy to All Systems

#### Option A: Network Share Deployment
```batch
REM Copy script to network share
copy deploy_port_change.bat \\server\share\

REM Run on all student PCs using PsExec (from Sysinternals)
psexec \\student-pc-* -u Administrator -p YourPassword cmd /c "\\server\share\deploy_port_change.bat"
```

#### Option B: Group Policy Deployment
1. Copy `deploy_port_change.bat` to: `\\domain\SYSVOL\domain\scripts\`
2. Open Group Policy Management
3. Create new GPO: "Screen Capture Port Update"
4. Edit GPO → Computer Configuration → Policies → Windows Settings → Scripts → Startup
5. Add script: `\\domain\SYSVOL\domain\scripts\deploy_port_change.bat`
6. Link GPO to OU containing student computers
7. Run `gpupdate /force` on student PCs or wait for next reboot

#### Option C: Manual Deployment (Small Scale)
1. Copy `deploy_port_change.bat` to USB drive
2. Visit each student PC
3. Right-click script → Run as administrator
4. Wait for completion

---

## Method 2: PowerShell Remote Deployment

### Step 1: Create PowerShell Script

Save as `deploy_port_change.ps1`:

```powershell
# ========================================
# Screen Capture Agent - Port Update Script
# Changes port to 8765 on remote computers
# ========================================

param(
    [string[]]$ComputerNames = @(),
    [string]$ComputerListFile = "",
    [PSCredential]$Credential
)

# Configuration
$AgentDir = "C:\LabAssistant\ScreenCaptureAgent"
$ConfigFile = "$AgentDir\config.json"
$AgentExe = "ScreenCaptureAgent.exe"
$NewPort = 8765

# Get list of computers
$computers = @()
if ($ComputerListFile -and (Test-Path $ComputerListFile)) {
    $computers = Get-Content $ComputerListFile
} elseif ($ComputerNames.Count -gt 0) {
    $computers = $ComputerNames
} else {
    Write-Host "ERROR: No computers specified" -ForegroundColor Red
    Write-Host "Usage: .\deploy_port_change.ps1 -ComputerListFile computers.txt"
    Write-Host "   or: .\deploy_port_change.ps1 -ComputerNames PC1,PC2,PC3"
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Screen Capture Port Update Deployment" -ForegroundColor Cyan
Write-Host "Target Port: $NewPort" -ForegroundColor Cyan
Write-Host "Total Computers: $($computers.Count)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$successCount = 0
$failCount = 0
$results = @()

foreach ($computer in $computers) {
    Write-Host "Processing: $computer" -ForegroundColor Yellow
    
    try {
        # Test connection
        if (-not (Test-Connection -ComputerName $computer -Count 1 -Quiet)) {
            throw "Computer is offline or unreachable"
        }
        
        # Execute remote commands
        $scriptBlock = {
            param($AgentDir, $ConfigFile, $AgentExe, $NewPort)
            
            # Stop agent
            Stop-Process -Name $AgentExe -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            
            # Update config
            $config = @{port = $NewPort} | ConvertTo-Json
            Set-Content -Path $ConfigFile -Value $config -Force
            
            # Update firewall
            Remove-NetFirewallRule -DisplayName "Lab Assistant Screen Capture" -ErrorAction SilentlyContinue
            New-NetFirewallRule -DisplayName "Lab Assistant Screen Capture" `
                -Direction Inbound -Protocol TCP -LocalPort $NewPort `
                -Action Allow -Program "$AgentDir\$AgentExe" -Enabled True | Out-Null
            
            # Start agent
            Start-Process -FilePath "$AgentDir\$AgentExe" -WorkingDirectory $AgentDir
            Start-Sleep -Seconds 2
            
            # Verify
            $running = Get-Process -Name ($AgentExe -replace '\.exe$') -ErrorAction SilentlyContinue
            return $running -ne $null
        }
        
        $params = @{
            ComputerName = $computer
            ScriptBlock = $scriptBlock
            ArgumentList = $AgentDir, $ConfigFile, $AgentExe, $NewPort
        }
        
        if ($Credential) {
            $params.Credential = $Credential
        }
        
        $result = Invoke-Command @params
        
        if ($result) {
            Write-Host "  ✓ SUCCESS" -ForegroundColor Green
            $successCount++
            $results += [PSCustomObject]@{
                Computer = $computer
                Status = "Success"
                Message = "Port updated to $NewPort"
            }
        } else {
            Write-Host "  ✗ FAILED - Agent not running" -ForegroundColor Red
            $failCount++
            $results += [PSCustomObject]@{
                Computer = $computer
                Status = "Failed"
                Message = "Agent did not start"
            }
        }
        
    } catch {
        Write-Host "  ✗ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $failCount++
        $results += [PSCustomObject]@{
            Computer = $computer
            Status = "Error"
            Message = $_.Exception.Message
        }
    }
    
    Write-Host ""
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Computers: $($computers.Count)" -ForegroundColor White
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor Red
Write-Host ""

# Export results
$reportFile = "port_update_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$results | Export-Csv -Path $reportFile -NoTypeInformation
Write-Host "Detailed report saved to: $reportFile" -ForegroundColor Cyan
Write-Host ""

# Show failed computers
if ($failCount -gt 0) {
    Write-Host "Failed Computers:" -ForegroundColor Red
    $results | Where-Object {$_.Status -ne "Success"} | Format-Table -AutoSize
}
```

### Step 2: Create Computer List

Create `computers.txt` with one computer name per line:
```
STUDENT-PC-001
STUDENT-PC-002
STUDENT-PC-003
...
STUDENT-PC-100
```

### Step 3: Run Deployment

```powershell
# Run as Administrator
.\deploy_port_change.ps1 -ComputerListFile computers.txt

# Or with credentials
$cred = Get-Credential
.\deploy_port_change.ps1 -ComputerListFile computers.txt -Credential $cred
```

---

## Method 3: Manual Update (Individual PCs)

If you need to update PCs manually:

### On Each Student PC:

1. **Stop the agent:**
   ```cmd
   taskkill /F /IM ScreenCaptureAgent.exe
   ```

2. **Edit config.json:**
   - Location: `C:\LabAssistant\ScreenCaptureAgent\config.json`
   - Change to: `{"port": 8765}`

3. **Update firewall:**
   ```cmd
   netsh advfirewall firewall delete rule name="Lab Assistant Screen Capture"
   netsh advfirewall firewall add rule name="Lab Assistant Screen Capture" dir=in action=allow protocol=TCP localport=8765 program="C:\LabAssistant\ScreenCaptureAgent\ScreenCaptureAgent.exe"
   ```

4. **Restart agent:**
   ```cmd
   cd C:\LabAssistant\ScreenCaptureAgent
   start ScreenCaptureAgent.exe
   ```

---

## Verification

### On Student PC:
```cmd
REM Check config
type C:\LabAssistant\ScreenCaptureAgent\config.json

REM Check if agent is running
tasklist | findstr ScreenCaptureAgent

REM Check port is listening
netstat -ano | findstr :8765
```

Expected output:
```
{"port": 8765}
ScreenCaptureAgent.exe    1234 Console    1     15,234 K
TCP    0.0.0.0:8765    0.0.0.0:0    LISTENING    1234
```

### From Admin PC:
```powershell
Test-NetConnection -ComputerName 172.17.13.123 -Port 8765
```

Should show: `TcpTestSucceeded : True`

---

## Database Update

After changing ports, update the database to remove old IP:PORT entries:

```sql
-- Connect to PostgreSQL
psql -U postgres -d labassistant

-- View current IP addresses
SELECT name, enroll_number, ip_address FROM users WHERE role = 'student';

-- Remove port numbers from IP addresses (if stored as IP:PORT)
UPDATE users 
SET ip_address = SPLIT_PART(ip_address, ':', 1)
WHERE role = 'student' AND ip_address LIKE '%:%';

-- Verify
SELECT name, enroll_number, ip_address FROM users WHERE role = 'student';
```

The Flutter app will now use the default port 8765 for all connections.

---

## Troubleshooting

### Issue: Script fails with "Access Denied"
**Solution:** Run as Administrator or use domain admin credentials

### Issue: Firewall rule not created
**Solution:** 
```cmd
REM Run as Administrator
netsh advfirewall firewall add rule name="Lab Assistant Screen Capture" dir=in action=allow protocol=TCP localport=8765 program="C:\LabAssistant\ScreenCaptureAgent\ScreenCaptureAgent.exe"
```

### Issue: Agent doesn't start
**Solution:**
- Check if .NET 6.0 Runtime is installed
- Run agent manually to see error message
- Check Windows Event Viewer for errors

### Issue: Port still shows old number
**Solution:**
- Verify config.json was updated
- Restart the agent
- Check for multiple agent instances running

---

## Quick Reference

### Files to Update on Each PC:
- `C:\LabAssistant\ScreenCaptureAgent\config.json`

### Commands to Run:
```batch
taskkill /F /IM ScreenCaptureAgent.exe
echo {"port": 8765} > C:\LabAssistant\ScreenCaptureAgent\config.json
netsh advfirewall firewall delete rule name="Lab Assistant Screen Capture"
netsh advfirewall firewall add rule name="Lab Assistant Screen Capture" dir=in action=allow protocol=TCP localport=8765 program="C:\LabAssistant\ScreenCaptureAgent\ScreenCaptureAgent.exe"
cd C:\LabAssistant\ScreenCaptureAgent
start ScreenCaptureAgent.exe
```

### Verification:
```cmd
type C:\LabAssistant\ScreenCaptureAgent\config.json
tasklist | findstr ScreenCaptureAgent
netstat -ano | findstr :8765
```

---

## Summary

1. **Choose deployment method** based on your infrastructure
2. **Test on 1-2 PCs** first
3. **Deploy to all 100 systems**
4. **Verify** each system is on port 8765
5. **Update database** to remove old port numbers
6. **Test** admin monitoring connections

After deployment, all systems will use port **8765** as the standard.
