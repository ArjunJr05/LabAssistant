# Lab Assistant Screen Capture Agent

A lightweight Windows application that captures screen content in real-time and streams it to the Lab Assistant admin interface via WebSocket connections.

## Features

- **Real-time Screen Capture**: Captures desktop at 10 FPS with 1280x720 resolution
- **Efficient Compression**: JPEG compression with 60% quality for optimal bandwidth usage
- **WebSocket Streaming**: Streams compressed frames to admin interface
- **LAN Discovery**: Automatically discoverable by admin interface on local network
- **Low Resource Usage**: Optimized for minimal CPU and memory impact
- **Silent Operation**: Runs quietly in background with console output

## System Requirements

- Windows 10/11 (64-bit)
- .NET 6.0 Runtime (included in self-contained build)
- Administrator privileges (for screen capture API access)
- Network connectivity to admin PC

## Quick Start

### Building the Agent

1. Open Command Prompt as Administrator
2. Navigate to the `screen_capture_agent` directory
3. Run the build script:
   ```cmd
   build.bat
   ```

### Deploying to Client PCs

1. Copy the entire `dist` folder to each client computer
2. On each client PC, run as Administrator:
   ```cmd
   cd dist
   ScreenCaptureAgent.exe
   ```

### Connecting from Admin Interface

1. Open Lab Assistant admin interface
2. Go to Admin Dashboard → Monitor Students → Screen Monitor tab
3. The agent will be automatically discovered, or manually enter the client IP address
4. Click "Connect" to start monitoring

## Network Configuration

### Firewall Settings
The agent uses port **8765** for WebSocket connections. Ensure this port is:
- Open in Windows Firewall on client PCs
- Allowed through corporate firewall if applicable

### Port Configuration
To change the default port (8765), modify the `WEBSOCKET_PORT` constant in `ScreenCaptureAgent.cs` and rebuild.

## Usage Instructions

### For IT Administrators

1. **Mass Deployment**: Copy the `dist` folder to a network share accessible by all client PCs
2. **Startup Script**: Create a startup script to automatically launch the agent:
   ```cmd
   @echo off
   cd "C:\LabAssistant\ScreenCaptureAgent"
   ScreenCaptureAgent.exe
   ```
3. **Group Policy**: Deploy via Group Policy for automatic installation and startup

### For Teachers/Admins

1. **Start Monitoring**: Open Lab Assistant → Admin Dashboard → Monitor Students
2. **Select Screen Monitor Tab**: Click on the "Screen Monitor" tab
3. **Auto Discovery**: Wait for clients to appear automatically, or
4. **Manual Connection**: Enter client IP addresses manually and click "Connect"
5. **View Screens**: See real-time screen feeds in a responsive grid layout
6. **Fullscreen Mode**: Click any screen tile to view in fullscreen mode

## Technical Details

### Screen Capture Method
- Uses Windows Desktop Duplication API for efficient screen capture
- Fallback to GDI+ BitBlt for compatibility
- Automatic resolution scaling to 1280x720 for consistent bandwidth

### Network Protocol
```json
{
  "type": "handshake",
  "clientInfo": {
    "computerName": "CLIENT-PC-01",
    "userName": "student1",
    "resolution": "1920x1080",
    "captureResolution": "1280x720",
    "fps": 10
  }
}
```

```json
{
  "type": "frame",
  "timestamp": 1640995200000,
  "data": "base64-encoded-jpeg-data",
  "format": "jpeg",
  "width": 1280,
  "height": 720
}
```

### Performance Optimization
- **Frame Rate**: Limited to 10 FPS to balance smoothness and bandwidth
- **Compression**: JPEG quality set to 60% for optimal size/quality ratio
- **Resolution**: Scaled to 1280x720 regardless of source resolution
- **Async Processing**: Non-blocking frame capture and transmission

## Troubleshooting

### Agent Won't Start
- **Run as Administrator**: Screen capture requires elevated privileges
- **Check .NET Runtime**: Ensure .NET 6.0 is installed
- **Firewall Issues**: Verify port 8765 is not blocked

### Connection Issues
- **Network Connectivity**: Ping between admin and client PCs
- **IP Address**: Verify correct IP address in admin interface
- **Port Conflicts**: Check if port 8765 is used by other applications

### Performance Issues
- **High CPU Usage**: Reduce FPS by modifying `TARGET_FPS` constant
- **Network Bandwidth**: Lower JPEG quality by adjusting `JPEG_QUALITY`
- **Memory Usage**: Restart agent periodically if memory usage grows

### Common Error Messages

| Error | Solution |
|-------|----------|
| "Access Denied" | Run as Administrator |
| "Port already in use" | Change port or close conflicting application |
| "Network unreachable" | Check firewall and network connectivity |
| "Screen capture failed" | Update graphics drivers, restart agent |

## Security Considerations

- **Network Security**: Use on trusted networks only
- **Data Privacy**: Screen content is transmitted unencrypted over LAN
- **Access Control**: No authentication - any admin can connect
- **Audit Trail**: Consider logging connections for security auditing

## Advanced Configuration

### Custom Settings
Modify these constants in `ScreenCaptureAgent.cs`:

```csharp
private const int TARGET_FPS = 10;          // Frames per second
private const int CAPTURE_WIDTH = 1280;     // Capture width
private const int CAPTURE_HEIGHT = 720;     // Capture height  
private const int WEBSOCKET_PORT = 8765;    // WebSocket port
private const long JPEG_QUALITY = 60L;     // JPEG quality (0-100)
```

### Multiple Monitor Support
Currently captures primary monitor only. To support multiple monitors, modify the screen capture logic in the `CaptureScreen()` method.

## Support

For technical support or feature requests, contact the Lab Assistant development team.

## License

This software is part of the Lab Assistant suite and is subject to the same licensing terms.
