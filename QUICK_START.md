# LabAssistant - Quick Start Guide

## 🚀 Building the Installer (Quick Steps)

### Prerequisites
1. ✅ Inno Setup 6 installed from https://jrsoftware.org/isdl.php
2. ✅ Flutter SDK installed and configured
3. ✅ Node.js installed

### Build Process (Automated)

**Option 1: Use the automated script (Recommended)**

1. Right-click `build_installer.bat`
2. Select "Run as administrator"
3. Wait for the process to complete
4. Find your installer in `installer_output\` folder

**Option 2: Manual build**

```cmd
# 1. Update paths
dart run update_paths_for_deployment.dart

# 2. Clean and build Flutter app
flutter clean
flutter build windows --release

# 3. Install backend dependencies
cd backend
npm install --production
npm prune --production
cd ..

# 4. Open Inno Setup and compile
# Open LabAssistant_Setup.iss in Inno Setup Compiler
# Press F9 to compile
```

## 📦 What Gets Included

The installer packages:
- ✅ Flutter Windows application (compiled)
- ✅ Node.js backend server
- ✅ MinGW compiler (for C code execution)
- ✅ Screen capture agent
- ✅ All necessary dependencies

## 🎯 Installation Path Structure

After installation, the structure will be:
```
C:\Program Files\LabAssistant\
├── labassistant.exe              (Main application)
├── data\                         (Flutter data)
├── backend\                      (Node.js server)
│   ├── node_modules\
│   ├── routes\
│   ├── utils\
│   └── server.js
├── MinGW\                        (C compiler)
│   └── bin\
│       └── gcc.exe
└── screen_capture_agent\         (Screen monitoring)
    └── dist\
        └── ScreenCaptureAgent.exe
```

## ⚙️ Important Configuration

### Before Building

1. **Update AppId in LabAssistant_Setup.iss**:
   ```powershell
   # Generate GUID in PowerShell:
   [guid]::NewGuid()
   ```
   Replace `{YOUR-UNIQUE-GUID-HERE}` with the generated GUID

2. **Create LICENSE.txt** (if not exists)

3. **Optional: Add app icon**:
   - Place icon at `assets\icon.ico`
   - Or comment out `SetupIconFile` line in .iss file

### After Installation (On Target System)

1. **Database Setup**:
   ```sql
   CREATE DATABASE labassistant;
   ```

2. **Configure backend/.env**:
   ```
   DB_HOST=localhost
   DB_PORT=5432
   DB_NAME=labassistant
   DB_USER=postgres
   DB_PASSWORD=your_password
   JWT_SECRET=your_secret_key
   PORT=3000
   ```

## 🔍 Testing the Installer

### Test Checklist

- [ ] Install on clean Windows 10/11 machine
- [ ] Verify all files are copied correctly
- [ ] Check MinGW path is accessible
- [ ] Test backend server starts correctly
- [ ] Verify database connection works
- [ ] Test screen capture agent launches
- [ ] Try compiling and running C code
- [ ] Test student and admin login
- [ ] Verify all features work as expected

## 🐛 Common Issues & Solutions

### Issue: "Node.js not found"
**Solution**: Install Node.js from https://nodejs.org/ before running installer

### Issue: "PostgreSQL connection failed"
**Solution**: 
1. Install PostgreSQL
2. Create database
3. Update backend/.env with correct credentials

### Issue: "MinGW not found"
**Solution**: MinGW is included. Check if installation completed successfully.

### Issue: "Screen capture won't start"
**Solution**: Run application as Administrator

### Issue: "Port 3000 already in use"
**Solution**: 
```cmd
# Find process using port 3000
netstat -ano | findstr :3000

# Kill the process (replace PID with actual process ID)
taskkill /PID <PID> /F
```

## 📝 Version Updates

To release a new version:

1. Update version in `LabAssistant_Setup.iss`:
   ```
   #define MyAppVersion "1.0.1"
   ```

2. Rebuild Flutter app:
   ```cmd
   flutter build windows --release
   ```

3. Rebuild installer:
   ```cmd
   build_installer.bat
   ```

## 🔐 Security Notes

1. **Code Signing** (Recommended for production):
   - Get a code signing certificate
   - Sign the installer to avoid Windows SmartScreen warnings
   - Command: `signtool sign /f certificate.pfx /p password installer.exe`

2. **Checksum Verification**:
   - SHA256 checksum is automatically generated
   - Publish on website for users to verify integrity

3. **Antivirus**:
   - Some antivirus may flag the installer
   - Submit to vendors for whitelisting if needed

## 📞 Support

For help:
- 📧 Email: support@yourorganization.com
- 📚 Full guide: See DEPLOYMENT_GUIDE.md
- 🐛 Issues: Report bugs on GitHub

## ✅ Pre-Distribution Checklist

Before distributing to users:

- [ ] Tested on multiple Windows versions (10, 11)
- [ ] All features working correctly
- [ ] Database scripts tested
- [ ] Documentation updated
- [ ] Version number updated
- [ ] Installer signed (if applicable)
- [ ] Checksum generated and published
- [ ] Support channels ready
- [ ] User manual prepared
- [ ] Installation guide ready

## 🎉 Ready to Deploy!

Once all checks pass, you can distribute your installer to users!

**Installer file**: `installer_output\LabAssistant_Setup_v1.0.0.exe`

Good luck with your deployment! 🚀
