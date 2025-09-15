import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/screen_monitor_service.dart';
import '../services/screen_monitor_state.dart';

class LiveMonitoringTab extends StatefulWidget {
  final List<User> onlineUsers;

  const LiveMonitoringTab({super.key, required this.onlineUsers});

  @override
  State<LiveMonitoringTab> createState() => _LiveMonitoringTabState();
}

class _LiveMonitoringTabState extends State<LiveMonitoringTab> {
  late ScreenMonitorService _screenService;
  late ScreenMonitorState _monitorState;

  @override
  void initState() {
    super.initState();
    _screenService = ScreenMonitorService();
    _monitorState = ScreenMonitorState();
    
    // Listen to frame updates
    _screenService.frameStream.listen((frame) {
      print('LiveMonitoringTab: Received frame from ${frame.clientId}, size: ${frame.imageData.length} bytes');
      _monitorState.updateFrame(frame.clientId, frame.imageData);
    }, onError: (error) {
      print('LiveMonitoringTab: Frame stream error: $error');
    });
    
<<<<<<< HEAD
    // Listen to client connections
    _screenService.clientsStream.listen((clients) {
      print('LiveMonitoringTab: Connected clients: ${clients.map((c) => '${c.id}@${c.ipAddress}').join(', ')}');
=======
    // Listen to client connections and disconnections
    _screenService.clientsStream.listen((clients) {
      print('LiveMonitoringTab: Connected clients: ${clients.map((c) => '${c.id}@${c.ipAddress}').join(', ')}');
      
      // Clean up frames for disconnected clients
      final connectedClientIds = clients.map((c) => c.id).toSet();
      final cachedClientIds = _monitorState.frameCache.keys.toSet();
      
      // Remove frames for clients that are no longer connected
      for (String cachedId in cachedClientIds) {
        if (!connectedClientIds.contains(cachedId)) {
          _monitorState.removeClient(cachedId);
        }
      }
>>>>>>> 041c61fd020faca8a541e97373a304810967dde2
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _monitorState,
      builder: (context, child) {
        // Show the main live monitoring interface
        return Column(
          children: [
            // Header with online students count
            _buildHeader(),
            const SizedBox(height: 16),
            
            // Main content area
            Expanded(
              child: Row(
                children: [
                  // Left side: Student list
                  Expanded(
                    flex: 1,
                    child: _buildStudentList(),
                  ),
                  const SizedBox(width: 16),
                  
                  // Right panel - Screen monitoring
                  Expanded(
                    flex: 2,
                    child: _buildMonitoringPanel(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    final onlineStudents = widget.onlineUsers.where((user) => user.role == 'student').toList();
    final connectedClients = _screenService.connectedClients;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.3),
            offset: const Offset(0, 8),
            blurRadius: 24,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.live_tv_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live Monitoring',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${onlineStudents.length} students online • ${connectedClients.length} screens connected',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    final onlineStudents = widget.onlineUsers.where((user) => user.role == 'student').toList();
    final connectedClients = _screenService.connectedClients;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // List header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.people_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Online Students',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${onlineStudents.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Student list
          Expanded(
            child: onlineStudents.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off_rounded,
                          size: 48,
                          color: Color(0xFF94A3B8),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No students online',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: onlineStudents.length,
                    itemBuilder: (context, index) {
                      final student = onlineStudents[index];
                      final isConnected = connectedClients.any((client) => 
                          client.userName.toLowerCase() == student.name.toLowerCase() ||
                          client.computerName.toLowerCase().contains(student.enrollNumber.toLowerCase()));
                      
                      return _buildStudentTile(student, isConnected);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTile(User student, bool isConnected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _connectToStudent(student),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isConnected ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isConnected ? const Color(0xFF3B82F6).withOpacity(0.2) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isConnected ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Student info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isConnected ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        student.enrollNumber,
                        style: TextStyle(
                          fontSize: 12,
                          color: isConnected ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Status indicator
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isConnected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                
                // Monitor icon
                if (isConnected) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.monitor_rounded,
                    size: 16,
                    color: Color(0xFF3B82F6),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildFullscreenView() {
    final connectedClients = _screenService.connectedClients;
    final client = connectedClients.firstWhere(
      (c) => c.id == _monitorState.fullscreenClientId,
      orElse: () => ClientInfo(
        id: '',
        computerName: 'Unknown',
        userName: 'Unknown',
        ipAddress: '',
        resolution: '',
        captureResolution: '',
        fps: 0,
        isConnected: false,
        lastSeen: DateTime.now(),
      ),
    );
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
          // Fullscreen image
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
                      key: ValueKey('fullscreen_${_monitorState.fullscreenClientId}'),
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
          
          // Floating controls
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
=======
>>>>>>> 041c61fd020faca8a541e97373a304810967dde2

  void _connectToStudent(User student) async {
    print('LiveMonitoringTab: Attempting to connect to student: ${student.name} with IP: ${student.ipAddress}');
    
    if (student.ipAddress == null || student.ipAddress!.isEmpty || student.ipAddress == 'unknown') {
      _showSnackBar('No IP address available for ${student.name}', Colors.orange);
      return;
    }

    // Check if already connected to this IP
    final existingClient = _screenService.connectedClients.firstWhere(
      (client) => client.ipAddress == student.ipAddress,
      orElse: () => ClientInfo(
        id: '',
        computerName: '',
        userName: '',
        ipAddress: '',
        resolution: '',
        captureResolution: '',
        fps: 0,
        isConnected: false,
        lastSeen: DateTime.now(),
      ),
    );

    if (existingClient.id.isNotEmpty) {
<<<<<<< HEAD
      // Already connected, just show in the monitoring area (don't go fullscreen immediately)
=======
>>>>>>> 041c61fd020faca8a541e97373a304810967dde2
      print('LiveMonitoringTab: Already connected to ${student.ipAddress}');
      _showSnackBar('Monitoring ${student.name}', const Color(0xFF10B981));
      return;
    }

    // Attempt to connect
    _showSnackBar('Connecting to ${student.name}...', const Color(0xFF3B82F6));
    
    final success = await _screenService.connectToClient(student.ipAddress!);
    
    if (success) {
      _showSnackBar('Connected to ${student.name}', const Color(0xFF10B981));
    } else {
      _showSnackBar('Failed to connect to ${student.name}', const Color(0xFFEF4444));
    }
  }

  Widget _buildMonitoringPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.monitor, color: Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                const Text(
                  'Live Screen Monitoring',
                  style: TextStyle(
                    fontSize: 16,
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
          ),
          
          // Screen grid
          Expanded(
            child: _buildScreenGrid(),
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
            childAspectRatio: 16 / 9,
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
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A000000),
            offset: const Offset(0, 4),
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
                            errorBuilder: (context, error, stackTrace) {
                              print('Image error for ${client.id}: $error');
                              return const Center(
<<<<<<< HEAD
                                child: Text('Image Error', style: TextStyle(color: Colors.red)),
=======
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 32,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Image Error',
                                      style: TextStyle(color: Colors.red, fontSize: 12),
                                    ),
                                  ],
                                ),
>>>>>>> 041c61fd020faca8a541e97373a304810967dde2
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
<<<<<<< HEAD
                              const Icon(
                                Icons.monitor_outlined,
                                color: Color(0xFF64748B),
                                size: 48,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Client: ${client.id}\nIP: ${client.ipAddress}\nFrames: ${_monitorState.frameCache.containsKey(client.id) ? 'Available' : 'None'}',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
=======
                              const CircularProgressIndicator(
                                color: Color(0xFF64748B),
                                strokeWidth: 2,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Connecting...',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'IP: ${client.ipAddress}',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                ),
>>>>>>> 041c61fd020faca8a541e97373a304810967dde2
                              ),
                            ],
                          ),
                        ),
                  
<<<<<<< HEAD
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
                          onTap: () => _monitorState.setFullscreenClient(client.id),
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
=======
>>>>>>> 041c61fd020faca8a541e97373a304810967dde2
                ],
              ),
            ),
          ),
          
          // Client info footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.computerName.isNotEmpty ? client.computerName : 'Unknown Computer',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        client.userName.isNotEmpty ? client.userName : 'Unknown User',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
<<<<<<< HEAD
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
=======
                    color: hasFrame 
                        ? const Color(0xFF10B981).withOpacity(0.1)
                        : const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    hasFrame ? 'LIVE' : 'CONNECTING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: hasFrame 
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
>>>>>>> 041c61fd020faca8a541e97373a304810967dde2
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
<<<<<<< HEAD
=======
    final connectedClients = _screenService.connectedClients;
    final frameCount = _monitorState.frameCache.length;
    
>>>>>>> 041c61fd020faca8a541e97373a304810967dde2
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.monitor_outlined,
              size: 64,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No screens connected',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
<<<<<<< HEAD
          Text(
            'Click on a student to connect and monitor their screen\n\nDebug Info:\n- Connected clients: ${_screenService.connectedClients.length}\n- Frame cache: ${_monitorState.frameCache.length} items',
            style: const TextStyle(
              fontSize: 12,
=======
          const Text(
            'Click on a student to connect and monitor their screen',
            style: TextStyle(
              fontSize: 14,
>>>>>>> 041c61fd020faca8a541e97373a304810967dde2
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
<<<<<<< HEAD
=======
          const SizedBox(height: 16),
          // Enhanced debug info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Debug Information:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Connected clients: ${connectedClients.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  '• Frame cache: $frameCount items',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                    fontFamily: 'monospace',
                  ),
                ),
                if (connectedClients.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  const Text(
                    '• Client IDs:',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                      fontFamily: 'monospace',
                    ),
                  ),
                  ...connectedClients.map((client) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '  - ${client.id} (${client.ipAddress})',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9CA3AF),
                        fontFamily: 'monospace',
                      ),
                    ),
                  )),
                ],
              ],
            ),
          ),
>>>>>>> 041c61fd020faca8a541e97373a304810967dde2
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

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}