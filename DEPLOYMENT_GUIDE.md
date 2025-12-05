# LabAssistant - Deployment Guide

## Prerequisites for Building the Installer

### Required Software
1. **Inno Setup 6** (or later)
   - Download from: https://jrsoftware.org/isdl.php
   - Install with default settings

2. **Flutter SDK**
   - Already installed (used for development)

3. **Node.js** (v14 or higher)
   - Already installed (used for backend)

4. **Git** (optional, for version control)

## Step-by-Step Build Process

### Step 1: Prepare the Flutter Application

1. Open Command Prompt or PowerShell
2. Navigate to your project directory:
   ```cmd
   cd C:\Users\user\LabAssistant
   ```

3. Clean previous builds:
   ```cmd
   flutter clean
   ```

4. Build the Windows release version:
   ```cmd
   flutter build windows --release
   ```
   
   This will create the executable in:
   `C:\Users\user\LabAssistant\build\windows\runner\Release\`

### Step 2: Update Hardcoded Paths

Before building the installer, you need to update hardcoded paths to use relative paths:

#### 2.1 Update `backend/utils/compiler.js`

The installer will automatically update this, but for reference:
- Line 11: `const MINGW_PATH = 'C:\\Users\\user\\LabAssistant\\MinGW\\bin\\gcc.exe';`
- Should become: Use `path.join(process.cwd(), '..', 'MinGW', 'bin', 'gcc.exe')`

#### 2.2 Update `lib/services/server_manager.dart`

- Line 35: `final backendPath = Platform.isWindows ? r'C:\Users\user\labassistant\backend' : '/Users/user/labassistant/backend';`
- Should use: `path.join(Platform.resolvedExecutable, '..', 'backend')`

#### 2.3 Update `lib/screens/login_screen.dart`

- Line 931: `const agentPath = r'C:\Users\arjun\LabAssistant\screen_capture_agent\dist\ScreenCaptureAgent.exe';`
- Should use: `path.join(Platform.resolvedExecutable, '..', 'screen_capture_agent', 'dist', 'ScreenCaptureAgent.exe')`

### Step 3: Prepare Backend Dependencies

1. Navigate to backend directory:
   ```cmd
   cd C:\Users\user\LabAssistant\backend
   ```

2. Install production dependencies:
   ```cmd
   npm install --production
   ```

3. Remove development dependencies and cache:
   ```cmd
   npm prune --production
   ```

### Step 4: Create Required Files

#### 4.1 Create LICENSE.txt
Create a file at `C:\Users\user\LabAssistant\LICENSE.txt` with your license text.

Example:
```
MIT License

Copyright (c) 2025 Your Name

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction...
```

#### 4.2 Create Icon File (Optional)
If you have an app icon, save it as:
`C:\Users\user\LabAssistant\assets\icon.ico`

If not, remove or comment out this line in the .iss file:
```
; SetupIconFile=C:\Users\user\LabAssistant\assets\icon.ico
```

### Step 5: Update Inno Setup Script

1. Open `LabAssistant_Setup.iss` in a text editor

2. Generate a unique GUID for AppId:
   - Open PowerShell and run: `[guid]::NewGuid()`
   - Replace `{YOUR-UNIQUE-GUID-HERE}` with the generated GUID

3. Update publisher information:
   - Change `MyAppPublisher` to your organization name
   - Change `MyAppURL` to your website

4. Verify all paths in the `[Files]` section exist

### Step 6: Build the Installer

1. Open Inno Setup Compiler

2. Open the script:
   - File → Open → Select `C:\Users\user\LabAssistant\LabAssistant_Setup.iss`

3. Compile the script:
   - Build → Compile (or press F9)

4. The installer will be created at:
   `C:\Users\user\LabAssistant\installer_output\LabAssistant_Setup_v1.0.0.exe`

## Installation on Target Systems

### System Requirements
- **Operating System**: Windows 10 or later (64-bit)
- **RAM**: Minimum 4GB (8GB recommended)
- **Disk Space**: 500MB for application + space for database
- **Prerequisites**:
  - Node.js v14 or higher
  - PostgreSQL v12 or higher

### Installation Steps

1. **Run the installer** as Administrator:
   - Right-click `LabAssistant_Setup_v1.0.0.exe`
   - Select "Run as administrator"

2. **Follow the installation wizard**:
   - Accept the license agreement
   - Choose installation directory (default: `C:\Program Files\LabAssistant`)
   - Select additional tasks (desktop icon, etc.)

3. **Wait for installation**:
   - The installer will copy files
   - Install backend dependencies (npm install)
   - Configure paths automatically

4. **Database Setup** (First-time only):
   - Open PostgreSQL
   - Create database: `CREATE DATABASE labassistant;`
   - Run initialization scripts from `backend/database/`

5. **Configure Environment**:
   - Navigate to installation directory
   - Edit `backend/.env` file with your database credentials:
     ```
     DB_HOST=localhost
     DB_PORT=5432
     DB_NAME=labassistant
     DB_USER=postgres
     DB_PASSWORD=your_password
     JWT_SECRET=your_secret_key
     ```

6. **Launch the application**:
   - Use desktop shortcut or Start Menu
   - First launch will start the backend server automatically

## Troubleshooting

### Common Issues

#### 1. "Node.js not found" error
**Solution**: Install Node.js from https://nodejs.org/

#### 2. "PostgreSQL connection failed"
**Solution**: 
- Ensure PostgreSQL is running
- Check credentials in `backend/.env`
- Verify database exists

#### 3. "MinGW compiler not found"
**Solution**: 
- MinGW is included in the installation
- Check if `C:\Program Files\LabAssistant\MinGW\bin\gcc.exe` exists
- Reinstall if missing

#### 4. Screen Capture Agent not starting
**Solution**:
- Run the application as Administrator
- Accept UAC prompt when prompted
- Check if `screen_capture_agent\dist\ScreenCaptureAgent.exe` exists

#### 5. Backend server won't start
**Solution**:
- Check if port 3000 is already in use
- Run `netstat -ano | findstr :3000` to check
- Kill conflicting process or change port in backend configuration

## Updating the Application

### For New Versions

1. Rebuild Flutter app with new version number
2. Update version in `LabAssistant_Setup.iss`:
   ```
   #define MyAppVersion "1.0.1"
   ```
3. Rebuild installer
4. Users can install over existing version (will preserve database and configuration)

## Uninstallation

1. Go to Windows Settings → Apps → Apps & features
2. Find "LabAssistant"
3. Click Uninstall
4. Follow the uninstall wizard

**Note**: Database and user data are NOT automatically removed. To completely remove:
- Delete PostgreSQL database: `DROP DATABASE labassistant;`
- Remove any remaining files in installation directory

## Distribution

### Recommended Distribution Methods

1. **Direct Download**:
   - Host the installer on your website
   - Provide download link to users

2. **USB/Network Share**:
   - Copy installer to USB drive or network location
   - Users can run from there

3. **Internal Deployment** (for organizations):
   - Use Group Policy or SCCM for automated deployment
   - Create silent install script:
     ```cmd
     LabAssistant_Setup_v1.0.0.exe /VERYSILENT /NORESTART
     ```

## Security Considerations

1. **Code Signing** (Recommended):
   - Sign the installer with a valid code signing certificate
   - Prevents Windows SmartScreen warnings
   - Increases user trust

2. **Checksum Verification**:
   - Generate SHA256 hash of installer
   - Publish hash on website for verification
   - Command: `certutil -hashfile LabAssistant_Setup_v1.0.0.exe SHA256`

3. **Antivirus False Positives**:
   - Some antivirus software may flag the installer
   - Submit to antivirus vendors for whitelisting
   - Provide instructions for users to add exception

## Support

For issues or questions:
- Email: support@yourorganization.com
- Documentation: https://yourwebsite.com/docs
- GitHub Issues: https://github.com/yourusername/labassistant/issues

## License

This software is licensed under [Your License Type].
See LICENSE.txt for full license text.
