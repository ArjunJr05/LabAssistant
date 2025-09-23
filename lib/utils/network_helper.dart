import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
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

  /// Get the device's local IP address
  static Future<String?> getLocalIpAddress() async {
    try {
      // Get all network interfaces
      final interfaces = await NetworkInterface.list();
      
      for (final interface in interfaces) {
        // Look for WiFi or Ethernet interfaces that are up
        if (interface.name.toLowerCase().contains('wi-fi') || 
            interface.name.toLowerCase().contains('ethernet') ||
            interface.name.toLowerCase().contains('wlan') ||
            interface.name.toLowerCase().contains('eth')) {
          
          for (final address in interface.addresses) {
            // Return the first IPv4 address that's not loopback
            if (address.type == InternetAddressType.IPv4 && 
                !address.isLoopback &&
                !address.address.startsWith('169.254')) { // Avoid APIPA addresses
              print('🌐 Found local IP: ${address.address} on ${interface.name}');
              return address.address;
            }
          }
        }
      }
      
      // Fallback: return any non-loopback IPv4 address
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 && 
              !address.isLoopback &&
              !address.address.startsWith('169.254')) {
            print('🌐 Fallback local IP: ${address.address} on ${interface.name}');
            return address.address;
          }
        }
      }
      
      print('❌ No local IP address found');
      return null;
    } catch (e) {
      print('❌ Error getting local IP: $e');
      return null;
    }
  }

  /// Get the device's public IP address
  static Future<String?> getPublicIpAddress() async {
    try {
      // Try multiple services for reliability
      final services = [
        'https://api.ipify.org?format=json',
        'https://httpbin.org/ip',
        'https://api.my-ip.io/ip.json',
      ];

      for (final service in services) {
        try {
          final response = await http.get(
            Uri.parse(service),
            headers: {'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            String? ip;
            
            // Different services return IP in different formats
            if (data['ip'] != null) {
              ip = data['ip'];
            } else if (data['origin'] != null) {
              ip = data['origin'];
            }
            
            if (ip != null) {
              print('🌍 Found public IP: $ip from $service');
              return ip;
            }
          }
        } catch (e) {
          print('⚠️ Failed to get IP from $service: $e');
          continue;
        }
      }
      
      print('❌ No public IP address found from any service');
      return null;
    } catch (e) {
      print('❌ Error getting public IP: $e');
      return null;
    }
  }

  /// Get both local and public IP addresses
  static Future<Map<String, String?>> getDeviceIpAddresses() async {
    print('🔍 Fetching device IP addresses...');
    
    final results = await Future.wait([
      getLocalIpAddress(),
      getPublicIpAddress(),
    ]);
    
    final localIp = results[0];
    final publicIp = results[1];
    
    print('📍 Device IP Summary:');
    print('   Local IP: ${localIp ?? 'Not found'}');
    print('   Public IP: ${publicIp ?? 'Not found'}');
    
    return {
      'localIp': localIp,
      'publicIp': publicIp,
    };
  }
}
