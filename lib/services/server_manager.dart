import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ServerManager extends ChangeNotifier {
  Process? _serverProcess;
  bool _isServerRunning = false;
  String _serverIP = '10.106.124.130'; // Default IP
  static const int _serverPort = 3000;
  
  bool get isServerRunning => _isServerRunning;
  String get serverIP => _serverIP;
  String get serverUrl => 'http://$_serverIP:$_serverPort';
  
  ServerManager() {
    _loadServerIP();
  }
  
  // Load server IP from preferences
  Future<void> _loadServerIP() async {
    final prefs = await SharedPreferences.getInstance();
    _serverIP = prefs.getString('server_ip') ?? '10.106.124.130';
    notifyListeners();
  }
  
  // Save server IP to preferences
  Future<void> setServerIP(String ip) async {
    _serverIP = ip;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_ip', ip);
    notifyListeners();
  }
  
  // Start the Node.js server
  Future<bool> startServer() async {
    try {
      if (_serverProcess != null) {
        print('🔄 Server process already running');
        return true;
      }
      
      print('🚀 Starting Node.js server...');
      
      // Get the backend directory path
      final backendPath = Platform.isWindows 
          ? r'C:\Users\arjun\labassistant\backend'
          : '/Users/arjun/labassistant/backend';
      
      // Check if backend directory exists
      final backendDir = Directory(backendPath);
      if (!await backendDir.exists()) {
        print('❌ Backend directory not found: $backendPath');
        return false;
      }
      
      // Start npm start process
      _serverProcess = await Process.start(
        'npm',
        ['start'],
        workingDirectory: backendPath,
        mode: ProcessStartMode.detached,
      );
      
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
      print('🔍 Checking server status at: $serverUrl/api/status');
      
      final response = await http.get(
        Uri.parse('$serverUrl/api/status'),
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
