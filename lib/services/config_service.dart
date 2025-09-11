import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static const String _serverIpKey = 'server_ip';
  static const String _serverPortKey = 'server_port';
  static const String _defaultServerIp = '192.168.0.79'; // Default Wi-Fi IP
  static const int _defaultServerPort = 3000;
  
  static String? _cachedServerIp;
  static int? _cachedServerPort;
  
  /// Get the current server IP address
  static Future<String> getServerIp() async {
    if (_cachedServerIp != null) {
      return _cachedServerIp!;
    }
    
    final prefs = await SharedPreferences.getInstance();
    _cachedServerIp = prefs.getString(_serverIpKey) ?? _defaultServerIp;
    return _cachedServerIp!;
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
}
