import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService extends ChangeNotifier {
  IO.Socket? socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  void connect() {
    socket = IO.io('http://localhost:3000', 
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build()
    );

    socket?.connect();

    socket?.onConnect((_) {
      print('Connected to server');
      _isConnected = true;
      notifyListeners();
    });

    socket?.onDisconnect((_) {
      print('Disconnected from server');
      _isConnected = false;
      notifyListeners();
    });

    socket?.onConnectError((data) {
      print('Connection error: $data');
      _isConnected = false;
      notifyListeners();
    });
  }

  void disconnect() {
    socket?.disconnect();
    socket?.dispose();
    _isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}