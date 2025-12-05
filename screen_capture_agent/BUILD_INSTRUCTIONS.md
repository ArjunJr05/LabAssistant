# Screen Capture Agent - Build Instructions

## Quick Build

### Build the executable:
```cmd
cd screen_capture_agent
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true
```

### Output location:
```
screen_capture_agent\bin\Release\net6.0-windows\win-x64\publish\ScreenCaptureAgent.exe
```

### Copy to root for easy access:
```cmd
copy bin\Release\net6.0-windows\win-x64\publish\ScreenCaptureAgent.exe .
```

## Installation on Student PCs

After building, use one of these methods:

### Method 1: Run INSTALL.bat (Recommended)
1. Copy the entire `screen_capture_agent` folder to student PC
2. Right-click `INSTALL.bat` → Run as administrator
3. Follow prompts

### Method 2: Manual Copy
1. Copy `ScreenCaptureAgent.exe` to `C:\LabAssistant\ScreenCaptureAgent\`
2. Create `config.json` with: `{"port": 8765}`
3. Add firewall rule (see AUTO_LAUNCH_SETUP.md)

## Development Testing

The Flutter app will automatically find the agent in:
- `screen_capture_agent\ScreenCaptureAgent.exe` (copied from build)
- `screen_capture_agent\bin\Release\net6.0-windows\win-x64\publish\ScreenCaptureAgent.exe` (build output)

Just run the Flutter app and log in as a student - it will auto-launch the agent!

## Build Requirements

- .NET 6.0 SDK or later
- Windows OS
- Visual Studio 2022 (optional, for development)

## Troubleshooting Build Issues

### "dotnet not found"
Install .NET SDK from: https://dotnet.microsoft.com/download

### Build errors
```cmd
dotnet clean
dotnet restore
dotnet build -c Release
```

### Large file size (150MB+)
This is normal for self-contained executables. It includes the .NET runtime.

To reduce size, use framework-dependent build:
```cmd
dotnet publish -c Release -r win-x64 --self-contained false
```
(Requires .NET 6.0 runtime on student PCs)
