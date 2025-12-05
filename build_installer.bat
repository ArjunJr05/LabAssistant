@echo off
REM LabAssistant - Automated Installer Build Script
REM This script automates the entire process of building the Windows installer

echo ========================================
echo  LabAssistant Installer Build Script
echo ========================================
echo.

REM Check if running as Administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run as Administrator!
    echo Right-click and select "Run as administrator"
    pause
    exit /b 1
)

echo Step 1: Updating paths for deployment...
echo ----------------------------------------
dart run update_paths_for_deployment.dart
if %errorLevel% neq 0 (
    echo ERROR: Failed to update paths
    pause
    exit /b 1
)
echo.

echo Step 2: Cleaning previous Flutter builds...
echo ----------------------------------------
call flutter clean
echo.

echo Step 3: Building Flutter Windows Release...
echo ----------------------------------------
call flutter build windows --release
if %errorLevel% neq 0 (
    echo ERROR: Flutter build failed
    pause
    exit /b 1
)
echo.

echo Step 4: Installing backend dependencies...
echo ----------------------------------------
cd backend
call npm install --production
if %errorLevel% neq 0 (
    echo ERROR: npm install failed
    pause
    exit /b 1
)
call npm prune --production
cd ..
echo.

echo Step 5: Creating installer output directory...
echo ----------------------------------------
if not exist "installer_output" mkdir installer_output
echo.

echo Step 6: Checking for Inno Setup...
echo ----------------------------------------
set INNO_SETUP="C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if not exist %INNO_SETUP% (
    echo ERROR: Inno Setup not found at %INNO_SETUP%
    echo Please install Inno Setup 6 from https://jrsoftware.org/isdl.php
    pause
    exit /b 1
)
echo Found Inno Setup
echo.

echo Step 7: Building installer with Inno Setup...
echo ----------------------------------------
%INNO_SETUP% "LabAssistant_Setup.iss"
if %errorLevel% neq 0 (
    echo ERROR: Inno Setup compilation failed
    pause
    exit /b 1
)
echo.

echo Step 8: Generating SHA256 checksum...
echo ----------------------------------------
cd installer_output
for %%F in (LabAssistant_Setup_*.exe) do (
    echo Generating checksum for %%F
    certutil -hashfile "%%F" SHA256 > "%%F.sha256"
    echo Checksum saved to %%F.sha256
)
cd ..
echo.

echo ========================================
echo  BUILD COMPLETED SUCCESSFULLY!
echo ========================================
echo.
echo Installer location:
dir /b installer_output\LabAssistant_Setup_*.exe
echo.
echo Next steps:
echo 1. Test the installer on a clean Windows machine
echo 2. Verify all features work correctly
echo 3. Distribute to users
echo.
echo Press any key to open installer output folder...
pause >nul
explorer installer_output
