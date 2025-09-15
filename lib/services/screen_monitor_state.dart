import 'dart:typed_data';
import 'package:flutter/material.dart';

class ScreenMonitorState extends ChangeNotifier {
  final Map<String, Uint8List> _frameCache = {};
  String? _fullscreenClientId;

  Map<String, Uint8List> get frameCache => _frameCache;
  String? get fullscreenClientId => _fullscreenClientId;

  void updateFrame(String clientId, Uint8List frameData) {
    _frameCache[clientId] = frameData;
    print('ScreenMonitorState: Updated frame for client $clientId, cache size: ${_frameCache.length}');
    notifyListeners();
  }

  void removeClient(String clientId) {
    _frameCache.remove(clientId);
    if (_fullscreenClientId == clientId) {
      _fullscreenClientId = null;
    }
    print('ScreenMonitorState: Removed client $clientId, remaining cache size: ${_frameCache.length}');
    notifyListeners();
  }

  // Updated method name for consistency
  void enterFullscreen(String clientId) {
    _fullscreenClientId = clientId;
    print('ScreenMonitorState: Entered fullscreen mode for client $clientId');
    notifyListeners();
  }

  // New method to exit fullscreen (returns to grid view)
  void exitFullscreen() {
    _fullscreenClientId = null;
    notifyListeners();
  }

  // Legacy method for backward compatibility (deprecated)
  @Deprecated('Use enterFullscreen instead')
  void setFullscreenClient(String? clientId) {
    if (clientId == null) {
      exitFullscreen();
    } else {
      enterFullscreen(clientId);
    }
  }

  void clearCache() {
    final previousSize = _frameCache.length;
    _frameCache.clear();
    _fullscreenClientId = null;
    print('ScreenMonitorState: Cleared cache (was $previousSize items)');
    notifyListeners();
  }

  bool hasFrame(String clientId) {
    return _frameCache.containsKey(clientId);
  }

  Uint8List? getFrame(String clientId) {
    return _frameCache[clientId];
  }

  bool get isFullscreen => _fullscreenClientId != null;

  int get connectedClientsCount => _frameCache.length;
}