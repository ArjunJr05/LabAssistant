import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'config_service.dart';

class SocketService extends ChangeNotifier {
  IO.Socket? socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (socket?.connected == true) {
      print('Socket already connected');
      return;
    }

    final serverUrl = await ConfigService.getServerUrl();
    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket!.connect();

    socket!.on('connect', (_) {
      print('Connected to server');
      _emitUserLogin();
      _isConnected = true;
      notifyListeners();
    });

    socket!.on('disconnect', (_) {
      print('Disconnected from server');
      _isConnected = false;
      notifyListeners();
    });

    socket!.on('connect_error', (data) {
      print('Connection error: $data');
      _isConnected = false;
      notifyListeners();
    });
  }

  void _emitUserLogin() {
    // This will be called when we need to register the user with the socket
    // Implementation will be added when user logs in
  }

  void disconnect() {
    socket?.disconnect();
    socket?.dispose();
    _isConnected = false;
    notifyListeners();
  }

  void emitCodeExecution(Map<String, dynamic> data) {
    socket?.emit('code-execution', data);
  }

  void emitScreenShare(String screenData) {
    socket?.emit('screen-share', screenData);
  }

  void emitUserLogin(Map<String, dynamic> userData) {
    print(' Emitting user login: ${userData['name']}');
    socket?.emit('user-login', userData);
  }

  void requestOnlineUsers() {
    print(' Requesting online users from server');
    socket?.emit('get-online-users');
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}