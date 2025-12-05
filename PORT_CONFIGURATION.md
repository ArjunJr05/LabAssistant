# Port Configuration Guide for Lab Assistant

## Problem
Port 8765 may be blocked or unavailable on some systems due to:
- Windows Firewall restrictions
- Corporate network policies
- Port already in use by another application
- Network configuration issues

## Solution

### For the Screen Capture Agent (Client PCs)

The agent now supports **3 ways** to configure a custom port:

#### 1. Command Line (Quick Testing)
```cmd
ScreenCaptureAgent.exe --port 9000
```

#### 2. Configuration File (Recommended for Deployment)
Create `config.json` in the same directory as `ScreenCaptureAgent.exe`:
```json
{
  "port": 9000
}
```

#### 3. Rebuild with Different Default
Modify `DEFAULT_WEBSOCKET_PORT` in `Program.cs` and rebuild.

### For the Admin Interface (Flutter App)

The admin interface **already supports** custom ports. Simply enter the IP address with port:

**Format:** `IP:PORT`

**Examples:**
- `192.168.1.100:8765` (default port)
- `192.168.1.100:9000` (custom port)
- `10.0.0.50:8080` (another custom port)

### Firewall Configuration

**On each client PC**, add a firewall rule for the port:

```powershell
# Run as Administrator
New-NetFirewallRule -DisplayName "Lab Assistant Screen Capture" -Direction Inbound -Protocol TCP -LocalPort 9000 -Action Allow
```

Replace `9000` with your chosen port number.

## Quick Start Guide

### Scenario 1: Port 8765 is Blocked

**On Client PCs:**
1. Create `config.json` with custom port (e.g., 9000)
2. Add firewall rule for port 9000
3. Run `ScreenCaptureAgent.exe`

**On Admin PC:**
1. Open Lab Assistant → Admin Dashboard → Monitor Students
2. Enter student IP as: `192.168.1.100:9000`
3. Click Connect

### Scenario 2: Different Ports for Different Labs

**Lab 1 - Port 8765:**
- Client config.json: `{"port": 8765}`
- Admin enters: `192.168.1.100:8765`

**Lab 2 - Port 9000:**
- Client config.json: `{"port": 9000}`
- Admin enters: `192.168.2.100:9000`

**Lab 3 - Port 9001:**
- Client config.json: `{"port": 9001}`
- Admin enters: `192.168.3.100:9001`

## Troubleshooting

### Check if Port is Available
```cmd
netstat -ano | findstr :8765
```

If output shows the port is in use, either:
- Close the application using it
- Choose a different port

### Test Connectivity
From admin PC:
```powershell
Test-NetConnection -ComputerName 192.168.1.100 -Port 9000
```

### Verify Agent is Running
On client PC, the agent console should show:
```
=== Lab Assistant Screen Capture Agent ===
Using port: 9000
Local IP: 192.168.1.100
Screen Capture Agent started on port 9000
Waiting for admin connections...
```

## Deployment Script Example

For IT administrators deploying to multiple PCs:

```batch
@echo off
REM Deploy Screen Capture Agent with Custom Port

REM Set custom port
SET PORT=9000

REM Create directory
if not exist "C:\LabAssistant\ScreenCaptureAgent" mkdir "C:\LabAssistant\ScreenCaptureAgent"

REM Copy files
xcopy /Y /E "\\server\share\ScreenCaptureAgent\*" "C:\LabAssistant\ScreenCaptureAgent\"

REM Create config file
echo {"port": %PORT%} > "C:\LabAssistant\ScreenCaptureAgent\config.json"

REM Add firewall rule
powershell -Command "New-NetFirewallRule -DisplayName 'Lab Assistant Screen Capture' -Direction Inbound -Protocol TCP -LocalPort %PORT% -Action Allow -ErrorAction SilentlyContinue"

REM Start agent
cd "C:\LabAssistant\ScreenCaptureAgent"
start "" "ScreenCaptureAgent.exe"

echo Deployment complete! Agent running on port %PORT%
pause
```

## Summary

✅ **Agent**: Supports custom ports via command line or config.json  
✅ **Admin App**: Already supports IP:PORT format  
✅ **Firewall**: Add rules for custom ports  
✅ **Flexible**: Different ports for different labs/systems  

For detailed troubleshooting, see `screen_capture_agent/TROUBLESHOOTING.md`
