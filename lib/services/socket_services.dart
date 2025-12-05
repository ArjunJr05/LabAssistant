// lib/services/socket_service.dart
// Complete enhanced socket service with admin logout and shutdown handling

import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'config_service.dart';

class SocketService extends ChangeNotifier {
  IO.Socket? socket;
  bool _isConnected = false;
  bool _disposed = false;
  String? _currentUserRole;
  String? _currentUserEnrollNumber;
  String? _currentUserName;
  
  // Connection status callbacks
  Function()? onConnected;
  Function()? onDisconnected;
  Function(String error)? onConnectionError;
  
  // Admin specific callbacks
  Function(Map<String, dynamic> data)? onAdminShutdown;
  Function(Map<String, dynamic> data)? onForceDisconnect;
  
  // Student specific callbacks
  Function(List<dynamic> users)? onOnlineUsersUpdate;
  Function(Map<String, dynamic> data)? onUserStatusChanged;

  bool get isConnected => _isConnected;
  String? get currentUserRole => _currentUserRole;
  String? get currentUserEnrollNumber => _currentUserEnrollNumber;
  String? get currentUserName => _currentUserName;

  void _safeNotifyListeners() {
    // Only notify listeners if we're not in a build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  Future<void> connect() async {
    if (socket?.connected == true) {
      print('Socket already connected');
      return;
    }

    try {
      final serverUrl = await ConfigService.getServerUrl();
      print('Connecting to socket server: $serverUrl');
      
      socket = IO.io(serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'timeout': 20000,
        'reconnection': true,
        'reconnectionAttempts': 5,
        'reconnectionDelay': 1000,
      });

      _setupSocketListeners();
      socket!.connect();
      
    } catch (e) {
      print('Error setting up socket connection: $e');
      _isConnected = false;
      _safeNotifyListeners();
    }
  }

  void _setupSocketListeners() {
    if (socket == null) return;

    // Connection events
    socket!.on('connect', (_) {
      print('Connected to socket server');
      _isConnected = true;
      _safeNotifyListeners();
      onConnected?.call();
    });

    socket!.on('disconnect', (reason) {
      print('Disconnected from socket server. Reason: $reason');
      _isConnected = false;
      _safeNotifyListeners();
      onDisconnected?.call();
    });

    socket!.on('connect_error', (data) {
      print('Socket connection error: $data');
      _isConnected = false;
      _safeNotifyListeners();
      onConnectionError?.call(data.toString());
    });

    socket!.on('reconnect', (attemptNumber) {
      print('Socket reconnected after $attemptNumber attempts');
      _isConnected = true;
      _safeNotifyListeners();
      onConnected?.call();
    });

    socket!.on('reconnect_error', (error) {
      print('Socket reconnection error: $error');
    });

    socket!.on('reconnect_failed', (_) {
      print('Socket reconnection failed after maximum attempts');
      _isConnected = false;
      _safeNotifyListeners();
    });

    // Admin shutdown events - CRITICAL for student apps
    socket!.on('admin-shutdown', (data) {
      print('RECEIVED ADMIN SHUTDOWN NOTIFICATION: $data');
      
      if (data is Map<String, dynamic>) {
        final message = data['message'] ?? 'Server is shutting down';
        final reason = data['reason'] ?? 'unknown';
        
        print('Admin shutdown reason: $reason');
        print('Shutdown message: $message');
        
        // Call callback if registered
        onAdminShutdown?.call(data);
        
        // Auto-disconnect after receiving shutdown notification
        Future.delayed(Duration(seconds: 2), () {
          print('Auto-disconnecting due to admin shutdown...');
          disconnect();
        });
      }
    });

    // Force disconnect event - Server forcing client to disconnect
    socket!.on('force-disconnect', (data) {
      print('RECEIVED FORCE DISCONNECT: $data');
      
      if (data is Map<String, dynamic>) {
        final reason = data['reason'] ?? 'server_request';
        final message = data['message'] ?? 'You have been disconnected by the server';
        
        print('Force disconnect reason: $reason');
        print('Force disconnect message: $message');
        
        // Call callback if registered
        onForceDisconnect?.call(data);
        
        // Immediately disconnect
        disconnect();
      }
    });

    // User management events
    socket!.on('user-connected', (data) {
      print('User connected: $data');
      if (data is Map<String, dynamic>) {
        onUserStatusChanged?.call({
          ...data,
          'action': 'connected'
        });
      }
    });

    socket!.on('user-disconnected', (data) {
      print('User disconnected: $data');
      if (data is Map<String, dynamic>) {
        onUserStatusChanged?.call({
          ...data,
          'action': 'disconnected'
        });
      }
    });

    socket!.on('online-users', (data) {
      print('Online users update: $data');
      if (data is List) {
        onOnlineUsersUpdate?.call(data);
      }
    });

    socket!.on('user-status-update', (data) {
      print('User status update: $data');
      if (data is List) {
        onOnlineUsersUpdate?.call(data);
      }
    });

    // Student activity monitoring
    socket!.on('student-activity', (data) {
      print('Student activity: $data');
    });

    socket!.on('student-screen', (data) {
      print('Student screen share: ${data.toString().substring(0, 100)}...');
    });

    // Admin connection events
    socket!.on('admin-connected', (data) {
      print('Admin connected to server: $data');
    });

    // Heartbeat
    socket!.on('pong', (data) {
      // Handle pong response for keepalive
    });
  }

  void disconnect() {
    print('Disconnecting socket...');
    
    if (socket?.connected == true) {
      // Emit logout event before disconnecting if user info is available
      if (_currentUserEnrollNumber != null && _currentUserName != null) {
        emitUserLogout({
          'enrollNumber': _currentUserEnrollNumber!,
          'name': _currentUserName!,
          'role': _currentUserRole ?? 'student',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
      
      socket?.disconnect();
    }
    
    socket?.dispose();
    socket = null;
    _isConnected = false;
    _clearUserInfo();
    _safeNotifyListeners();
    print('Socket disconnected successfully');
  }

  void _clearUserInfo() {
    _currentUserRole = null;
    _currentUserEnrollNumber = null;
    _currentUserName = null;
  }

  void _setUserInfo(String enrollNumber, String name, String role) {
    _currentUserEnrollNumber = enrollNumber;
    _currentUserName = name;
    _currentUserRole = role;
  }

  // User authentication events
  void emitUserLogin(Map<String, dynamic> userData) {
    if (!_isConnected || socket == null) {
      print('Cannot emit user login - socket not connected');
      return;
    }
    
    print('Emitting user login: ${userData['name']} (${userData['role']})');
    
    // Store user info
    _setUserInfo(
      userData['enrollNumber'] ?? '',
      userData['name'] ?? '',
      userData['role'] ?? 'student'
    );
    
    socket!.emit('user-login', userData);
  }

  void emitUserLogout(Map<String, dynamic> userData) {
    if (!_isConnected || socket == null) {
      print('Cannot emit user logout - socket not connected');
      return;
    }
    
    print('Emitting user logout: ${userData['name']} (${userData['role']})');
    socket!.emit('user-logout', userData);
    
    // Clear stored user info after logout
    _clearUserInfo();
  }

  // Admin specific events
  void emitAdminLogin(Map<String, dynamic> adminData) {
    if (!_isConnected || socket == null) {
      print('Cannot emit admin login - socket not connected');
      return;
    }
    
    print('Emitting admin login: ${adminData['name']}');
    
    // Store admin info
    _setUserInfo(
      adminData['enrollNumber'] ?? '',
      adminData['name'] ?? '',
      'admin'
    );
    
    socket!.emit('admin-login', adminData);
  }

  void emitAdminLogout(Map<String, dynamic> adminData) {
    if (!_isConnected || socket == null) {
      print('Cannot emit admin logout - socket not connected');
      return;
    }
    
    print('Emitting admin logout: ${adminData['name']} - This will trigger server shutdown');
    socket!.emit('admin-logout', adminData);
    
    // Clear stored admin info after logout
    _clearUserInfo();
  }

  // Student activity events
  void emitCodeExecution(Map<String, dynamic> data) {
    if (!_isConnected || socket == null) {
      print('Cannot emit code execution - socket not connected');
      return;
    }
    
    socket!.emit('code-execution', data);
  }

  void emitScreenShare(String screenData) {
    if (!_isConnected || socket == null) {
      print('Cannot emit screen share - socket not connected');
      return;
    }
    
    socket!.emit('screen-share', screenData);
  }

  void emitUserActivity(Map<String, dynamic> activityData) {
    if (!_isConnected || socket == null) {
      print('Cannot emit user activity - socket not connected');
      return;
    }
    
    socket!.emit('user-activity', activityData);
  }

  // Request online users list
  void requestOnlineUsers() {
    if (!_isConnected || socket == null) {
      print('Cannot request online users - socket not connected');
      return;
    }
    
    print('Requesting online users from server');
    socket!.emit('get-online-users');
  }

  // Heartbeat/keepalive
  void sendHeartbeat() {
    if (!_isConnected || socket == null) {
      return;
    }
    
    socket!.emit('ping', {
      'timestamp': DateTime.now().toIso8601String(),
      'userRole': _currentUserRole,
      'enrollNumber': _currentUserEnrollNumber,
    });
  }

  // Callback registration methods
  void setOnConnectedCallback(Function() callback) {
    onConnected = callback;
  }

  void setOnDisconnectedCallback(Function() callback) {
    onDisconnected = callback;
  }

  void setOnConnectionErrorCallback(Function(String error) callback) {
    onConnectionError = callback;
  }

  void setOnAdminShutdownCallback(Function(Map<String, dynamic> data) callback) {
    onAdminShutdown = callback;
  }

  void setOnForceDisconnectCallback(Function(Map<String, dynamic> data) callback) {
    onForceDisconnect = callback;
  }

  void setOnOnlineUsersUpdateCallback(Function(List<dynamic> users) callback) {
    onOnlineUsersUpdate = callback;
  }

  void setOnUserStatusChangedCallback(Function(Map<String, dynamic> data) callback) {
    onUserStatusChanged = callback;
  }

  // Utility methods
  bool get isAdmin => _currentUserRole == 'admin';
  bool get isStudent => _currentUserRole == 'student';
  
  Map<String, dynamic> getCurrentUserInfo() {
    return {
      'enrollNumber': _currentUserEnrollNumber,
      'name': _currentUserName,
      'role': _currentUserRole,
      'isConnected': _isConnected,
    };
  }

  // Connection health check
  bool isHealthy() {
    return _isConnected && socket?.connected == true;
  }

  // Force reconnection
  Future<void> forceReconnect() async {
    print('Forcing socket reconnection...');
    
    if (socket?.connected == true) {
      socket!.disconnect();
    }
    
    // Wait a moment before reconnecting
    await Future.delayed(Duration(milliseconds: 500));
    
    if (socket != null) {
      socket!.connect();
    } else {
      await connect();
    }
  }

  // Get connection statistics
  Map<String, dynamic> getConnectionStats() {
    return {
      'isConnected': _isConnected,
      'socketId': socket?.id,
      'currentUser': {
        'enrollNumber': _currentUserEnrollNumber,
        'name': _currentUserName,
        'role': _currentUserRole,
      },
      'socketConnected': socket?.connected ?? false,
      'hasSocket': socket != null,
    };
  }

  @override
  void dispose() {
    print('Disposing SocketService...');
    
    // Mark as disposed to prevent further notifications
    _disposed = true;
    
    // Clear all callbacks
    onConnected = null;
    onDisconnected = null;
    onConnectionError = null;
    onAdminShutdown = null;
    onForceDisconnect = null;
    onOnlineUsersUpdate = null;
    onUserStatusChanged = null;
    
    // Disconnect socket without notifying listeners
    if (socket?.connected == true) {
      socket?.disconnect();
    }
    socket?.dispose();
    socket = null;
    _isConnected = false;
    _clearUserInfo();
    
    // Don't call notifyListeners() in dispose as it can cause errors
    super.dispose();
    print('SocketService disposed');
  }

  // Debug method to print current state
  void debugPrintState() {
    print('\n=== SOCKET SERVICE DEBUG INFO ===');
    print('Connected: $_isConnected');
    print('Disposed: $_disposed');
    print('Socket exists: ${socket != null}');
    print('Socket connected: ${socket?.connected}');
    print('Socket ID: ${socket?.id}');
    print('Current user: $_currentUserName ($_currentUserRole)');
    print('Enroll number: $_currentUserEnrollNumber');
    print('================================\n');
  }
}