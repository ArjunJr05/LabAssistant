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
        return true;
      }
      
      print('🚀 Starting Node.js server...');
      
      // Get the backend directory path
      final backendPath = Platform.isWindows 
          ? r'C:\Users\user\labassistant\backend'
          : '/Users/user/labassistant/backend';
      
      // Check if backend directory exists
      final backendDir = Directory(backendPath);
      if (!await backendDir.exists()) {
        print('❌ Backend directory not found: $backendPath');
        return false;
      }
      
      // Check if Node.js and npm are available
      final hasNodeAndNpm = await _checkNodeAndNpm();
      if (!hasNodeAndNpm) {
        print('❌ Node.js or npm not found. Please install Node.js from https://nodejs.org/');
        return false;
      }
      
      // Try to start the server with different approaches
      _serverProcess = await _startServerProcess(backendPath);
      
      if (_serverProcess != null) {
        print('✅ Server process started with PID: ${_serverProcess!.pid}');
        
        // Listen to process output for debugging
        _serverProcess!.stdout.transform(utf8.decoder).listen((data) {
          print('📡 Server stdout: $data');
        });
        
        _serverProcess!.stderr.transform(utf8.decoder).listen((data) {
          print('⚠️ Server stderr: $data');
        });
        
        // Wait a moment for server to start
        await Future.delayed(const Duration(seconds: 3));
        
        // Check if server is actually running
        final isRunning = await checkServerStatus();
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
  
  // Check if server is online by hitting the status endpoint
  Future<bool> checkServerStatus() async {
    try {
      final url = await serverUrl;
      print('🔍 Checking server status at: $url/api/status');
      
      final response = await http.get(
        Uri.parse('$url/api/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
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
  
  // Try different approaches to start the server process
  Future<Process?> _startServerProcess(String backendPath) async {
    if (Platform.isWindows) {
      // Try multiple approaches on Windows
      final approaches = [
        // Approach 1: Use cmd.exe
        () => Process.start('cmd', ['/c', 'npm', 'start'], 
            workingDirectory: backendPath, mode: ProcessStartMode.detached),
        
        // Approach 2: Use PowerShell
        () => Process.start('powershell', ['-Command', 'npm start'], 
            workingDirectory: backendPath, mode: ProcessStartMode.detached),
        
        // Approach 3: Try npm.cmd directly
        () => Process.start('npm.cmd', ['start'], 
            workingDirectory: backendPath, mode: ProcessStartMode.detached),
        
        // Approach 4: Try with full path to npm
        () => Process.start('C:\\Program Files\\nodejs\\npm.cmd', ['start'], 
            workingDirectory: backendPath, mode: ProcessStartMode.detached),
      ];
      
      for (int i = 0; i < approaches.length; i++) {
        try {
          print('🔧 Trying approach ${i + 1} to start npm...');
          final process = await approaches[i]();
          print('✅ Successfully started with approach ${i + 1}');
          return process;
        } catch (e) {
          print('❌ Approach ${i + 1} failed: $e');
          if (i == approaches.length - 1) {
            print('💥 All approaches failed on Windows');
          }
        }
      }
      return null;
    } else {
      // Unix-like systems
      try {
        print('🔧 Starting npm on Unix-like system...');
        return await Process.start('npm', ['start'], 
            workingDirectory: backendPath, mode: ProcessStartMode.detached);
      } catch (e) {
        print('❌ Failed to start npm on Unix: $e');
        return null;
      }
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

  // Kill any existing Node.js processes (cleanup utility)
  Future<void> killExistingNodeProcesses() async {
    try {
      if (Platform.isWindows) {
        // Kill Node.js processes on Windows
        await Process.run('taskkill', ['/F', '/IM', 'node.exe']);
        print('🧹 Killed existing Node.js processes on Windows');
      } else {
        // Kill Node.js processes on Unix-like systems
        await Process.run('pkill', ['-f', 'node']);
        print('🧹 Killed existing Node.js processes on Unix');
      }
    } catch (e) {
      print('ℹ️ No existing Node.js processes to kill or error: $e');
    }
  }
  
  @override
  void dispose() {
    stopServer();
    super.dispose();
  }
}
