# Auto-Launch Screen Capture Agent Setup Guide

## Overview
The Lab Assistant app now **automatically launches** the screen capture agent when a student logs in. This eliminates the need for manual agent startup.

## How It Works

### Automatic Launch Process
1. **Student logs in** to the Lab Assistant app
2. **App searches** for `ScreenCaptureAgent.exe` in standard locations
3. **Agent launches** automatically with administrator privileges
4. **UAC prompt** may appear (student must approve)
5. **Monitoring begins** - Admin can now view student's screen

### Search Locations
The app searches for the agent in these locations (in order):
1. `C:\LabAssistant\ScreenCaptureAgent\`
2. `C:\Program Files\LabAssistant\ScreenCaptureAgent\`
3. `C:\Program Files (x86)\LabAssistant\ScreenCaptureAgent\`
4. `%USERPROFILE%\LabAssistant\ScreenCaptureAgent\`
5. Same directory as the Flutter app
6. Parent directory of the Flutter app

## Installation Methods

### Method 1: Automated Installation (Recommended)

**On each student PC:**

1. Copy the `screen_capture_agent` folder to the student PC

2. **Run as Administrator:**
   ```cmd
   Right-click INSTALL.bat → Run as administrator
   ```

3. Follow the prompts:
   - Installs to `C:\LabAssistant\ScreenCaptureAgent\`
   - Configures Windows Firewall
   - Creates config.json with port 8765

4. **Done!** The agent will auto-launch when students log in.

### Method 2: Manual Installation

**On each student PC:**

1. Create directory:
   ```cmd
   mkdir C:\LabAssistant\ScreenCaptureAgent
   ```

2. Copy `ScreenCaptureAgent.exe` to the directory

3. Create `config.json`:
   ```json
   {"port": 8765}
   ```

4. Add firewall rule:
   ```powershell
   # Run as Administrator
   New-NetFirewallRule -DisplayName "Lab Assistant Screen Capture" -Direction Inbound -Protocol TCP -LocalPort 8765 -Action Allow -Program "C:\LabAssistant\ScreenCaptureAgent\ScreenCaptureAgent.exe"
   ```

### Method 3: Network Deployment (For IT Admins)

Create a deployment script for multiple PCs:

```batch
@echo off
REM Deploy to multiple student PCs

SET INSTALL_DIR=C:\LabAssistant\ScreenCaptureAgent
SET SOURCE=\\server\share\LabAssistant\ScreenCaptureAgent

REM Create directory
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

REM Copy files
xcopy /Y /E "%SOURCE%\*" "%INSTALL_DIR%\"

REM Configure firewall
netsh advfirewall firewall add rule name="Lab Assistant Screen Capture" dir=in action=allow protocol=TCP localport=8765 program="%INSTALL_DIR%\ScreenCaptureAgent.exe"

echo Deployment complete!
```

## UAC (User Account Control) Handling

### The UAC Prompt
When the agent auto-launches, Windows will show a UAC prompt:
```
Do you want to allow this app to make changes to your device?
ScreenCaptureAgent.exe
Publisher: Unknown Publisher
```

**Students must click "Yes"** to allow the agent to run.

### Options to Handle UAC

#### Option 1: Student Approval (Default)
- Student sees UAC prompt on first login
- Student clicks "Yes"
- Agent runs for that session

**Pros:** Secure, follows Windows security model  
**Cons:** Requires student interaction

#### Option 2: Disable UAC for Lab PCs (Not Recommended)
```cmd
REM Run as Administrator
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 0 /f
```

**Pros:** No prompts  
**Cons:** Security risk, not recommended

#### Option 3: Group Policy (For Domain-Joined PCs)
Configure Group Policy to auto-elevate the agent:
1. Open `gpedit.msc`
2. Navigate to: `Computer Configuration → Windows Settings → Security Settings → Application Control Policies → AppLocker`
3. Create rule to allow auto-elevation for `ScreenCaptureAgent.exe`

## Verification

### Check if Agent is Running
```cmd
tasklist | findstr ScreenCaptureAgent
```

Expected output:
```
ScreenCaptureAgent.exe    1234 Console    1     15,234 K
```

### Check if Port is Listening
```cmd
netstat -ano | findstr :8765
```

Expected output:
```
TCP    0.0.0.0:8765    0.0.0.0:0    LISTENING    1234
```

### View Agent Logs
Check the Flutter app console for:
```
🎬 AUTO-LAUNCHING SCREEN CAPTURE AGENT
👤 Student: John Doe
✅ Screen capture agent is running and ready for monitoring
```

## Troubleshooting

### Agent Not Found
**Symptom:** Console shows "Screen capture agent not found"

**Solution:**
1. Verify installation location:
   ```cmd
   dir C:\LabAssistant\ScreenCaptureAgent\ScreenCaptureAgent.exe
   ```

2. If not found, run `INSTALL.bat` as Administrator

### Agent Not Starting
**Symptom:** Console shows "Agent may require UAC approval"

**Solution:**
1. Student must approve UAC prompt
2. Check if agent is blocked by antivirus
3. Verify firewall rules

### Connection Timeout
**Symptom:** Admin sees "Connection timeout to 172.17.13.123:8765"

**Solution:**
1. Verify agent is running on student PC:
   ```cmd
   tasklist | findstr ScreenCaptureAgent
   ```

2. Check firewall:
   ```powershell
   Get-NetFirewallRule -DisplayName "Lab Assistant Screen Capture"
   ```

3. Test connectivity from admin PC:
   ```powershell
   Test-NetConnection -ComputerName 172.17.13.123 -Port 8765
   ```

### Custom Port Configuration
If port 8765 is blocked, use a custom port:

**On Student PC:**
1. Edit `C:\LabAssistant\ScreenCaptureAgent\config.json`:
   ```json
   {"port": 9000}
   ```

2. Update firewall rule:
   ```powershell
   netsh advfirewall firewall set rule name="Lab Assistant Screen Capture" new localport=9000
   ```

**On Admin PC:**
- Enter student IP as: `172.17.13.123:9000`

## Manual Start (Fallback)

If auto-launch fails, students can manually start the agent:

1. Navigate to: `C:\LabAssistant\ScreenCaptureAgent\`
2. Right-click `ScreenCaptureAgent.exe`
3. Select "Run as administrator"
4. Click "Yes" on UAC prompt

## Deployment Checklist

For each student PC:
- [ ] Install agent to `C:\LabAssistant\ScreenCaptureAgent\`
- [ ] Create `config.json` with correct port
- [ ] Add Windows Firewall rule
- [ ] Test agent manually first
- [ ] Verify auto-launch on student login
- [ ] Test admin connection from monitoring PC

## Security Notes

- Agent requires administrator privileges to capture screens
- Agent only accepts connections from local network
- No data is stored locally - only transmitted to admin
- Agent stops when student logs out
- All communication is over WebSocket (not encrypted by default)

## Benefits of Auto-Launch

✅ **No manual steps** - Students don't need to remember to start the agent  
✅ **Immediate monitoring** - Admin can monitor as soon as student logs in  
✅ **Consistent setup** - Same experience across all student PCs  
✅ **Reduced support** - Fewer "agent not running" issues  
✅ **Better compliance** - Harder for students to avoid monitoring  

## Summary

The auto-launch feature makes screen monitoring seamless:
1. Install agent once using `INSTALL.bat`
2. Student logs in → Agent starts automatically
3. Admin can monitor immediately

No manual intervention needed after initial setup!
