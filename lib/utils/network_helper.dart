import '../services/config_service.dart';

class NetworkHelper {
  /// Reset network configuration to use the correct Wi-Fi IP
  static Future<void> resetNetworkConfig() async {
    await ConfigService.resetToDefault();
    print('🔧 Network configuration reset to: ${await ConfigService.getServerIp()}');
  }
  
  /// Get current network configuration for debugging
  static Future<Map<String, dynamic>> getNetworkInfo() async {
    return {
      'serverIp': await ConfigService.getServerIp(),
      'serverPort': await ConfigService.getServerPort(),
      'serverUrl': await ConfigService.getServerUrl(),
      'apiBaseUrl': await ConfigService.getApiBaseUrl(),
    };
  }
  
  /// Print network configuration for debugging
  static Future<void> debugNetworkConfig() async {
    final info = await getNetworkInfo();
    print('🌐 Current Network Configuration:');
    info.forEach((key, value) {
      print('   $key: $value');
    });
  }
}
