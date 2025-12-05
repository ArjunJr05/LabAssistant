@echo off
REM ========================================
REM Port Standardization Script
REM Changes screen capture agent port to 8765
REM ========================================

echo.
echo ========================================
echo Screen Capture Agent - Port Update
echo Changing port to 8765
echo ========================================
echo.

REM Define paths
set AGENT_DIR=C:\LabAssistant\ScreenCaptureAgent
set CONFIG_FILE=%AGENT_DIR%\config.json
set AGENT_EXE=ScreenCaptureAgent.exe

REM Check if agent directory exists
if not exist "%AGENT_DIR%" (
    echo ERROR: Agent directory not found: %AGENT_DIR%
    echo Please install the screen capture agent first.
    pause
    exit /b 1
)

echo [1/4] Stopping existing agent...
taskkill /F /IM %AGENT_EXE% >nul 2>&1
if %errorLevel% equ 0 (
    echo Agent stopped successfully
) else (
    echo Agent was not running
)
timeout /t 2 /nobreak >nul

echo.
echo [2/4] Updating config.json to port 8765...
echo {"port": 8765} > "%CONFIG_FILE%"
if exist "%CONFIG_FILE%" (
    echo Config updated successfully
    type "%CONFIG_FILE%"
) else (
    echo ERROR: Failed to create config file
    pause
    exit /b 1
)

echo.
echo [3/4] Updating Windows Firewall...
REM Remove old firewall rule
netsh advfirewall firewall delete rule name="Lab Assistant Screen Capture" >nul 2>&1

REM Add new firewall rule for port 8765
netsh advfirewall firewall add rule name="Lab Assistant Screen Capture" dir=in action=allow protocol=TCP localport=8765 program="%AGENT_DIR%\%AGENT_EXE%" enable=yes >nul 2>&1
if %errorLevel% equ 0 (
    echo Firewall rule updated for port 8765
) else (
    echo WARNING: Failed to update firewall rule
    echo You may need to run this script as Administrator
)

echo.
echo [4/4] Starting agent with new port...
cd /d "%AGENT_DIR%"
start "" "%AGENT_EXE%"
timeout /t 3 /nobreak >nul

REM Verify agent is running
tasklist /FI "IMAGENAME eq %AGENT_EXE%" 2>NUL | find /I /N "%AGENT_EXE%">NUL
if %errorLevel% equ 0 (
    echo Success: Agent started successfully on port 8765
) else (
    echo Warning: Agent may not have started - check manually
)

echo.
echo ========================================
echo Port Update Complete!
echo ========================================
echo.
echo Agent is now configured for port 8765
echo.
pause
