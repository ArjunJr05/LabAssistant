import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

class ScreenFrame {
  final String clientId;
  final Uint8List imageData;
  final int width;
  final int height;
  final DateTime timestamp;
  final String format;

  ScreenFrame({
    required this.clientId,
    required this.imageData,
    required this.width,
    required this.height,
    required this.timestamp,
    required this.format,
  });
}

class ClientInfo {
  final String id;
  final String computerName;
  final String userName;
  final String ipAddress;
  final String resolution;
  final String captureResolution;
  final int fps;
  final bool isConnected;
  final DateTime lastSeen;

  ClientInfo({
    required this.id,
    required this.computerName,
    required this.userName,
    required this.ipAddress,
    required this.resolution,
    required this.captureResolution,
    required this.fps,
    required this.isConnected,
    required this.lastSeen,
  });

  ClientInfo copyWith({
    String? id,
    String? computerName,
    String? userName,
    String? ipAddress,
    String? resolution,
    String? captureResolution,
    int? fps,
    bool? isConnected,
    DateTime? lastSeen,
  }) {
    return ClientInfo(
      id: id ?? this.id,
      computerName: computerName ?? this.computerName,
      userName: userName ?? this.userName,
      ipAddress: ipAddress ?? this.ipAddress,
      resolution: resolution ?? this.resolution,
      captureResolution: captureResolution ?? this.captureResolution,
      fps: fps ?? this.fps,
      isConnected: isConnected ?? this.isConnected,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

class ScreenMonitorService {
  static final ScreenMonitorService _instance = ScreenMonitorService._internal();
  factory ScreenMonitorService() => _instance;
  ScreenMonitorService._internal();

  final Map<String, WebSocketChannel> _connections = {};
  final Map<String, ClientInfo> _clients = {};
  final Map<String, ScreenFrame> _latestFrames = {};
  
  final StreamController<List<ClientInfo>> _clientsController = StreamController<List<ClientInfo>>.broadcast();
  final StreamController<ScreenFrame> _frameController = StreamController<ScreenFrame>.broadcast();
  final StreamController<String> _connectionStatusController = StreamController<String>.broadcast();

  Stream<List<ClientInfo>> get clientsStream => _clientsController.stream;
  Stream<ScreenFrame> get frameStream => _frameController.stream;
  Stream<String> get connectionStatusStream => _connectionStatusController.stream;

  List<ClientInfo> get connectedClients => _clients.values.where((c) => c.isConnected).toList();
  
  Timer? _discoveryTimer;
  Timer? _heartbeatTimer;

  void startService() {
    print('Starting Screen Monitor Service...');
    
    // Start LAN discovery
    _startLANDiscovery();
    
    // Start heartbeat to check client connections
    _startHeartbeat();
    
    _connectionStatusController.add('Screen monitoring service started');
  }

  void stopService() {
    print('Stopping Screen Monitor Service...');
    
    _discoveryTimer?.cancel();
    _heartbeatTimer?.cancel();
    
    // Disconnect all clients
    for (var connection in _connections.values) {
      connection.sink.close();
    }
    _connections.clear();
    _clients.clear();
    _latestFrames.clear();
    
    _clientsController.add([]);
    _connectionStatusController.add('Screen monitoring service stopped');
  }

  Future<bool> connectToClient(String ipAddress, {int port = 8765}) async {
    final clientId = '$ipAddress:$port';
    
    if (_connections.containsKey(clientId)) {
      print('Already connected to $clientId');
      return true;
    }

    try {
      print('Connecting to client at $ipAddress:$port...');
      
      final uri = Uri.parse('ws://$ipAddress:$port/');
      final channel = IOWebSocketChannel.connect(uri);
      
      _connections[clientId] = channel;
      
      // Listen for messages
      channel.stream.listen(
        (message) => _handleMessage(clientId, message),
        onError: (error) => _handleConnectionError(clientId, error),
        onDone: () => _handleConnectionClosed(clientId),
      );
      
      // Send initial ping
      _sendMessage(clientId, {'type': 'ping'});
      
      _connectionStatusController.add('Connected to $ipAddress');
      return true;
      
    } catch (e) {
      print('Failed to connect to $clientId: $e');
      _connectionStatusController.add('Failed to connect to $ipAddress: $e');
      return false;
    }
  }

  void disconnectClient(String clientId) {
    final connection = _connections[clientId];
    if (connection != null) {
      connection.sink.close();
      _connections.remove(clientId);
    }
    
    if (_clients.containsKey(clientId)) {
      _clients[clientId] = _clients[clientId]!.copyWith(isConnected: false);
      _clientsController.add(connectedClients);
    }
    
    _latestFrames.remove(clientId);
  }

  void _handleMessage(String clientId, dynamic message) {
    try {
      final data = json.decode(message);
      final type = data['type'];
      
      switch (type) {
        case 'handshake':
          _handleHandshake(clientId, data);
          break;
        case 'frame':
          _handleFrame(clientId, data);
          break;
        case 'pong':
          _handlePong(clientId);
          break;
        default:
          print('Unknown message type: $type');
      }
    } catch (e) {
      print('Error handling message from $clientId: $e');
    }
  }

  void _handleHandshake(String clientId, Map<String, dynamic> data) {
    final clientInfo = data['clientInfo'];
    final ipAddress = clientId.split(':')[0];
    
    final client = ClientInfo(
      id: clientId,
      computerName: clientInfo['computerName'] ?? 'Unknown',
      userName: clientInfo['userName'] ?? 'Unknown',
      ipAddress: ipAddress,
      resolution: clientInfo['resolution'] ?? 'Unknown',
      captureResolution: clientInfo['captureResolution'] ?? 'Unknown',
      fps: clientInfo['fps'] ?? 10,
      isConnected: true,
      lastSeen: DateTime.now(),
    );
    
    _clients[clientId] = client;
    _clientsController.add(connectedClients);
    
    print('Client connected: ${client.computerName} (${client.userName}) at $ipAddress');
    _connectionStatusController.add('Client ${client.computerName} connected');
  }

  void _handleFrame(String clientId, Map<String, dynamic> data) {
    try {
      final base64Data = data['data'] as String;
      final imageData = base64Decode(base64Data);
      
      final frame = ScreenFrame(
        clientId: clientId,
        imageData: imageData,
        width: data['width'] ?? 1280,
        height: data['height'] ?? 720,
        timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch),
        format: data['format'] ?? 'jpeg',
      );
      
      _latestFrames[clientId] = frame;
      _frameController.add(frame);
      
      // Update last seen
      if (_clients.containsKey(clientId)) {
        _clients[clientId] = _clients[clientId]!.copyWith(lastSeen: DateTime.now());
      }
      
    } catch (e) {
      print('Error processing frame from $clientId: $e');
    }
  }

  void _handlePong(String clientId) {
    if (_clients.containsKey(clientId)) {
      _clients[clientId] = _clients[clientId]!.copyWith(lastSeen: DateTime.now());
    }
  }

  void _handleConnectionError(String clientId, dynamic error) {
    print('Connection error with $clientId: $error');
    disconnectClient(clientId);
    _connectionStatusController.add('Connection lost with ${clientId.split(':')[0]}');
  }

  void _handleConnectionClosed(String clientId) {
    print('Connection closed with $clientId');
    disconnectClient(clientId);
  }

  void _sendMessage(String clientId, Map<String, dynamic> message) {
    final connection = _connections[clientId];
    if (connection != null) {
      try {
        connection.sink.add(json.encode(message));
      } catch (e) {
        print('Error sending message to $clientId: $e');
      }
    }
  }

  void _startLANDiscovery() {
    _discoveryTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _discoverClientsOnLAN();
    });
    
    // Initial discovery
    _discoverClientsOnLAN();
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _sendHeartbeat();
      _checkClientTimeouts();
    });
  }

  void _sendHeartbeat() {
    for (final clientId in _connections.keys) {
      _sendMessage(clientId, {'type': 'ping'});
    }
  }

  void _checkClientTimeouts() {
    final now = DateTime.now();
    final timeoutDuration = const Duration(seconds: 30);
    
    final timedOutClients = <String>[];
    
    for (final entry in _clients.entries) {
      if (entry.value.isConnected && 
          now.difference(entry.value.lastSeen) > timeoutDuration) {
        timedOutClients.add(entry.key);
      }
    }
    
    for (final clientId in timedOutClients) {
      print('Client timeout: $clientId');
      disconnectClient(clientId);
    }
  }

  Future<void> _discoverClientsOnLAN() async {
    // Simple LAN discovery by trying common IP ranges
    // In a production environment, you might want to use more sophisticated discovery
    
    final baseIP = await _getLocalNetworkBase();
    if (baseIP == null) return;
    
    print('Discovering clients on network: $baseIP.x');
    
    // Try IPs from .1 to .254
    for (int i = 1; i <= 254; i++) {
      final ip = '$baseIP.$i';
      
      // Skip if already connected
      if (_connections.containsKey('$ip:8765')) continue;
      
      // Try to connect (non-blocking)
      _tryConnectToIP(ip);
      
      // Add small delay to avoid overwhelming the network
      if (i % 10 == 0) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  Future<void> _tryConnectToIP(String ip) async {
    try {
      // Quick connection test with timeout
      final result = await connectToClient(ip).timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
      
      if (!result) {
        // Connection failed, remove from clients if it was there
        final clientId = '$ip:8765';
        if (_clients.containsKey(clientId)) {
          _clients[clientId] = _clients[clientId]!.copyWith(isConnected: false);
        }
      }
    } catch (e) {
      // Ignore connection failures during discovery
    }
  }

  Future<String?> _getLocalNetworkBase() async {
    try {
      // This is a simplified approach - in production you might want to use
      // more sophisticated network interface detection
      return '192.168.1'; // Most common home network range
    } catch (e) {
      print('Error getting local network base: $e');
      return null;
    }
  }

  ScreenFrame? getLatestFrame(String clientId) {
    return _latestFrames[clientId];
  }

  void changeClientQuality(String clientId, int quality) {
    _sendMessage(clientId, {
      'type': 'changeQuality',
      'quality': quality,
    });
  }

  void changeClientFPS(String clientId, int fps) {
    _sendMessage(clientId, {
      'type': 'changeFPS',
      'fps': fps,
    });
  }

  void dispose() {
    stopService();
    _clientsController.close();
    _frameController.close();
    _connectionStatusController.close();
  }
}
