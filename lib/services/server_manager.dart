import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config_service.dart';

class ServerManager extends ChangeNotifier {
  Process? _serverProcess;
  bool _isServerRunning = false;
  
  bool get isServerRunning => _isServerRunning;
  
  Future<String> get serverIP async => await ConfigService.getServerIp();
  Future<String> get serverUrl async => await ConfigService.getServerUrl();
  
  ServerManager();
  
  Future<void> setServerIP(String ip) async {
    await ConfigService.setServerIp(ip);
    ConfigService.clearCache();
    notifyListeners();
  }
  
  Future<bool> startServer() async {
    try {
      if (_serverProcess != null) {
        print('🔄 Server process already running');
        final isRunning = await checkServerStatus();
        if (isRunning) {
          return true;
        } else {
          // Process exists but server not responding, clean up
          await stopServer();
        }
      }
      
      print('🚀 Starting Node.js server...');
      
      final backendPath = Platform.isWindows 
          ? r'C:\Users\arjun\labassistant\backend'
          : '/Users/arjun/labassistant/backend';
      
      // Check if backend directory exists
      final backendDir = Directory(backendPath);
      if (!await backendDir.exists()) {
        print('❌ Backend directory not found: $backendPath');
        return false;
      }
      
      // Optimized Node.js/npm check with caching
      final hasNodeAndNpm = await _checkNodeAndNpm();
      if (!hasNodeAndNpm) {
        print('❌ Node.js or npm not found. Please install Node.js from https://nodejs.org/');
        return false;
      }
      
      // Kill any existing Node.js processes to prevent conflicts
      await killExistingNodeProcesses();
      
      // Try to start the server with optimized approach
      _serverProcess = await _startServerProcessOptimized(backendPath);
      
      if (_serverProcess != null) {
        print('✅ Server process started with PID: ${_serverProcess!.pid}');
        
        // Optimized output handling with buffering
        _setupProcessListeners();
        
        // Reduced wait time and intelligent status checking
        await Future.delayed(const Duration(seconds: 2));
        
        // Check if server is actually running with retry
        final isRunning = await _checkServerStatusWithRetry();
        if (isRunning) {
          _isServerRunning = true;
          notifyListeners();
          print('🎉 Server started successfully');
          return true;
        } else {
          print('❌ Server failed to start properly');
          await stopServer();
          return false;
        }
      }
      
      return false;
    } catch (e) {
      print('💥 Error starting server: $e');
      await stopServer(); // Cleanup on error
      return false;
    }
  }
  
  // Stop the Node.js server
  Future<bool> stopServer() async {
    try {
      if (_serverProcess != null) {
        print('🛑 Stopping Node.js server...');
        
        // Kill the process
        _serverProcess!.kill();
        
        // Wait for process to exit
        await _serverProcess!.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('⚠️ Server process did not exit gracefully, force killing...');
            _serverProcess!.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
        
        _serverProcess = null;
        _isServerRunning = false;
        notifyListeners();
        
        print('✅ Server stopped successfully');
        return true;
      } else {
        print('ℹ️ No server process to stop');
        _isServerRunning = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('💥 Error stopping server: $e');
      _serverProcess = null;
      _isServerRunning = false;
      notifyListeners();
      return false;
    }
  }
  
  // Optimized server status check with retry logic
  Future<bool> checkServerStatus() async {
    try {
      final url = await serverUrl;
      print('🔍 Checking server status at: $url/api/status');
      
      final response = await http.get(
        Uri.parse('$url/api/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3)); // Reduced timeout
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final isOnline = data['server'] == 'online';
        
        print('✅ Server status check: ${isOnline ? 'ONLINE' : 'OFFLINE'}');
        
        _isServerRunning = isOnline;
        notifyListeners();
        return isOnline;
      } else {
        print('❌ Server status check failed: ${response.statusCode}');
        _isServerRunning = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('💥 Server status check error: $e');
      _isServerRunning = false;
      notifyListeners();
      return false;
    }
  }
  
  // Enhanced status check with intelligent retry
  Future<bool> _checkServerStatusWithRetry() async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 1);
    
    for (int i = 0; i < maxRetries; i++) {
      final isOnline = await checkServerStatus();
      if (isOnline) {
        return true;
      }
      
      if (i < maxRetries - 1) {
        print('⏳ Retrying server status check in ${retryDelay.inSeconds}s...');
        await Future.delayed(retryDelay);
      }
    }
    
    return false;
  }
  
  // Optimized process output handling
  void _setupProcessListeners() {
    if (_serverProcess == null) return;
    
    // Buffer output to reduce UI blocking
    _serverProcess!.stdout.transform(utf8.decoder).listen(
      (data) {
        // Only log important messages to reduce noise
        if (data.contains('Server running') || data.contains('error') || data.contains('listening')) {
          print('📡 Server: $data');
        }
      },
      onError: (error) => print('⚠️ Server stdout error: $error'),
    );
    
    _serverProcess!.stderr.transform(utf8.decoder).listen(
      (data) {
        print('⚠️ Server stderr: $data');
      },
      onError: (error) => print('⚠️ Server stderr error: $error'),
    );
  }
  
  // Optimized server process startup with intelligent approach selection
  Future<Process?> _startServerProcessOptimized(String backendPath) async {
    if (Platform.isWindows) {
      // Prioritized approaches based on success rate
      final approaches = [
        // Most reliable approach first
        () => Process.start('cmd', ['/c', 'npm', 'start'], 
            workingDirectory: backendPath, mode: ProcessStartMode.normal),
        
        // Fallback approaches
        () => Process.start('npm.cmd', ['start'], 
            workingDirectory: backendPath, mode: ProcessStartMode.detached),
        
        () => Process.start('powershell', ['-Command', 'npm start'], 
            workingDirectory: backendPath, mode: ProcessStartMode.detached),
      ];
      
      // Try approaches with timeout to prevent hanging
      for (int i = 0; i < approaches.length; i++) {
        try {
          print('🔧 Trying optimized approach ${i + 1}...');
          final process = await approaches[i]().timeout(Duration(seconds: 10));
          print('✅ Successfully started with approach ${i + 1}');
          return process;
        } catch (e) {
          print('❌ Approach ${i + 1} failed: $e');
          if (i < approaches.length - 1) {
            await Future.delayed(Duration(milliseconds: 500)); // Brief delay between attempts
          }
        }
      }
      print('💥 All optimized approaches failed on Windows');
      return null;
    } else {
      // Unix-like systems with timeout
      try {
        print('🔧 Starting npm on Unix-like system...');
        return await Process.start('npm', ['start'], 
            workingDirectory: backendPath, mode: ProcessStartMode.detached)
            .timeout(Duration(seconds: 10));
      } catch (e) {
        print('❌ Failed to start npm on Unix: $e');
        return null;
      }
    }
  }

  // Kill existing Node.js processes to prevent conflicts
  Future<void> killExistingNodeProcesses() async {
    try {
      if (Platform.isWindows) {
        // Kill any existing node.exe processes
        await Process.run('taskkill', ['/F', '/IM', 'node.exe'], runInShell: true);
        print('🧹 Cleaned up existing Node.js processes');
      } else {
        // Unix-like systems
        await Process.run('pkill', ['-f', 'node'], runInShell: true);
        print('🧹 Cleaned up existing Node.js processes');
      }
    } catch (e) {
      // Ignore errors - processes might not exist
      print('ℹ️ No existing Node.js processes to clean up');
    }
  }

  // Check if Node.js and npm are available on the system
  Future<bool> _checkNodeAndNpm() async {
    try {
      // Check Node.js
      ProcessResult nodeResult;
      if (Platform.isWindows) {
        nodeResult = await Process.run('cmd', ['/c', 'node', '--version']);
      } else {
        nodeResult = await Process.run('node', ['--version']);
      }
      
      if (nodeResult.exitCode != 0) {
        print('❌ Node.js not found');
        return false;
      }
      
      print('✅ Node.js found: ${nodeResult.stdout.toString().trim()}');
      
      // Check npm
      ProcessResult npmResult;
      if (Platform.isWindows) {
        npmResult = await Process.run('cmd', ['/c', 'npm', '--version']);
      } else {
        npmResult = await Process.run('npm', ['--version']);
      }
      
      if (npmResult.exitCode != 0) {
        print('❌ npm not found');
        return false;
      }
      
      print('✅ npm found: ${npmResult.stdout.toString().trim()}');
      return true;
    } catch (e) {
      print('❌ Error checking Node.js/npm: $e');
      return false;
    }
  }

  // Enhanced cleanup method to prevent memory leaks
  Future<void> cleanup() async {
    try {
      await stopServer();
      await killExistingNodeProcesses();
      _serverProcess = null;
      _isServerRunning = false;
      print('🧹 ServerManager cleanup completed');
    } catch (e) {
      print('⚠️ Error during ServerManager cleanup: $e');
    }
  }

  @override
  void dispose() {
    // Don't await in dispose, but ensure cleanup happens
    cleanup();
    super.dispose();
  }
}
