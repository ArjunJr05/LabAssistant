import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/screen_monitor_service.dart';

class ScreenMonitorWidget extends StatefulWidget {
  const ScreenMonitorWidget({super.key});

  @override
  State<ScreenMonitorWidget> createState() => _ScreenMonitorWidgetState();
}

class _ScreenMonitorWidgetState extends State<ScreenMonitorWidget> {
  late ScreenMonitorService _screenService;
  final Map<String, Uint8List> _frameCache = {};
  String? _fullscreenClientId;
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _screenService = ScreenMonitorService();
    _screenService.startService();
    
    // Listen to frame updates
    _screenService.frameStream.listen((frame) {
      if (mounted) {
        setState(() {
          _frameCache[frame.clientId] = frame.imageData;
        });
      }
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_fullscreenClientId != null) {
      return _buildFullscreenView();
    }

    return Column(
      children: [
        _buildControlPanel(),
        const SizedBox(height: 16),
        Expanded(child: _buildScreenGrid()),
      ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor, color: Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              const Text(
                'Screen Monitoring Control',
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipController,
                  decoration: InputDecoration(
                    hintText: 'Enter client IP address (e.g., 192.168.1.100)',
                    prefixIcon: const Icon(Icons.computer, color: Color(0xFF64748B)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _connectToManualIP,
                icon: const Icon(Icons.add_link, size: 18),
                label: const Text('Connect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _refreshDiscovery,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Discover'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
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
    final hasFrame = _frameCache.containsKey(client.id);
    
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
                child: hasFrame
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image.memory(
                          _frameCache[client.id]!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
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
    final client = _screenService.connectedClients
        .firstWhere((c) => c.id == _fullscreenClientId);
    final hasFrame = _frameCache.containsKey(_fullscreenClientId);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.8),
        foregroundColor: Colors.white,
        title: Text('${client.computerName} - ${client.userName}'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _fullscreenClientId = null),
            icon: const Icon(Icons.fullscreen_exit),
          ),
        ],
      ),
      body: Center(
        child: hasFrame
            ? InteractiveViewer(
                child: Image.memory(
                  _frameCache[_fullscreenClientId]!,
                  fit: BoxFit.contain,
                ),
              )
            : const Column(
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

  void _connectToManualIP() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;

    final success = await _screenService.connectToClient(ip);
    if (success && mounted) {
      _ipController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to $ip'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect to $ip'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _refreshDiscovery() {
    _screenService.stopService();
    _screenService.startService();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Discovering clients on network...'),
          backgroundColor: Color(0xFF3B82F6),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _openFullscreen(String clientId) {
    setState(() {
      _fullscreenClientId = clientId;
    });
  }
}
