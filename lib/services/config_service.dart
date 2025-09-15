import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ConfigService {
  static const String _serverIpKey = 'server_ip';
  static const String _serverPortKey = 'server_port';
  static const int _defaultServerPort = 3000;
  
  static String? _cachedServerIp;
  static int? _cachedServerPort;
  
  /// Fetch admin IP from database using known admin IP
  static Future<String?> _fetchAdminIpFromDatabase() async {
    // List of potential admin IPs to try
    final potentialAdminIPs = [
      '10.106.124.236', // Current admin IP from your table
      '172.17.13.191',  // Previous IP
      'localhost',      // Development fallback
    ];
    
    for (String adminIP in potentialAdminIPs) {
      try {
        print('Trying to fetch admin IP using: $adminIP');
        final response = await http.get(
          Uri.parse('http://$adminIP:$_defaultServerPort/api/admin/ip'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 3));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final fetchedIP = data['ip'] as String?;
          print('Successfully fetched admin IP from database: $fetchedIP');
          return fetchedIP;
        }
      } catch (e) {
        print('Failed to fetch admin IP using $adminIP: $e');
        continue; // Try next IP
      }
    }
    
    print('Failed to fetch admin IP from database using all potential IPs');
    return null;
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
    
    // Always try to fetch admin IP from database first
    final adminIp = await _fetchAdminIpFromDatabase();
    if (adminIp != null) {
      _cachedServerIp = adminIp;
      // Store the fetched IP for future use
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
  
  /// Auto-detect local network IP addresses (for convenience)
  static List<String> getCommonLocalIPs() {
    return [
      '192.168.0.79',
      '192.168.1.100',
      '192.168.1.101',
      '192.168.1.102',
      '192.168.0.100',
      '192.168.0.101',
      '192.168.0.102',
      '10.0.0.100',
      '10.0.0.101',
      '172.16.0.100',
      'localhost', // Keep as fallback for development
    ];
  }
  
  /// Force reset and fetch fresh IP from database (useful for troubleshooting)
  static Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_serverIpKey); // Remove cached IP
    await prefs.setInt(_serverPortKey, _defaultServerPort);
    clearCache();
    
    // Force fetch fresh IP from database
    await getServerIp();
  }
}
