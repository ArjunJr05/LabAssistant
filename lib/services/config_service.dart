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
    
    // For students, try to discover admin IP by scanning common network ranges
    final adminIp = await _discoverAdminServer();
    if (adminIp != null) {
      _cachedServerIp = adminIp;
      await prefs.setString(_serverIpKey, adminIp);
      return _cachedServerIp!;
    }
    
    // If all fails, throw an error
    throw Exception('Unable to connect to server. Please ensure admin is logged in and server is running.');
  }
  
  /// Discover admin server by scanning network
  static Future<String?> _discoverAdminServer() async {
    try {
      print('🔍 Discovering admin server on network...');
      
      // Get current system IP to determine network range
      final currentIP = await getCurrentSystemIP();
      if (currentIP == null || currentIP == 'localhost') {
        print('❌ Cannot determine network range - no valid IP found');
        return null;
      }
      
      print('📍 Current system IP: $currentIP');
      
      // Extract network prefix (e.g., 172.17.13.x)
      final ipParts = currentIP.split('.');
      if (ipParts.length != 4) {
        print('❌ Invalid IP format: $currentIP');
        return null;
      }
      
      final networkPrefix = '${ipParts[0]}.${ipParts[1]}.${ipParts[2]}';
      print('🌐 Scanning network range: $networkPrefix.x');
      
      // Common IP ranges to check (prioritize current subnet)
      final List<String> ipRangesToCheck = [
        networkPrefix, // Current subnet first
        '192.168.1',   // Common home network
        '192.168.0',   // Another common range
        '10.0.0',      // Corporate network
      ];
      
      // Remove duplicates
      final uniqueRanges = ipRangesToCheck.toSet().toList();
      
      for (final range in uniqueRanges) {
        print('🔍 Scanning range: $range.x');
        
        // Check a reasonable range of IPs (1-254)
        final futures = <Future<String?>>[];
        
        // Scan in batches to avoid overwhelming the network
        for (int i = 1; i <= 254; i += 10) {
          final endRange = (i + 9 > 254) ? 254 : i + 9;
          
          for (int j = i; j <= endRange; j++) {
            final testIp = '$range.$j';
            
            // Skip current system IP
            if (testIp == currentIP) continue;
            
            futures.add(_checkAdminServer(testIp));
          }
          
          // Process batch and check for results
          final results = await Future.wait(futures, eagerError: false);
          final adminIp = results.firstWhere((ip) => ip != null, orElse: () => null);
          
          if (adminIp != null) {
            print('✅ Found admin server at: $adminIp');
            return adminIp;
          }
          
          futures.clear();
          
          // Small delay between batches
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      
      print('❌ No admin server found on network');
      return null;
      
    } catch (e) {
      print('❌ Error during admin server discovery: $e');
      return null;
    }
  }
  
  /// Check if a specific IP has an admin server running
  static Future<String?> _checkAdminServer(String ip) async {
    try {
      final response = await http.get(
        Uri.parse('http://$ip:$_defaultServerPort/api/admin/ip'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 2));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['ip'] != null) {
          print('✅ Admin server found at $ip with stored IP: ${data['ip']}');
          return data['ip'] as String;
        }
      }
    } catch (e) {
      // Silently ignore connection errors during discovery
    }
    return null;
  }
  
  /// Set server IP during admin login
  static Future<void> setServerIpForAdmin() async {
    final currentIP = await getCurrentSystemIP();
    if (currentIP != null) {
      await setServerIp(currentIP);
      // Also store in database
      await storeAdminIP(currentIP);
    }
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