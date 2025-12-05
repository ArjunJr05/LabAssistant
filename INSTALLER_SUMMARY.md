# LabAssistant Installer - Updated for v1.0.4

## ✅ Installer Status: READY TO BUILD

The Inno Setup script (`LabAssistant_Setup.iss`) has been updated with all recent features and improvements.

## What's Updated

### 1. **Version Number**
- Updated to **v1.0.4**
- Reflects all new features

### 2. **Screen Capture Agent**
- ✅ Includes built executable from: `bin\Release\net6.0-windows\win-x64\publish\ScreenCaptureAgent.exe`
- ✅ Includes documentation (*.md files)
- ✅ Includes INSTALL.bat for manual setup
- ✅ Creates config.json with default port 8765
- ✅ Configures Windows Firewall automatically

### 3. **Documentation Files**
- ✅ AUTO_LAUNCH_SETUP.md
- ✅ ADMIN_LOGOUT_FEATURE.md
- ✅ PORT_CONFIGURATION.md
- ✅ README.md
- ✅ Screen capture agent docs

### 4. **Installation Actions**
- ✅ Installs Flutter app
- ✅ Installs Node.js backend
- ✅ Installs MinGW compiler
- ✅ Installs screen capture agent
- ✅ Runs `npm install` for backend
- ✅ Adds firewall rule for port 8765
- ✅ Adds MinGW to system PATH
- ✅ Creates config.json for agent

### 5. **Welcome Message**
Updated to include:
- .NET 6.0 Runtime requirement
- New features list:
  - Auto-launch Screen Capture Agent
  - Admin logout broadcasts
  - Real-time screen monitoring
  - Custom port configuration

## Build Requirements

Before building the installer, ensure:

1. **Flutter app is built:**
   ```cmd
   flutter build windows --release
   ```

2. **Screen capture agent is built:**
   ```cmd
   cd screen_capture_agent
   dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
   ```

3. **All files exist:**
   - `build\windows\x64\runner\Release\labassistant.exe`
   - `screen_capture_agent\bin\Release\net6.0-windows\win-x64\publish\ScreenCaptureAgent.exe`
   - `backend\*` (all backend files)
   - `MinGW\*` (all MinGW files)
   - Documentation files

## Quick Build Command

```cmd
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" "C:\Users\user\LabAssistant\LabAssistant_Setup.iss"
```

**Output:** `installer_output\LabAssistant_Setup_v1.0.4.exe`

## What the Installer Does

### During Installation:
1. Copies Flutter app to `C:\Program Files\LabAssistant\`
2. Copies backend to `C:\Program Files\LabAssistant\backend\`
3. Copies MinGW to `C:\Program Files\LabAssistant\MinGW\`
4. Copies screen capture agent to `C:\Program Files\LabAssistant\screen_capture_agent\`
5. Runs `npm install` in backend folder
6. Adds firewall rule: `Lab Assistant Screen Capture` (port 8765)
7. Adds MinGW to system PATH
8. Creates `config.json` for screen capture agent
9. Creates desktop shortcut (optional)
10. Creates start menu entries

### Prerequisites Checked:
- Node.js (v14+)
- PostgreSQL (v12+)
- Warns if missing but allows installation to continue

## Key Features in v1.0.4

### 🚀 Auto-Launch Screen Capture Agent
- Automatically starts when student logs in
- Requests UAC elevation
- No manual startup needed

### 📡 Admin Logout Broadcast
- When admin logs out, all students are automatically logged out
- Uses Socket.IO for real-time communication
- Ensures clean session management

### 🔌 Custom Port Support
- Screen capture agent supports custom ports
- Configure via `config.json`
- Admin can connect using `IP:PORT` format

### 🛡️ Firewall Auto-Configuration
- Installer automatically adds firewall rule
- Port 8765 allowed by default
- Can be changed in config.json

## Installation Size

**Approximate sizes:**
- Flutter App: ~50MB
- Backend: ~5MB (before npm install)
- MinGW: ~100MB
- Screen Capture Agent: ~150MB (self-contained with .NET runtime)
- **Total Installer:** ~250-300MB

## Target System Requirements

### Minimum:
- Windows 10 (64-bit)
- 4GB RAM
- 1GB free disk space
- Node.js v14+
- PostgreSQL v12+

### Recommended:
- Windows 10/11 (64-bit)
- 8GB RAM
- 2GB free disk space
- Node.js v18+
- PostgreSQL v14+

## Testing Checklist

After building, test on a clean system:
- [ ] Install completes without errors
- [ ] Application launches
- [ ] Admin can log in
- [ ] Student can log in
- [ ] Screen capture agent auto-launches
- [ ] Admin can monitor student screen
- [ ] Admin logout triggers student logout
- [ ] Custom port configuration works
- [ ] Firewall rule is created
- [ ] MinGW is in PATH

## Known Limitations

1. **Requires Administrator privileges** for installation
2. **Screen capture agent** requires UAC approval on first run
3. **Backend npm install** requires internet connection during setup
4. **Large installer size** due to self-contained .NET runtime

## Troubleshooting

### If build fails:
1. Check all source files exist
2. Verify paths in .iss file are correct
3. Ensure Flutter and .NET builds are complete
4. Check Inno Setup version (6.0+)

### If installation fails:
1. Run as Administrator
2. Check Node.js is installed
3. Check PostgreSQL is installed
4. Verify internet connection (for npm install)
5. Check antivirus isn't blocking

## Next Steps

1. **Build Prerequisites:**
   ```cmd
   flutter build windows --release
   cd screen_capture_agent
   dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
   ```

2. **Build Installer:**
   ```cmd
   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" "C:\Users\user\LabAssistant\LabAssistant_Setup.iss"
   ```

3. **Test on Clean VM**

4. **Distribute**

## Summary

✅ **Installer script is complete and up-to-date**  
✅ **All new features included**  
✅ **Documentation included**  
✅ **Firewall auto-configuration**  
✅ **Ready to build**  

Just build the prerequisites (Flutter app and screen capture agent), then compile the installer!
