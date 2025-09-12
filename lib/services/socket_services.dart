// lib/services/socket_service.dart
// Optimized socket service with batch updates and reduced latency

import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'config_service.dart';
import 'dart:async';

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
  
  // Student specific callbacks - Optimized for batch updates
  Function(List<dynamic> users)? onOnlineUsersUpdate;
  Function(List<dynamic> updates)? onUserStatusBatch; // New batch callback
  Function(Map<String, dynamic> data)? onUserStatusChanged;

  // Batch update management for reduced latency
  Timer? _batchTimer;
  final List<Map<String, dynamic>> _pendingUserUpdates = [];
  static const Duration _batchDelay = Duration(milliseconds: 100);

  bool get isConnected => _isConnected;
  String? get currentUserRole => _currentUserRole;
  String? get currentUserEnrollNumber => _currentUserEnrollNumber;
  String? get currentUserName => _currentUserName;

  void _safeNotifyListeners() {
    if (!_disposed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) {
          notifyListeners();
        }
      });
    }
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
        'timeout': 10000, // Reduced from 20000
        'reconnection': true,
        'reconnectionAttempts': 3, // Reduced from 5
        'reconnectionDelay': 500, // Reduced from 1000
        'forceNew': true,
      });

      _setupOptimizedSocketListeners();
      socket!.connect();
      
    } catch (e) {
      print('Error setting up socket connection: $e');
      _isConnected = false;
      _safeNotifyListeners();
    }
  }

  void _setupOptimizedSocketListeners() {
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
      _flushPendingUpdates(); // Flush any pending updates
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

    // CRITICAL: Admin shutdown events
    socket!.on('admin-shutdown', (data) {
      print('RECEIVED ADMIN SHUTDOWN NOTIFICATION: $data');
      
      if (data is Map<String, dynamic>) {
        final message = data['message'] ?? 'Server is shutting down';
        final reason = data['reason'] ?? 'unknown';
        
        print('Admin shutdown reason: $reason');
        print('Shutdown message: $message');
        
        onAdminShutdown?.call(data);
        
        // Immediate disconnect for admin shutdown
        Future.delayed(Duration(milliseconds: 500), () {
          print('Auto-disconnecting due to admin shutdown...');
          disconnect();
        });
      }
    });

    // Force disconnect event
    socket!.on('force-disconnect', (data) {
      print('RECEIVED FORCE DISCONNECT: $data');
      
      if (data is Map<String, dynamic>) {
        final reason = data['reason'] ?? 'server_request';
        final message = data['message'] ?? 'You have been disconnected by the server';
        
        print('Force disconnect reason: $reason');
        print('Force disconnect message: $message');
        
        onForceDisconnect?.call(data);
        disconnect();
      }
    });

    // OPTIMIZED: Batch user status updates
    socket!.on('user-status-batch', (data) {
      print('Received batch user status update');
      if (data is List) {
        onUserStatusBatch?.call(data);
      }
    });

    // OPTIMIZED: Bulk online users update
    socket!.on('online-users-bulk', (data) {
      print('Received bulk online users update: ${data is List ? data.length : 0} users');
      if (data is List) {
        onOnlineUsersUpdate?.call(data);
      }
    });

    // Individual user events - now batched for admin dashboard
    socket!.on('user-connected', (data) {
      print('User connected: ${data?['name']}');
      if (data is Map<String, dynamic>) {
        _addToBatch({
          ...data,
          'action': 'connected',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });

    socket!.on('user-disconnected', (data) {
      print('User disconnected: ${data?['name']}');
      if (data is Map<String, dynamic>) {
        _addToBatch({
          ...data,
          'action': 'disconnected',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });

    // Legacy support - still call individual callback for backward compatibility
    socket!.on('online-users', (data) {
      print('Online users update (legacy)');
      if (data is List) {
        onOnlineUsersUpdate?.call(data);
      }
    });

    socket!.on('user-status-update', (data) {
      print('User status update (legacy)');
      if (data is List) {
        onOnlineUsersUpdate?.call(data);
      }
    });

    // Student activity monitoring - optimized
    socket!.on('student-activity', (data) {
      if (data != null) {
        print('Student activity received');
      }
    });

    socket!.on('student-screen', (data) {
      if (data != null) {
        print('Student screen share received');
      }
    });

    // Admin connection events
    socket!.on('admin-connected', (data) {
      print('Admin connected to server: ${data?['name']}');
    });

    // Optimized heartbeat response
    socket!.on('pong', (data) {
      // Handle pong response for keepalive - no logging to reduce noise
    });
  }

  // Batch update management for reduced UI rebuilds
  void _addToBatch(Map<String, dynamic> update) {
    _pendingUserUpdates.add(update);
    
    // Cancel existing timer
    _batchTimer?.cancel();
    
    // Set new timer
    _batchTimer = Timer(_batchDelay, () {
      _flushPendingUpdates();
    });
  }

  void _flushPendingUpdates() {
    if (_pendingUserUpdates.isNotEmpty) {
      final updates = List<Map<String, dynamic>>.from(_pendingUserUpdates);
      _pendingUserUpdates.clear();
      
      print('Flushing ${updates.length} batched user updates');
      
      // Call batch callback if available
      onUserStatusBatch?.call(updates);
      
      // Also call individual callbacks for backward compatibility
      for (final update in updates) {
        onUserStatusChanged?.call(update);
      }
    }
    _batchTimer = null;
  }

  
  void disconnect() {
    print('Disconnecting socket...');
    
    // Flush any pending updates before disconnecting
    _flushPendingUpdates();
    _batchTimer?.cancel();
    
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

  // OPTIMIZED: User authentication events with minimal data
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
    
    // Emit with timestamp for latency tracking
    socket!.emit('user-login', {
      ...userData,
      'clientTimestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void emitUserLogout(Map<String, dynamic> userData) {
    if (socket == null) {
      print('Cannot emit user logout - socket not available');
      return;
    }
    
    print('Emitting user logout: ${userData['name']} (${userData['role']})');
    
    // Emit even if not connected for cleanup
    socket!.emit('user-logout', {
      ...userData,
      'clientTimestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
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
    
    socket!.emit('admin-login', {
      ...adminData,
      'clientTimestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void emitAdminLogout(Map<String, dynamic> adminData) {
    if (!_isConnected || socket == null) {
      print('Cannot emit admin logout - socket not connected');
      return;
    }
    
    print('Emitting admin logout: ${adminData['name']} - This will trigger server shutdown');
    socket!.emit('admin-logout', {
      ...adminData,
      'clientTimestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    // Clear stored admin info after logout
    _clearUserInfo();
  }

  // Optimized activity events
  void emitCodeExecution(Map<String, dynamic> data) {
    if (!_isConnected || socket == null) {
      print('Cannot emit code execution - socket not connected');
      return;
    }
    
    socket!.emit('code-execution', {
      ...data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void emitScreenShare(String screenData) {
    if (!_isConnected || socket == null) {
      print('Cannot emit screen share - socket not connected');
      return;
    }
    
    socket!.emit('screen-share', {
      'data': screenData,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'user': _currentUserEnrollNumber,
    });
  }

  void emitUserActivity(Map<String, dynamic> activityData) {
    if (!_isConnected || socket == null) {
      print('Cannot emit user activity - socket not connected');
      return;
    }
    
    socket!.emit('user-activity', {
      ...activityData,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Request online users list with immediate response preference
  void requestOnlineUsers() {
    if (!_isConnected || socket == null) {
      print('Cannot request online users - socket not connected');
      return;
    }
    
    print('Requesting online users from server');
    socket!.emit('get-online-users', {
      'requestId': DateTime.now().millisecondsSinceEpoch,
      'preferBulk': true, // Indicate preference for bulk response
    });
  }

  // Optimized heartbeat with reduced frequency
  void sendHeartbeat() {
    if (!_isConnected || socket == null) {
      return;
    }
    
    socket!.emit('ping', {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'userRole': _currentUserRole,
      'enrollNumber': _currentUserEnrollNumber,
    });
  }

  // ENHANCED: Callback registration methods with batch support
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

  // NEW: Batch update callback registration
  void setOnUserStatusBatchCallback(Function(List<dynamic> updates) callback) {
    onUserStatusBatch = callback;
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

  // Optimized reconnection
  Future<void> forceReconnect() async {
    print('Forcing socket reconnection...');
    
    // Flush pending updates before reconnecting
    _flushPendingUpdates();
    
    if (socket?.connected == true) {
      socket!.disconnect();
    }
    
    // Shorter wait time
    await Future.delayed(Duration(milliseconds: 200));
    
    if (socket != null) {
      socket!.connect();
    } else {
      await connect();
    }
  }

  // Enhanced connection statistics
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
      'pendingUpdates': _pendingUserUpdates.length,
      'batchTimerActive': _batchTimer?.isActive ?? false,
    };
  }

  // Performance monitoring
  int getPendingUpdateCount() {
    return _pendingUserUpdates.length;
  }

  void clearPendingUpdates() {
    _pendingUserUpdates.clear();
    _batchTimer?.cancel();
    _batchTimer = null;
  }

  @override
  void dispose() {
    print('Disposing SocketService...');
    
    // Mark as disposed to prevent further notifications
    _disposed = true;
    
    // Flush any pending updates
    _flushPendingUpdates();
    _batchTimer?.cancel();
    
    // Clear all callbacks
    onConnected = null;
    onDisconnected = null;
    onConnectionError = null;
    onAdminShutdown = null;
    onForceDisconnect = null;
    onOnlineUsersUpdate = null;
    onUserStatusChanged = null;
    onUserStatusBatch = null;
    
    // Disconnect socket without notifying listeners
    if (socket?.connected == true) {
      socket?.disconnect();
    }
    socket?.dispose();
    socket = null;
    _isConnected = false;
    _clearUserInfo();
    
    super.dispose();
    print('SocketService disposed');
  }

  // Enhanced debug method
  void debugPrintState() {
    print('\n=== SOCKET SERVICE DEBUG INFO ===');
    print('Connected: $_isConnected');
    print('Disposed: $_disposed');
    print('Socket exists: ${socket != null}');
    print('Socket connected: ${socket?.connected}');
    print('Socket ID: ${socket?.id}');
    print('Current user: $_currentUserName ($_currentUserRole)');
    print('Enroll number: $_currentUserEnrollNumber');
    print('Pending updates: ${_pendingUserUpdates.length}');
    print('Batch timer active: ${_batchTimer?.isActive ?? false}');
    print('================================\n');
  }
}