# LabAssistant Installer Build Checklist

## Pre-Build Requirements

### Software Required
- [ ] **Inno Setup 6** or later installed
- [ ] **Flutter SDK** installed
- [ ] **.NET 6.0 SDK** installed
- [ ] **Node.js** installed (for backend dependencies)
- [ ] **PostgreSQL** installed (for database)

## Build Steps

### 1. Build Flutter Application
```cmd
cd C:\Users\user\LabAssistant
flutter clean
flutter pub get
flutter build windows --release
```

**Verify:**
- [ ] Output at: `build\windows\x64\runner\Release\labassistant.exe`
- [ ] All DLL files present in Release folder
- [ ] data folder with flutter assets present

### 2. Build Screen Capture Agent
```cmd
cd C:\Users\user\LabAssistant\screen_capture_agent
dotnet clean
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true
```

**Verify:**
- [ ] Output at: `bin\Release\net6.0-windows\win-x64\publish\ScreenCaptureAgent.exe`
- [ ] File size approximately 150MB (self-contained)

### 3. Prepare Backend
```cmd
cd C:\Users\user\LabAssistant\backend
# Clean up development files
del /s /q node_modules
del /s /q *.log
```

**Verify:**
- [ ] No node_modules folder (will be installed on target)
- [ ] All .js files present
- [ ] package.json present
- [ ] .env.example present (if applicable)

### 4. Verify MinGW
```cmd
dir C:\Users\user\LabAssistant\MinGW\bin\gcc.exe
```

**Verify:**
- [ ] gcc.exe exists
- [ ] All MinGW binaries present

### 5. Verify Documentation Files
**Check these files exist:**
- [ ] `README.md`
- [ ] `AUTO_LAUNCH_SETUP.md`
- [ ] `ADMIN_LOGOUT_FEATURE.md`
- [ ] `PORT_CONFIGURATION.md`
- [ ] `LICENSE.txt`
- [ ] `screen_capture_agent\BUILD_INSTRUCTIONS.md`
- [ ] `screen_capture_agent\TROUBLESHOOTING.md`
- [ ] `screen_capture_agent\INSTALL.bat`

### 6. Update Version Number
Edit `LabAssistant_Setup.iss`:
```iss
#define MyAppVersion "1.0.4"
```

**Current version:** 1.0.4

**Features in this version:**
- Auto-launch screen capture agent on student login
- Admin logout broadcasts to all students
- Custom port configuration support
- Improved error handling and logging

### 7. Build Installer
```cmd
# Open Inno Setup Compiler
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" "C:\Users\user\LabAssistant\LabAssistant_Setup.iss"
```

**Or:**
- Open `LabAssistant_Setup.iss` in Inno Setup
- Click Build → Compile
- Wait for completion

**Verify:**
- [ ] Output at: `installer_output\LabAssistant_Setup_v1.0.4.exe`
- [ ] No compilation errors
- [ ] File size reasonable (check against previous versions)

## Post-Build Testing

### Test on Clean VM/PC
- [ ] Install Node.js v14+
- [ ] Install PostgreSQL v12+
- [ ] Run `LabAssistant_Setup_v1.0.4.exe`
- [ ] Verify installation completes without errors
- [ ] Check firewall rule created
- [ ] Check MinGW in PATH
- [ ] Launch application
- [ ] Test admin login
- [ ] Test student login
- [ ] Test screen capture auto-launch
- [ ] Test admin logout → student auto-logout
- [ ] Test screen monitoring connection

### Verify Installation Paths
After installation, verify these exist:
- [ ] `C:\Program Files\LabAssistant\labassistant.exe`
- [ ] `C:\Program Files\LabAssistant\backend\`
- [ ] `C:\Program Files\LabAssistant\MinGW\`
- [ ] `C:\Program Files\LabAssistant\screen_capture_agent\ScreenCaptureAgent.exe`
- [ ] `C:\Program Files\LabAssistant\screen_capture_agent\config.json`
- [ ] `C:\Program Files\LabAssistant\*.md` (documentation)

### Verify Firewall Rule
```powershell
Get-NetFirewallRule -DisplayName "Lab Assistant Screen Capture"
```

Should show:
- Direction: Inbound
- Action: Allow
- Protocol: TCP
- LocalPort: 8765

### Verify Backend Dependencies
```cmd
cd "C:\Program Files\LabAssistant\backend"
dir node_modules
```

Should show installed packages.

## Common Issues

### Issue: Flutter build fails
**Solution:**
```cmd
flutter clean
flutter pub get
flutter build windows --release
```

### Issue: Screen capture agent not found
**Solution:**
```cmd
cd screen_capture_agent
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
```

### Issue: Inno Setup can't find files
**Solution:**
- Check all paths in `LabAssistant_Setup.iss` are correct
- Verify files exist at specified locations
- Use absolute paths

### Issue: Installer too large
**Current size:** ~200-250MB (includes .NET runtime in agent)

**To reduce:**
- Use framework-dependent build for agent (requires .NET on target)
- Compress with UPX (not recommended for signed executables)

## Distribution

### Before Distribution
- [ ] Test on clean Windows 10 VM
- [ ] Test on clean Windows 11 VM
- [ ] Verify all features work
- [ ] Check for antivirus false positives
- [ ] Sign executable (if code signing certificate available)

### Distribution Checklist
- [ ] Upload to distribution server
- [ ] Create release notes
- [ ] Update download links
- [ ] Notify users of new version

## Installer Features (v1.0.4)

### Included Components
✅ Flutter Desktop Application  
✅ Node.js Backend Server  
✅ PostgreSQL Database Support  
✅ MinGW C Compiler  
✅ Screen Capture Agent (.NET 6.0)  
✅ Auto-launch functionality  
✅ Firewall configuration  
✅ Documentation files  

### Installation Actions
✅ Installs all components to Program Files  
✅ Installs backend dependencies (npm install)  
✅ Configures Windows Firewall for port 8765  
✅ Adds MinGW to system PATH  
✅ Creates config.json for screen capture agent  
✅ Creates desktop shortcut (optional)  
✅ Creates start menu entries  

### Prerequisites Check
✅ Checks for Node.js  
✅ Checks for PostgreSQL  
✅ Warns if missing (allows continue)  

## Version History

### v1.0.4 (Current)
- Auto-launch screen capture agent on student login
- Admin logout broadcasts to all connected students
- Custom port configuration for screen capture
- Improved PowerShell command escaping
- Added comprehensive documentation

### v1.0.3
- Initial installer version
- Basic components included

## Notes

- **Administrator privileges required** for installation
- **Firewall rule** automatically created for port 8765
- **Screen capture agent** requires UAC approval on first run
- **Backend dependencies** installed during setup (requires internet)
- **MinGW** added to PATH for C code compilation

## Support

For issues or questions:
- Check documentation in installation folder
- Review TROUBLESHOOTING.md
- Contact: Sidaz Technology (https://sidaz.vercel.app/)
