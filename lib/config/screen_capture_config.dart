// lib/config/screen_capture_config.dart
// Centralized configuration for screen capture agent

class ScreenCaptureConfig {
  // Default port for screen capture agent
  // Change this value to use a different port across all systems
  static const int defaultPort = 8765;
  
  // Alternative ports (in case default is blocked)
  static const List<int> alternativePorts = [9000, 9001, 9002, 8766, 8767];
  
  // Connection timeout in seconds
  static const int connectionTimeout = 8;
  
  // Retry attempts for connection
  static const int maxRetryAttempts = 3;
  
  // Delay between retry attempts (in seconds)
  static const int retryDelay = 2;
}
