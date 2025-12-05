@echo off
REM ========================================
REM Lab Assistant - Screen Capture Agent Installer
REM ========================================
REM This script installs the screen capture agent to a standard location
REM and configures Windows Firewall

echo.
echo ========================================
echo Lab Assistant Screen Capture Agent
echo Installation Script
echo ========================================
echo.

REM Check for administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run as Administrator!
    echo.
    echo Right-click this file and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

echo [1/5] Checking system...
echo.

REM Set installation directory
set INSTALL_DIR=C:\LabAssistant\ScreenCaptureAgent
set PORT=8765

REM Create installation directory
echo [2/5] Creating installation directory...
if not exist "%INSTALL_DIR%" (
    mkdir "%INSTALL_DIR%"
    echo Created: %INSTALL_DIR%
) else (
    echo Directory already exists: %INSTALL_DIR%
)
echo.

REM Copy files
echo [3/5] Copying files...
xcopy /Y /Q "ScreenCaptureAgent.exe" "%INSTALL_DIR%\"
if exist "config.json" (
    xcopy /Y /Q "config.json" "%INSTALL_DIR%\"
) else (
    echo {"port": %PORT%} > "%INSTALL_DIR%\config.json"
)
if exist "README.md" xcopy /Y /Q "README.md" "%INSTALL_DIR%\"
if exist "TROUBLESHOOTING.md" xcopy /Y /Q "TROUBLESHOOTING.md" "%INSTALL_DIR%\"
echo Files copied successfully
echo.

REM Configure Windows Firewall
echo [4/5] Configuring Windows Firewall...
netsh advfirewall firewall delete rule name="Lab Assistant Screen Capture" >nul 2>&1
netsh advfirewall firewall add rule name="Lab Assistant Screen Capture" dir=in action=allow protocol=TCP localport=%PORT% program="%INSTALL_DIR%\ScreenCaptureAgent.exe" enable=yes
if %errorLevel% equ 0 (
    echo Firewall rule added for port %PORT%
) else (
    echo WARNING: Failed to add firewall rule
)
echo.

REM Create desktop shortcut (optional)
echo [5/5] Installation complete!
echo.
echo ========================================
echo Installation Summary
echo ========================================
echo Location: %INSTALL_DIR%
echo Port: %PORT%
echo Firewall: Configured
echo.
echo IMPORTANT:
echo - The agent will be auto-launched when students log in
echo - If auto-launch fails, run manually from: %INSTALL_DIR%
echo - Always run as Administrator for proper functionality
echo.
echo ========================================
echo.

REM Ask if user wants to start the agent now
set /p START_NOW="Start the agent now? (Y/N): "
if /i "%START_NOW%"=="Y" (
    echo.
    echo Starting Screen Capture Agent...
    cd /d "%INSTALL_DIR%"
    start "" "ScreenCaptureAgent.exe"
    echo Agent started!
)

echo.
echo Installation complete. Press any key to exit...
pause >nul
