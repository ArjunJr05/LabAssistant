@echo off
REM ========================================
REM Firewall Configuration for Screen Capture Agent
REM Run this as Administrator
REM ========================================

echo.
echo ========================================
echo Configuring Windows Firewall
echo ========================================
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run as Administrator!
    echo Right-click this file and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

echo [1/3] Removing old firewall rules...
netsh advfirewall firewall delete rule name="Lab Assistant Screen Capture" >nul 2>&1
netsh advfirewall firewall delete rule name="Lab Assistant Screen Capture Agent" >nul 2>&1
echo Old rules removed (if they existed)

echo.
echo [2/3] Adding firewall rule for port 8765...
netsh advfirewall firewall add rule name="Lab Assistant Screen Capture" dir=in action=allow protocol=TCP localport=8765 enable=yes
if %errorLevel% equ 0 (
    echo Success: Port 8765 allowed
) else (
    echo ERROR: Failed to add port rule
    pause
    exit /b 1
)

echo.
echo [3/3] Adding firewall rule for executable...
netsh advfirewall firewall add rule name="Lab Assistant Screen Capture Agent" dir=in action=allow program="C:\LabAssistant\ScreenCaptureAgent\ScreenCaptureAgent.exe" enable=yes
if %errorLevel% equ 0 (
    echo Success: Executable allowed
) else (
    echo WARNING: Failed to add executable rule
)

echo.
echo ========================================
echo Firewall Configuration Complete!
echo ========================================
echo.
echo Port 8765 is now allowed through Windows Firewall
echo.
echo Verifying rules...
echo.
netsh advfirewall firewall show rule name="Lab Assistant Screen Capture"
echo.
pause
