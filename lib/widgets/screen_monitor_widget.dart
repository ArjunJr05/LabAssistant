import 'package:flutter/material.dart';
import '../services/screen_monitor_service.dart';
import '../services/screen_monitor_state.dart';
import 'student_bottom_nav.dart';

class ScreenMonitorWidget extends StatefulWidget {
  const ScreenMonitorWidget({super.key});

  @override
  State<ScreenMonitorWidget> createState() => _ScreenMonitorWidgetState();
}

class _ScreenMonitorWidgetState extends State<ScreenMonitorWidget> {
  late ScreenMonitorService _screenService;
  late ScreenMonitorState _monitorState;

  @override
  void initState() {
    super.initState();
    // Use the singleton instances
    _screenService = ScreenMonitorService();
    _monitorState = ScreenMonitorState();
    
    // Listen to frame updates with debug logging
    _screenService.frameStream.listen((frame) {
      print('ScreenMonitorWidget: Received frame from ${frame.clientId}, size: ${frame.imageData.length} bytes, dimensions: ${frame.width}x${frame.height}');
      _monitorState.updateFrame(frame.clientId, frame.imageData);
      print('ScreenMonitorWidget: Frame cached for ${frame.clientId}, total cached: ${_monitorState.frameCache.length}');
      print('ScreenMonitorWidget: Triggering UI rebuild...');
    }, onError: (error) {
      print('ScreenMonitorWidget: Frame stream error: $error');
    });
    
    // Listen to connection status
    _screenService.connectionStatusStream.listen((status) {
      print('ScreenMonitorWidget: Connection status: $status');
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _monitorState,
      builder: (context, child) {
        if (_monitorState.fullscreenClientId != null) {
          return _buildFullscreenView();
        }

        return Column(
          children: [
            _buildControlPanel(),
            const SizedBox(height: 16),
            Expanded(child: _buildScreenGrid()),
            StudentBottomNav(
              onStudentTap: _openFullscreen,
              selectedClientId: _monitorState.fullscreenClientId,
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.monitor, color: Color(0xFF3B82F6)),
          const SizedBox(width: 8),
          const Text(
            'Live Screen Monitoring',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const Spacer(),
          StreamBuilder<String>(
            stream: _screenService.connectionStatusStream,
            builder: (context, snapshot) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                    const SizedBox(width: 6),
                    Text(
                      snapshot.data ?? 'Ready',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScreenGrid() {
    return StreamBuilder<List<ClientInfo>>(
      stream: _screenService.clientsStream,
      builder: (context, snapshot) {
        final clients = snapshot.data ?? [];
        
        if (clients.isEmpty) {
          return _buildEmptyState();
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _calculateGridColumns(clients.length),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 16 / 9, // Standard screen ratio
          ),
          itemCount: clients.length,
          itemBuilder: (context, index) {
            final client = clients[index];
            return _buildScreenTile(client);
          },
        );
      },
    );
  }

  Widget _buildScreenTile(ClientInfo client) {
    final hasFrame = _monitorState.frameCache.containsKey(client.id);
    
    return GestureDetector(
      onTap: () => _openFullscreen(client.id),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              offset: Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Column(
          children: [
            // Screen display area
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Stack(
                  children: [
                    // Screen content
                    hasFrame
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: Image.memory(
                              _monitorState.frameCache[client.id]!,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              width: double.infinity,
                              height: double.infinity,
                              filterQuality: FilterQuality.medium,
                              key: ValueKey('${client.id}_frame'),
                            ),
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.monitor_outlined,
                                  color: Color(0xFF64748B),
                                  size: 48,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Connecting...',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                    
                    // Fullscreen button overlay
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => _openFullscreen(client.id),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.fullscreen,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Client info footer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: client.isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          client.computerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          client.userName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        client.ipAddress,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          client.captureResolution,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${client.fps} FPS',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullscreenView() {
    final client = _screenService.connectedClients.firstWhere((c) => c.id == _monitorState.fullscreenClientId);
    final hasFrame = _monitorState.frameCache.containsKey(_monitorState.fullscreenClientId);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: Container(),
      ),
      body: Stack(
        children: [
          // Full screen content
          SizedBox.expand(
            child: hasFrame
                ? InteractiveViewer(
                    panEnabled: true,
                    scaleEnabled: true,
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Image.memory(
                      _monitorState.frameCache[_monitorState.fullscreenClientId]!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.medium,
                      cacheWidth: null,
                      cacheHeight: null,
                    ),
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Loading screen...',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
          ),
          
          // Floating controls overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${client.computerName} - ${client.userName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _monitorState.setFullscreenClient(null),
                    icon: const Icon(Icons.minimize, color: Colors.white),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Icons.desktop_windows_outlined,
              size: 64,
              color: Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No screens connected',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect to client computers to start monitoring',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
                    SizedBox(width: 8),
                    Text(
                      'Run the Screen Capture Agent on client PCs',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _calculateGridColumns(int clientCount) {
    if (clientCount <= 1) return 1;
    if (clientCount <= 4) return 2;
    if (clientCount <= 9) return 3;
    return 4;
  }


  void _openFullscreen(String clientId) {
    _monitorState.setFullscreenClient(clientId);
  }
}
