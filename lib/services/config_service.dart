import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class ConfigService {
  static const String _serverIpKey = 'server_ip';
  static const String _serverPortKey = 'server_port';
  static const int _defaultServerPort = 3000;
  
  static String? _cachedServerIp;
  static int? _cachedServerPort;
  
  /// Get current system's IP address
  static Future<String?> getCurrentSystemIP() async {
    try {
      // Get all network interfaces
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      
      // Prefer non-loopback interfaces
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback && address.type == InternetAddressType.IPv4) {
            print('Found system IP: ${address.address}');
            return address.address;
          }
        }
      }
      
      // Fallback to localhost if no other IP found
      return 'localhost';
    } catch (e) {
      print('Error getting system IP: $e');
      return 'localhost';
    }
  }
  
  /// Store admin IP in database during login
  static Future<bool> storeAdminIP(String adminIP) async {
    try {
      print('Storing admin IP in database: $adminIP');
      final response = await http.post(
        Uri.parse('http://$adminIP:$_defaultServerPort/api/admin/store-ip'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'ip': adminIP}),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        print('Successfully stored admin IP in database');
        return true;
      } else {
        print('Failed to store admin IP: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error storing admin IP: $e');
      return false;
    }
  }
  
  /// Get the current server IP address
  static Future<String> getServerIp() async {
    if (_cachedServerIp != null) {
      return _cachedServerIp!;
    }
    
    final prefs = await SharedPreferences.getInstance();
    String? storedIp = prefs.getString(_serverIpKey);
    
    if (storedIp != null) {
      _cachedServerIp = storedIp;
      return _cachedServerIp!;
    }
    
    final adminIp = await _fetchAdminIpFromDatabase();
    if (adminIp != null) {
      _cachedServerIp = adminIp;
      await prefs.setString(_serverIpKey, adminIp);
      return _cachedServerIp!;
    }
    
    // If database fetch fails, throw an error instead of using fallback
    throw Exception('Unable to fetch admin IP from database. Please ensure the server is running and accessible.');
  }
  
  /// Get the current server port
  static Future<int> getServerPort() async {
    if (_cachedServerPort != null) {
      return _cachedServerPort!;
    }
    
    final prefs = await SharedPreferences.getInstance();
    _cachedServerPort = prefs.getInt(_serverPortKey) ?? _defaultServerPort;
    return _cachedServerPort!;
  }
  
  /// Get the complete server URL
  static Future<String> getServerUrl() async {
    final ip = await getServerIp();
    final port = await getServerPort();
    return 'http://$ip:$port';
  }
  
  /// Get the complete API base URL
  static Future<String> getApiBaseUrl() async {
    final serverUrl = await getServerUrl();
    return '$serverUrl/api';
  }
  
  /// Set the server IP address
  static Future<void> setServerIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverIpKey, ip);
    _cachedServerIp = ip;
  }
  
  /// Set the server port
  static Future<void> setServerPort(int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_serverPortKey, port);
    _cachedServerPort = port;
  }
  
  /// Clear cached values (useful when settings change)
  static void clearCache() {
    _cachedServerIp = null;
    _cachedServerPort = null;
  }
  
  
  /// Force reset configuration (useful for troubleshooting)
  static Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_serverIpKey); // Remove cached IP
    await prefs.setInt(_serverPortKey, _defaultServerPort);
    clearCache();
    print('Network configuration reset to default');
  }
}
