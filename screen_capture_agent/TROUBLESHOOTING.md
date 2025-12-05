# Screen Capture Agent Troubleshooting Guide

## Port 8765 Not Working on Other Systems

If the default port 8765 is blocked or not working on client machines, you have several options:

### Option 1: Use a Different Port via Command Line

Run the agent with a custom port:
```cmd
ScreenCaptureAgent.exe --port 9000
```

### Option 2: Use Configuration File

1. Create a `config.json` file in the same directory as `ScreenCaptureAgent.exe`:
```json
{
  "port": 9000
}
```

2. Run the agent normally:
```cmd
ScreenCaptureAgent.exe
```

The agent will automatically read the port from `config.json`.

### Option 3: Check Firewall Settings

The most common issue is Windows Firewall blocking the port. To fix:

1. **Open Windows Firewall with Advanced Security** (Run as Administrator)
2. Click **Inbound Rules** → **New Rule**
3. Select **Port** → Click **Next**
4. Select **TCP** and enter port number (e.g., 8765) → Click **Next**
5. Select **Allow the connection** → Click **Next**
6. Check all profiles (Domain, Private, Public) → Click **Next**
7. Name it "Lab Assistant Screen Capture" → Click **Finish**

**Quick PowerShell Command (Run as Administrator):**
```powershell
New-NetFirewallRule -DisplayName "Lab Assistant Screen Capture" -Direction Inbound -Protocol TCP -LocalPort 8765 -Action Allow
```

For custom port (e.g., 9000):
```powershell
New-NetFirewallRule -DisplayName "Lab Assistant Screen Capture" -Direction Inbound -Protocol TCP -LocalPort 9000 -Action Allow
```

### Option 4: Check if Port is Already in Use

To check if a port is already in use:
```cmd
netstat -ano | findstr :8765
```

If the port is in use, either:
- Close the application using that port
- Use a different port (see Options 1 or 2 above)

## Connecting from Admin Interface

When using a custom port on client machines, you need to specify it in the admin interface:

1. Open Lab Assistant → Admin Dashboard → Monitor Students
2. In the "Add Student IP" field, enter: `192.168.1.100:9000` (replace with actual IP and port)
3. Click "Connect"

**Note:** The Flutter app's `connectToClient` method already supports custom ports via the `port` parameter.

## Common Issues and Solutions

### Issue: "Cannot reach client at IP:8765"

**Solutions:**
1. Verify the agent is running on the client machine
2. Check Windows Firewall settings (see Option 3 above)
3. Ping the client machine to verify network connectivity
4. Try a different port if 8765 is blocked by corporate policy

### Issue: "Port already in use"

**Solutions:**
1. Find what's using the port: `netstat -ano | findstr :8765`
2. Close the conflicting application
3. Use a different port (Options 1 or 2 above)

### Issue: "Access Denied" when starting agent

**Solution:**
- Run `ScreenCaptureAgent.exe` as Administrator (required for screen capture API)

### Issue: Connection works locally but not from other machines

**Solutions:**
1. Check if Windows Firewall is blocking incoming connections
2. Verify both machines are on the same network
3. Check corporate firewall/network policies
4. Try disabling Windows Firewall temporarily to test

## Network Configuration for IT Administrators

### Recommended Ports
- **Default:** 8765 (can be changed)
- **Alternative:** 9000-9100 (if default is blocked)

### Group Policy Deployment

Create a startup script that:
1. Copies the agent to `C:\LabAssistant\ScreenCaptureAgent`
2. Creates `config.json` with appropriate port
3. Adds firewall rule
4. Starts the agent

**Example Startup Script (startup.bat):**
```batch
@echo off
REM Create directory
if not exist "C:\LabAssistant\ScreenCaptureAgent" mkdir "C:\LabAssistant\ScreenCaptureAgent"

REM Copy agent files
xcopy /Y /E "\\server\share\ScreenCaptureAgent\*" "C:\LabAssistant\ScreenCaptureAgent\"

REM Create config file with custom port
echo {"port": 9000} > "C:\LabAssistant\ScreenCaptureAgent\config.json"

REM Add firewall rule
powershell -Command "New-NetFirewallRule -DisplayName 'Lab Assistant Screen Capture' -Direction Inbound -Protocol TCP -LocalPort 9000 -Action Allow -ErrorAction SilentlyContinue"

REM Start agent
cd "C:\LabAssistant\ScreenCaptureAgent"
start "" "ScreenCaptureAgent.exe"
```

### Testing Connectivity

From the admin machine, test if you can reach a client:
```cmd
Test-NetConnection -ComputerName 192.168.1.100 -Port 8765
```

Or use telnet:
```cmd
telnet 192.168.1.100 8765
```

## Advanced Configuration

### Using Different Ports for Different Labs

You can deploy different configurations to different labs:

**Lab 1 (config.json):**
```json
{"port": 8765}
```

**Lab 2 (config.json):**
```json
{"port": 8766}
```

**Lab 3 (config.json):**
```json
{"port": 8767}
```

This allows you to segment monitoring by lab if needed.

### Monitoring Multiple Students with Different Ports

The admin interface supports connecting to clients on different ports:

```dart
// In your Flutter code
await screenMonitorService.connectToClient('192.168.1.100', port: 8765);
await screenMonitorService.connectToClient('192.168.1.101', port: 9000);
await screenMonitorService.connectToClient('192.168.1.102', port: 8766);
```

## Getting Help

If you continue to experience issues:

1. Check the agent console output for error messages
2. Verify network connectivity with `ping` and `Test-NetConnection`
3. Review Windows Event Viewer for firewall/security logs
4. Contact your network administrator about port restrictions

## Quick Checklist

- [ ] Agent running as Administrator
- [ ] Correct port configured (default 8765 or custom)
- [ ] Windows Firewall rule added for the port
- [ ] Network connectivity verified (ping works)
- [ ] Port not in use by another application
- [ ] Admin interface using correct IP:port combination
