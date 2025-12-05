// lib/services/screen_capture_launcher.dart
// Service to automatically launch the screen capture agent when student logs in

import 'dart:io';
import 'package:process_run/shell.dart';
import '../config/screen_capture_config.dart';

class ScreenCaptureLauncher {
  static const String agentExecutableName = 'ScreenCaptureAgent.exe';
  static int get defaultPort => ScreenCaptureConfig.defaultPort;
  
  // Possible locations where the agent might be installed
  static final List<String> searchPaths = [
    'C:\\LabAssistant\\ScreenCaptureAgent',
    'C:\\Program Files\\LabAssistant\\ScreenCaptureAgent',
    'C:\\Program Files (x86)\\LabAssistant\\ScreenCaptureAgent',
    Platform.environment['USERPROFILE'] != null 
        ? '${Platform.environment['USERPROFILE']}\\LabAssistant\\ScreenCaptureAgent'
        : '',
    // Check in the same directory as the Flutter app
    '${Directory.current.path}\\screen_capture_agent',
    '${Directory.current.path}\\..\\screen_capture_agent',
    // Check in build output directory (for development)
    '${Directory.current.path}\\screen_capture_agent\\bin\\Release\\net6.0-windows\\win-x64\\publish',
  ];

  /// Find the screen capture agent executable
  static Future<String?> findAgentExecutable() async {
    print('🔍 Searching for ScreenCaptureAgent.exe...');
    
    for (final path in searchPaths) {
      if (path.isEmpty) continue;
      
      final exePath = '$path\\$agentExecutableName';
      final file = File(exePath);
      
      print('  Checking: $exePath');
      
      if (await file.exists()) {
        print('✅ Found agent at: $exePath');
        return exePath;
      }
    }
    
    print('❌ ScreenCaptureAgent.exe not found in any search path');
    return null;
  }

  /// Check if the agent is already running
  static Future<bool> isAgentRunning() async {
    try {
      final shell = Shell();
      final result = await shell.run('tasklist /FI "IMAGENAME eq $agentExecutableName"');
      
      final output = result.outText;
      final isRunning = output.contains(agentExecutableName);
      
      print(isRunning 
          ? '✅ ScreenCaptureAgent is already running' 
          : '⏸️  ScreenCaptureAgent is not running');
      
      return isRunning;
    } catch (e) {
      print('❌ Error checking if agent is running: $e');
      return false;
    }
  }

  /// Launch the screen capture agent with administrator privileges
  static Future<bool> launchAgent({int? port}) async {
    port ??= ScreenCaptureConfig.defaultPort;
    try {
      print('\n🚀 LAUNCHING SCREEN CAPTURE AGENT');
      
      // Check if already running
      if (await isAgentRunning()) {
        print('ℹ️  Agent is already running, skipping launch');
        return true;
      }
      
      // Find the executable
      final exePath = await findAgentExecutable();
      if (exePath == null) {
        print('❌ Cannot launch agent: executable not found');
        return false;
      }
      
      // Check if config.json exists, create if needed
      final configPath = '${File(exePath).parent.path}\\config.json';
      final configFile = File(configPath);
      
      if (!await configFile.exists()) {
        print('📝 Creating config.json with port $port');
        await configFile.writeAsString('{"port": $port}');
      }
      
      // Launch with administrator privileges using PowerShell
      print('🔐 Launching agent as Administrator...');
      print('📍 Path: $exePath');
      print('🔌 Port: $port');
      
      // Use PowerShell to run as administrator
      final shell = Shell();
      
      // Start the process in a new window with admin rights
      // Using Start-Process with -Verb RunAs to request elevation
      // Escape the path properly for PowerShell
      final escapedPath = exePath.replaceAll('\\', '\\\\');
      
      try {
        // Use single quotes in PowerShell to avoid escaping issues
        await shell.run('powershell -Command "Start-Process -FilePath \'$exePath\' -Verb RunAs -WindowStyle Minimized"');
        
        // Wait a moment for the process to start
        await Future.delayed(const Duration(seconds: 2));
        
        // Verify it's running
        final isRunning = await isAgentRunning();
        
        if (isRunning) {
          print('✅ Screen capture agent launched successfully!');
          return true;
        } else {
          print('⚠️  Agent may not have started (UAC prompt might be pending)');
          return false;
        }
      } catch (e) {
        print('❌ Error launching agent: $e');
        print('💡 User may have declined UAC prompt');
        return false;
      }
      
    } catch (e, stackTrace) {
      print('💥 ERROR LAUNCHING SCREEN CAPTURE AGENT: $e');
      print('📍 Stack trace: $stackTrace');
      return false;
    }
  }

  /// Stop the screen capture agent
  static Future<bool> stopAgent() async {
    try {
      print('🛑 Stopping screen capture agent...');
      
      if (!await isAgentRunning()) {
        print('ℹ️  Agent is not running');
        return true;
      }
      
      final shell = Shell();
      await shell.run('taskkill /F /IM $agentExecutableName');
      
      print('✅ Screen capture agent stopped');
      return true;
    } catch (e) {
      print('❌ Error stopping agent: $e');
      return false;
    }
  }

  /// Get agent status information
  static Future<Map<String, dynamic>> getAgentStatus() async {
    final isRunning = await isAgentRunning();
    final exePath = await findAgentExecutable();
    
    return {
      'isRunning': isRunning,
      'executableFound': exePath != null,
      'executablePath': exePath,
      'defaultPort': defaultPort,
    };
  }

  /// Launch agent silently (no error dialogs, just logs)
  static Future<void> launchAgentSilently({int? port}) async {
    port ??= ScreenCaptureConfig.defaultPort;
    try {
      await launchAgent(port: port);
    } catch (e) {
      print('Silent launch failed: $e');
      // Silently fail - don't show errors to user
    }
  }
}
