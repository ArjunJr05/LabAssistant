// Replace your AuthService temporarily with this debug version

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user_model.dart';
import 'server_manager.dart';
import 'config_service.dart';
import '../utils/network_helper.dart';

class AuthService extends ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = false;
  final ServerManager _serverManager = ServerManager();

  User? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _user != null;
  bool get isLoading => _isLoading;
  ServerManager get serverManager => _serverManager;

  AuthService() {
    // No longer load user from storage - always start fresh
    _isLoading = false;
  }

  // Removed _loadUserFromStorage - no longer persist authentication state

  Future<bool> login(String enrollNumber, String password) async {
    try {
      print('\n🚀 LOGIN ATTEMPT STARTED');
      print('👤 Username: $enrollNumber');
      print('🔒 Password length: ${password.length}');
      
      _isLoading = true;
      notifyListeners();

      final isAdminLogin = enrollNumber.toUpperCase() == 'ADMIN001';

      // For Student login: Check if server is online first
      if (!isAdminLogin) {
        print('👨‍🎓 STUDENT LOGIN - Checking server status...');
        
        // Debug network configuration
        await NetworkHelper.debugNetworkConfig();
        
        final serverOnline = await _serverManager.checkServerStatus();
        if (!serverOnline) {
          print('❌ Server is offline - Student login blocked');
          print('💡 Trying to reset network configuration...');
          await NetworkHelper.resetNetworkConfig();
          
          _isLoading = false;
          notifyListeners();
          throw Exception('Admin not logged in. Please wait for server.');
        }
        print('✅ Server is online - Student login allowed');
      }

      // Admin credential validation
      if (isAdminLogin) {
        print('🔑 ADMIN LOGIN DETECTED');
        print('🔐 Expected password: Admin_aids@smvec');
        print('🔐 Provided password: $password');
        print('🔐 Password match: ${password == 'Admin_aids@smvec'}');
        
        if (password != 'Admin_aids@smvec') {
          print('❌ Admin password validation FAILED');
          return false;
        }
        print('✅ Admin password validation PASSED');
        
        // Start server for Admin login
        print('🚀 Starting Node.js server for Admin...');
        final serverStarted = await _serverManager.startServer();
        if (!serverStarted) {
          print('❌ Failed to start server - Admin login blocked');
          return false;
        }
        print('✅ Server started successfully');
      }

      // Make API call (use config service for dynamic IP)
      final apiUrl = await ConfigService.getApiBaseUrl();
      print('🌐 Making API call to: $apiUrl/auth/login');
      
      final response = await http.post(
        Uri.parse('$apiUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'enrollNumber': enrollNumber,
          'password': password,
        }),
      );

      print('📡 API Response Status: ${response.statusCode}');
      print('📡 API Response Headers: ${response.headers}');
      print('📡 API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Login API call successful');
        print('🎫 Token received: ${data['token'] != null}');
        print('👤 User data: ${data['user']}');
        print('📊 Raw user data from API: ${data['user']}');
        
        _token = data['token'];
        _user = User.fromJson(data['user']);
        
        print('✅ User object created: ${_user?.name}');
        print('🏷️ User role: ${_user?.role}');
        print('🆔 User enroll number: ${_user?.enrollNumber}');
        
        // No longer save to storage - session only
        
        // Extra validation for admin
        if (isAdminLogin) {
          if (_user?.role != 'admin') {
            print('❌ SECURITY ERROR: Admin login but role is not admin!');
            print('🔍 Expected role: admin');
            print('🔍 Actual role: ${_user?.role}');
            await logout();
            return false;
          }
          print('✅ Admin role validation PASSED');
        }
        
        print('🎉 LOGIN SUCCESSFUL');
        
        // For student login, fetch IP addresses and update database
        if (_user?.role == 'student') {
          print('📡 Registering student with socket server...');
          // We'll emit this after the UI updates
          Future.delayed(Duration(milliseconds: 500), () {
            _emitStudentLogin();
            _updateStudentIpAddress();
          });
        }
        
        // Force immediate UI update
        _isLoading = false;
        notifyListeners();
        
        return true;
      } else {
        print('❌ API call failed');
        final errorData = json.decode(response.body);
        print('💥 Error message: ${errorData['message']}');
        
        // If admin login failed, stop the server
        if (isAdminLogin) {
          await _serverManager.stopServer();
        }
        
        return false;
      }
    } catch (e, stackTrace) {
      print('💥 LOGIN ERROR: $e');
      print('📍 Stack trace: $stackTrace');
      
      // If admin login failed, stop the server
      if (enrollNumber.toUpperCase() == 'ADMIN001') {
        await _serverManager.stopServer();
      }
      
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
      print('🏁 Login attempt finished\n');
    }
  }

  Future<bool> register({
    required String name,
    required String enrollNumber,
    required String year,
    required String section,
    required String batch,
    required String password,
  }) async {
    try {
      print('\n🚀 REGISTRATION ATTEMPT STARTED');
      print('👤 Name: $name');
      print('🆔 Enrollment Number: $enrollNumber');
      print('📅 Year: $year, Section: $section, Batch: $batch');
      
      _isLoading = true;
      notifyListeners();

      if (enrollNumber.toUpperCase() == 'ADMIN001' || 
          enrollNumber.toLowerCase().contains('admin')) {
        print('❌ Cannot register admin account through student registration');
        return false;
      }

      // Debug network configuration for registration
      await NetworkHelper.debugNetworkConfig();
      
      final apiUrl = await ConfigService.getApiBaseUrl();
      print('🌐 Making registration API call to: $apiUrl/auth/register');
      
      final response = await http.post(
        Uri.parse('$apiUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'enrollNumber': enrollNumber,
          'year': year,
          'section': section,
          'batch': batch,
          'password': password,
        }),
      );

      print('📡 Registration Response Status: ${response.statusCode}');
      print('📡 Registration Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Registration API call successful');
        print('🎫 Token received: ${data['token'] != null}');
        print('👤 User data: ${data['user']}');
        
        _token = data['token'];
        _user = User.fromJson(data['user']);
        
        print('✅ User object created: ${_user?.name}');
        print('🏷️ User role: ${_user?.role}');
        print('🆔 User enroll number: ${_user?.enrollNumber}');
        
        // No longer save to storage - session only
        print('🎉 REGISTRATION SUCCESSFUL');
        return true;
      } else {
        print('❌ Registration API call failed');
        try {
          final errorData = json.decode(response.body);
          print('💥 Error message: ${errorData['message'] ?? errorData['error'] ?? 'Unknown error'}');
        } catch (e) {
          print('💥 Error response: ${response.body}');
        }
        return false;
      }
    } catch (e, stackTrace) {
      print('💥 REGISTRATION ERROR: $e');
      print('📍 Stack trace: $stackTrace');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
      print('🏁 Registration attempt finished\n');
    }
  }

  Future<bool> registerAdmin({
    required String name,
    required String username,
    required String password,
    required String masterPassword,
  }) async {
    try {
      print('\n🚀 ADMIN REGISTRATION ATTEMPT STARTED');
      print('👤 Admin Name: $name');
      print('🆔 Admin Username: $username');
      print('🔐 Master Password Check: ${masterPassword == 'Admin_aids@smvec'}');
      
      _isLoading = true;
      notifyListeners();

      // Validate master password on client side first
      if (masterPassword != 'Admin_aids@smvec') {
        print('❌ Invalid master password provided');
        return false;
      }

      // Debug network configuration for admin registration
      await NetworkHelper.debugNetworkConfig();
      
      final apiUrl = await ConfigService.getApiBaseUrl();
      print('🌐 Making admin registration API call to: $apiUrl/auth/register-admin');
      
      final response = await http.post(
        Uri.parse('$apiUrl/auth/register-admin'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'username': username,
          'password': password,
          'masterPassword': masterPassword,
        }),
      );

      print('📡 Admin Registration Response Status: ${response.statusCode}');
      print('📡 Admin Registration Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Admin registration API call successful');
        print('🎫 Token received: ${data['token'] != null}');
        print('👤 Admin data: ${data['user']}');
        
        _token = data['token'];
        _user = User.fromJson(data['user']);
        
        print('✅ Admin user object created: ${_user?.name}');
        print('🏷️ Admin role: ${_user?.role}');
        print('🆔 Admin username: ${_user?.enrollNumber}');
        
        // No longer save to storage - session only
        print('🎉 ADMIN REGISTRATION SUCCESSFUL');
        return true;
      } else {
        print('❌ Admin registration API call failed');
        try {
          final errorData = json.decode(response.body);
          print('💥 Error message: ${errorData['message'] ?? errorData['error'] ?? 'Unknown error'}');
        } catch (e) {
          print('💥 Error response: ${response.body}');
        }
        return false;
      }
    } catch (e, stackTrace) {
      print('💥 ADMIN REGISTRATION ERROR: $e');
      print('📍 Stack trace: $stackTrace');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
      print('🏁 Admin registration attempt finished\n');
    }
  }

  Future<void> logout() async {
    try {
      print('\n🚪 LOGOUT PROCESS STARTED');
      print('👤 User: ${_user?.name} (${_user?.role})');
      
      // Check if current user is admin before logout
      final wasAdmin = _user?.role == 'admin';
      final wasStudent = _user?.role == 'student';
      
      if (wasAdmin) {
        print('🔑 Admin logout - Shutting down server...');
        
        // Notify all students about server shutdown
        try {
          final response = await http.post(
            Uri.parse('${await ConfigService.getApiBaseUrl()}/api/admin/shutdown-notification'),
            headers: authHeaders,
          );
          print('📡 Shutdown notification sent: ${response.statusCode}');
        } catch (e) {
          print('❌ Failed to send shutdown notification: $e');
        }
        
        // Stop the server
        await _serverManager.stopServer();
        print('🛑 Server stopped');
        
      } else if (wasStudent) {
        print('👨‍🎓 Student logout - Updating online status...');
        
        // For students, call logout endpoint to set offline status
        try {
          final apiUrl = await ConfigService.getApiBaseUrl();
          print('🌐 Calling logout API: $apiUrl/auth/logout');
          
          final response = await http.post(
            Uri.parse('$apiUrl/auth/logout'),
            headers: authHeaders,
            body: json.encode({
              'enrollNumber': _user?.enrollNumber,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          );
          
          print('📡 Logout API response: ${response.statusCode}');
          print('📡 Logout API body: ${response.body}');
          
          if (response.statusCode == 200) {
            print('✅ Student marked offline in database');
          } else {
            print('❌ Failed to mark student offline: ${response.statusCode}');
          }
        } catch (e) {
          print('❌ Error calling logout API: $e');
          // Continue with logout even if API call fails
        }
      }
      
      // Clear local data (memory only - no storage to clear)
      print('🧹 Clearing session data...');
      _user = null;
      _token = null;
      
      print('🔄 Notifying listeners...');
      notifyListeners();
      
      print('✅ LOGOUT COMPLETED SUCCESSFULLY\n');
      
    } catch (e, stackTrace) {
      print('💥 ERROR DURING LOGOUT: $e');
      print('📍 Stack trace: $stackTrace');
      
      // Still clear local data even if server call fails
      print('🧹 Force clearing session data...');
      _user = null;
      _token = null;
      notifyListeners();
      
      print('🏁 Logout completed with errors\n');
    }
  }
  // Removed _saveUserToStorage - authentication is now session-only

  void _emitStudentLogin() {
    if (_user?.role == 'student') {
      // Import SocketService and emit login event
      print('🔌 Emitting student login to socket server');
      // This will be handled by the UI components that have access to SocketService
    }
  }

  Future<void> _updateStudentIpAddress() async {
    try {
      print('AuthService: Starting IP address update...');
      
      // Get device IP addresses
      final ipAddresses = await NetworkHelper.getDeviceIpAddresses();
      print('AuthService: Retrieved IP addresses: $ipAddresses');
      
      if (ipAddresses.isEmpty) {
        print('AuthService: No IP addresses found, skipping update');
        return;
      }
      
      // Use the first available IP address (preferably local network IP)
      String primaryIp = ipAddresses['localIp'] ?? ipAddresses['publicIp'] ?? 'unknown';
      print('AuthService: Using primary IP: $primaryIp');
      
      // Send IP address in the login request body instead of separate API call
      // This will be handled by the updated login endpoint
      print('AuthService: IP address will be captured by login endpoint automatically');
      
    } catch (e) {
      print('AuthService: Error preparing IP address: $e');
    }
  }

  Map<String, String> get authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_token',
  };

  bool get isAdmin => _user?.role == 'admin';
  bool get isAdminUser => _user?.enrollNumber == 'ADMIN001' && _user?.role == 'admin';
}