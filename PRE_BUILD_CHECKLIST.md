# Pre-Build Checklist for LabAssistant Installer

## ✅ Complete this checklist before building the installer

### 1. Code Preparation

- [ ] All features tested and working
- [ ] No hardcoded development paths remaining
- [ ] Database migrations are up to date
- [ ] All console.log/print statements reviewed (remove sensitive data)
- [ ] Error handling is robust
- [ ] API endpoints are secure

### 2. Path Updates Required

**IMPORTANT**: These files contain hardcoded paths that need updating:

#### File: `backend/utils/compiler.js` (Line 11)
```javascript
// BEFORE (Development):
const MINGW_PATH = 'C:\\Users\\user\\LabAssistant\\MinGW\\bin\\gcc.exe';

// AFTER (Production):
const path = require('path');
const MINGW_PATH = path.join(__dirname, '..', '..', 'MinGW', 'bin', 'gcc.exe');
```

#### File: `lib/services/server_manager.dart` (Line 35)
```dart
// BEFORE (Development):
final backendPath = Platform.isWindows 
    ? r'C:\Users\user\labassistant\backend'
    : '/Users/user/labassistant/backend';

// AFTER (Production):
final executableDir = File(Platform.resolvedExecutable).parent.path;
final backendPath = Platform.isWindows 
    ? '$executableDir\\backend'
    : '$executableDir/backend';
```

#### File: `lib/screens/login_screen.dart` (Line 931)
```dart
// BEFORE (Development):
const agentPath = r'C:\Users\arjun\LabAssistant\screen_capture_agent\dist\ScreenCaptureAgent.exe';

// AFTER (Production):
final executableDir = File(Platform.resolvedExecutable).parent.path;
final agentPath = Platform.isWindows
    ? '$executableDir\\screen_capture_agent\\dist\\ScreenCaptureAgent.exe'
    : '$executableDir/screen_capture_agent/dist/ScreenCaptureAgent';
```

**Quick Fix**: Run `dart run update_paths_for_deployment.dart` to update automatically

### 3. Configuration Files

- [ ] `.env.example` file exists in backend folder
- [ ] Database schema SQL files are in `backend/database/`
- [ ] README.md is up to date
- [ ] LICENSE.txt exists
- [ ] App icon exists at `assets/icon.ico` (or line commented in .iss)

### 4. Inno Setup Script

- [ ] AppId GUID generated and updated (replace `{YOUR-UNIQUE-GUID-HERE}`)
- [ ] Version number updated (`#define MyAppVersion`)
- [ ] Publisher name updated
- [ ] Website URL updated
- [ ] All file paths verified to exist

### 5. Dependencies Check

- [ ] Flutter SDK installed and working
- [ ] Node.js installed (v14+)
- [ ] Inno Setup 6 installed
- [ ] PostgreSQL installed (for testing)
- [ ] All npm packages in backend are production-ready

### 6. Build Environment

- [ ] Disk space available (minimum 2GB free)
- [ ] No other Flutter builds running
- [ ] Backend server is stopped
- [ ] No file locks on project files
- [ ] Antivirus temporarily disabled (if causing issues)

### 7. Testing Before Build

- [ ] App runs correctly in development mode
- [ ] Backend server starts successfully
- [ ] Database connection works
- [ ] MinGW compiler executes C code
- [ ] Screen capture agent launches
- [ ] Student login/registration works
- [ ] Admin login/dashboard works
- [ ] Exercise creation and submission works
- [ ] Tab switch detection works
- [ ] Student locking/unlocking works

### 8. Documentation

- [ ] User manual prepared
- [ ] Installation guide ready
- [ ] System requirements documented
- [ ] Troubleshooting guide available
- [ ] Support contact information updated

### 9. Security

- [ ] No sensitive data in code (passwords, API keys)
- [ ] Environment variables properly configured
- [ ] JWT secret is secure
- [ ] Database credentials not hardcoded
- [ ] SQL injection protection verified
- [ ] XSS protection implemented

### 10. Final Verification

- [ ] Version number consistent across all files
- [ ] Git repository is clean (all changes committed)
- [ ] Backup of current working version created
- [ ] Build script tested (`build_installer.bat`)

---

## 🚀 Ready to Build?

If all items are checked, proceed with:

```cmd
# Run as Administrator
build_installer.bat
```

Or follow manual steps in DEPLOYMENT_GUIDE.md

---

## 📋 Post-Build Testing

After building the installer:

- [ ] Install on clean Windows 10 VM
- [ ] Install on clean Windows 11 VM
- [ ] Test all major features
- [ ] Verify paths are correct
- [ ] Check file permissions
- [ ] Test uninstallation
- [ ] Verify no files left after uninstall (except database)

---

## 🎯 Distribution Checklist

Before distributing to users:

- [ ] Installer tested on multiple machines
- [ ] SHA256 checksum generated
- [ ] Release notes prepared
- [ ] Support team notified
- [ ] Download link prepared
- [ ] Installation instructions published
- [ ] Code signing completed (if applicable)

---

**Date Prepared**: _____________
**Prepared By**: _____________
**Version**: _____________
**Build Number**: _____________

---

## Notes

_Use this space for any additional notes or special considerations for this build:_

_______________________________________________________________

_______________________________________________________________

_______________________________________________________________
