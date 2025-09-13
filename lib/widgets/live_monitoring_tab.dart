import 'package:flutter/material.dart';
import '../services/screen_monitor_service.dart';
import '../services/screen_monitor_state.dart';
import '../services/api_services.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'screen_monitor_widget.dart';

class LiveMonitoringTab extends StatefulWidget {
  final List<User> onlineUsers;

  const LiveMonitoringTab({super.key, required this.onlineUsers});

  @override
  State<LiveMonitoringTab> createState() => _LiveMonitoringTabState();
}

class _LiveMonitoringTabState extends State<LiveMonitoringTab> {
  late ScreenMonitorService _screenService;
  late ScreenMonitorState _monitorState;
  late ApiService _apiService;
  List<Map<String, dynamic>> _studentIpData = [];
  bool _isLoadingIpData = true;

  @override
  void initState() {
    super.initState();
    _screenService = ScreenMonitorService();
    _monitorState = ScreenMonitorState();
    _apiService = ApiService(AuthService());
    _loadStudentIpData();
  }

  Future<void> _loadStudentIpData() async {
    try {
      print('🔍 Loading student IP data...');
      final ipData = await _apiService.getStudentIpAddresses();
      print('📊 Received IP data: ${ipData.length} students');
      for (var data in ipData) {
        print('   Student: ${data['enrollNumber']} - Local: ${data['localIp']}, Public: ${data['publicIp']}');
      }
      
      if (mounted) {
        setState(() {
          _studentIpData = ipData;
          _isLoadingIpData = false;
        });
      }
    } catch (e) {
      print('❌ Error loading student IP data: $e');
      if (mounted) {
        setState(() {
          _isLoadingIpData = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _monitorState,
      builder: (context, child) {
        // If in fullscreen mode, show the fullscreen view
        if (_monitorState.fullscreenClientId != null) {
          return _buildFullscreenView();
        }

        // Otherwise show the main live monitoring interface
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
                  
                  // Right side: Screen monitoring grid
                  Expanded(
                    flex: 2,
                    child: const ScreenMonitorWidget(),
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
    final connectedStudents = onlineStudents.where(_isStudentConnected).length;
    
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
                  '${onlineStudents.length} students online • $connectedStudents screens connected',
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
            child: _isLoadingIpData
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text(
                          'Loading student data...',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : onlineStudents.isEmpty
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
                          final isConnected = _isStudentConnected(student);
                          
                          return _buildStudentTile(student, isConnected);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTile(User student, bool isConnected) {
    final connectedClients = _screenService.connectedClients;
    
    // Find student's IP data from database
    final studentIpInfo = _studentIpData.firstWhere(
      (ipData) => ipData['enrollNumber'] == student.enrollNumber,
      orElse: () => <String, dynamic>{},
    );
    
    // Match client using IP address from database
    ClientInfo? matchingClient;
    if (isConnected) {
      matchingClient = connectedClients.firstWhere(
        (client) {
          if (studentIpInfo.isNotEmpty) {
            final localIp = studentIpInfo['localIp'];
            final publicIp = studentIpInfo['publicIp'];
            return client.ipAddress == localIp || client.ipAddress == publicIp;
          }
          // Fallback to name matching if no IP data
          return client.userName.toLowerCase() == student.name.toLowerCase() ||
                 client.computerName.toLowerCase().contains(student.enrollNumber.toLowerCase());
        },
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
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isConnected && matchingClient != null ? () => _openStudentFullscreen(matchingClient!.id) : null,
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
                      // Show IP status for debugging
                      if (studentIpInfo.isNotEmpty)
                        Text(
                          'IP: ${studentIpInfo['localIp'] ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
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
                    icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
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

  bool _isStudentConnected(User student) {
    final connectedClients = _screenService.connectedClients;
    
    // Find student's IP data from database
    final studentIpInfo = _studentIpData.firstWhere(
      (ipData) => ipData['enrollNumber'] == student.enrollNumber,
      orElse: () => <String, dynamic>{},
    );
    
    print('🔍 Checking connection for student: ${student.name} (${student.enrollNumber})');
    print('   IP Data: $studentIpInfo');
    print('   Connected clients: ${connectedClients.map((c) => '${c.computerName}@${c.ipAddress}').toList()}');
    
    // Check if any connected client matches this student's IP
    bool isConnected = connectedClients.any((client) {
      if (studentIpInfo.isNotEmpty) {
        final localIp = studentIpInfo['localIp'];
        final publicIp = studentIpInfo['publicIp'];
        bool ipMatch = client.ipAddress == localIp || client.ipAddress == publicIp;
        if (ipMatch) {
          print('   ✅ IP match found: ${client.ipAddress} matches ${localIp ?? publicIp}');
        }
        return ipMatch;
      }
      // Fallback to name matching if no IP data
      bool nameMatch = client.userName.toLowerCase() == student.name.toLowerCase() ||
                      client.computerName.toLowerCase().contains(student.enrollNumber.toLowerCase());
      if (nameMatch) {
        print('   ✅ Name match found: ${client.userName}/${client.computerName}');
      }
      return nameMatch;
    });
    
    print('   Result: ${isConnected ? "CONNECTED" : "NOT CONNECTED"}');
    return isConnected;
  }

  void _openStudentFullscreen(String clientId) {
    _monitorState.setFullscreenClient(clientId);
  }
}
