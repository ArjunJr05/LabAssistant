import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class ScreenMonitorState extends ChangeNotifier {
  static final ScreenMonitorState _instance = ScreenMonitorState._internal();
  factory ScreenMonitorState() => _instance;
  ScreenMonitorState._internal();

  final Map<String, Uint8List> _frameCache = {};
  String? _fullscreenClientId;
  
  Map<String, Uint8List> get frameCache => _frameCache;
  String? get fullscreenClientId => _fullscreenClientId;
  
  void updateFrame(String clientId, Uint8List imageData) {
    _frameCache[clientId] = imageData;
    notifyListeners();
  }
  
  void setFullscreenClient(String? clientId) {
    _fullscreenClientId = clientId;
    notifyListeners();
  }
  
  void clearFrameCache() {
    _frameCache.clear();
    notifyListeners();
  }
  
  void removeFrame(String clientId) {
    _frameCache.remove(clientId);
    notifyListeners();
  }
}
