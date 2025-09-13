@echo off
echo Building Lab Assistant Screen Capture Agent...
echo.

REM Check if .NET 6 is installed
dotnet --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: .NET 6.0 SDK is not installed or not in PATH
    echo Please install .NET 6.0 SDK from: https://dotnet.microsoft.com/download/dotnet/6.0
    pause
    exit /b 1
)

REM Restore packages
echo Restoring NuGet packages...
dotnet restore
if %errorlevel% neq 0 (
    echo ERROR: Failed to restore packages
    pause
    exit /b 1
)

REM Build the application
echo Building application...
dotnet build --configuration Release
if %errorlevel% neq 0 (
    echo ERROR: Build failed
    pause
    exit /b 1
)

REM Publish as self-contained executable
echo Publishing self-contained executable...
dotnet publish --configuration Release --runtime win-x64 --self-contained true --output ./dist
if %errorlevel% neq 0 (
    echo ERROR: Publish failed
    pause
    exit /b 1
)

echo.
echo SUCCESS: Screen Capture Agent built successfully!
echo Executable location: .\dist\ScreenCaptureAgent.exe
echo.
echo To run the agent:
echo 1. Copy the 'dist' folder to client computers
echo 2. Run ScreenCaptureAgent.exe as Administrator
echo 3. The agent will display its IP address and wait for connections
echo.
pause
