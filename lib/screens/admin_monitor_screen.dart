import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:labassistant/services/socket_services.dart';
import 'package:labassistant/services/api_services.dart';
import 'package:labassistant/services/auth_service.dart';
import 'package:labassistant/services/screen_monitor_service.dart';
import 'package:labassistant/widgets/screen_monitor_widget.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';

class AdminMonitorScreen extends StatefulWidget {
  final List<User> onlineUsers;

  const AdminMonitorScreen({super.key, required this.onlineUsers});

  @override
  State<AdminMonitorScreen> createState() => _AdminMonitorScreenState();
}

class _AdminMonitorScreenState extends State<AdminMonitorScreen> with TickerProviderStateMixin {
  User? selectedUser;
  Map<String, dynamic> studentActivity = {};
  List<Map<String, dynamic>> studentExercises = [];
  List<Map<String, dynamic>> studentActivities = [];
  bool isLoadingExercises = false;
  bool isLoadingActivities = false;
  Map<String, bool> expandedActivities = {};
  Map<String, bool> expandedExercises = {};
  
  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  
  // Screen monitoring
  late ScreenMonitorService _screenMonitorService;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _setupSocketListeners();
    
    // Initialize screen monitoring service
    _screenMonitorService = ScreenMonitorService();
    
    // Start animations
    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _screenMonitorService.dispose();
    super.dispose();
  }

  void _setupSocketListeners() {
    final socketService = Provider.of<SocketService>(context, listen: false);
    
    socketService.socket?.on('student-activity', (data) {
      setState(() {
        studentActivity[data['userId']] = data;
      });
      // Refresh activities if this is the selected student
      if (selectedUser?.enrollNumber == data['userId']) {
        _loadStudentActivities(selectedUser!.id);
      }
    });
    
    // Listen for test runs and submissions to update activity feed in real-time
    socketService.socket?.on('test-run-completed', (data) {
      if (selectedUser?.id == data['userId']) {
        _loadStudentActivities(selectedUser!.id);
      }
    });
    
    socketService.socket?.on('submission-completed', (data) {
      if (selectedUser?.id == data['userId']) {
        _loadStudentActivities(selectedUser!.id);
      }
    });

    socketService.socket?.on('student-screen', (data) {
      if (selectedUser?.enrollNumber == data['userId']) {
        // Handle screen sharing data
        print('Screen data received for ${data['userId']}');
      }
    });
    
    // Listen for exercise CRUD operations to refresh student exercises
    socketService.socket?.on('exercise-created', (data) {
      if (selectedUser != null) {
        _loadStudentExercises(selectedUser!.id);
      }
    });
    
    socketService.socket?.on('exercise-deleted', (data) {
      if (selectedUser != null) {
        _loadStudentExercises(selectedUser!.id);
      }
    });
    
    socketService.socket?.on('exercise-updated', (data) {
      if (selectedUser != null) {
        _loadStudentExercises(selectedUser!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final onlineStudents = widget.onlineUsers.where((user) => user.role == 'student').toList();
    
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          // Student list sidebar
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _slideController,
              curve: Curves.easeOutCubic,
            )),
            child: Container(
              width: 320,
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0A000000),
                    offset: Offset(2, 0),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.people_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Online Students',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${onlineStudents.length} active',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.circle, color: Colors.white, size: 6),
                              const SizedBox(width: 4),
                              Text(
                                '${onlineStudents.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Student list
                  Expanded(
                    child: onlineStudents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: const Icon(
                                    Icons.people_outline,
                                    size: 48,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No students online',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Students will appear here\nwhen they log in',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: onlineStudents.length,
                            itemBuilder: (context, index) {
                              final user = onlineStudents[index];
                              final isActive = studentActivity.containsKey(user.enrollNumber);
                              final lastActivity = studentActivity[user.enrollNumber];
                              final isSelected = selectedUser?.id == user.id;
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.1) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: const Color(0xFF3B82F6),
                                        child: Text(
                                          user.name[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: isActive ? const Color(0xFF10B981) : const Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  title: Text(
                                    user.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? const Color(0xFF1E40AF) : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF6B7280).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              user.enrollNumber,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF8B5CF6).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${user.batch}${user.section}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF8B5CF6),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (lastActivity != null) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.access_time,
                                              size: 12,
                                              color: Color(0xFF10B981),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Active ${_formatTime(lastActivity['timestamp'])}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF10B981),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'Online',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    setState(() {
                                      selectedUser = user;
                                    });
                                    _loadStudentExercises(user.id);
                                    _loadStudentActivities(user.id);
                                    _connectToStudentScreen(user);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          
          // Main monitoring panel
          Expanded(
            child: FadeTransition(
              opacity: _fadeController,
              child: onlineStudents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(60),
                            ),
                            child: const Icon(
                              Icons.monitor_outlined,
                              size: 64,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'No students to monitor',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Students will appear here when they log in',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    )
                  : selectedUser == null
                      ? Center(
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
                                  Icons.touch_app_rounded,
                                  size: 64,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Select a student to monitor',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Choose from the online students list',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildStudentMonitor(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadStudentExercises(int studentId) async {
    setState(() {
      isLoadingExercises = true;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService(authService);
      
      final exercises = await apiService.getStudentExercises(studentId);
      setState(() {
        studentExercises = exercises;
      });
    } catch (e) {
      print('Error loading student exercises: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading exercises: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      setState(() {
        isLoadingExercises = false;
      });
    }
  }
  
  Future<void> _loadStudentActivities(int studentId) async {
    setState(() {
      isLoadingActivities = true;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService(authService);
      
      final activities = await apiService.getStudentActivities(studentId);
      setState(() {
        studentActivities = activities;
      });
    } catch (e) {
      print('Error loading student activities: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading activities: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      setState(() {
        isLoadingActivities = false;
      });
    }
  }

  Future<void> _connectToStudentScreen(User user) async {
    // Connect to the specific student's screen monitoring agent
    if (user.ipAddress != null && user.ipAddress!.isNotEmpty) {
      // Sanitize IP address - replace commas with dots
      final sanitizedIP = user.ipAddress!.replaceAll(',', '.');
      
      // Validate IP address format
      if (_isValidIPAddress(sanitizedIP)) {
        print('Connecting to screen monitoring for ${user.name} at $sanitizedIP');
        
        // Show connecting status
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Connecting to ${user.name}\'s screen...'),
                ],
              ),
              backgroundColor: const Color(0xFF3B82F6),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        
        // Test basic connectivity first
        final canConnect = await _screenMonitorService.testConnectivity(sanitizedIP);
        
        if (!canConnect) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Cannot reach ${user.name}\'s machine at $sanitizedIP:8765\n'
                          'Please ensure:\n'
                          '• Screen capture agent is running as Administrator\n'
                          '• Windows Firewall allows port 8765\n'
                          '• Network connectivity is working'),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                duration: const Duration(seconds: 8),
              ),
            );
          }
          return;
        }
        
        final success = await _screenMonitorService.connectToClient(sanitizedIP);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    success ? Icons.check_circle : Icons.error,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      success 
                        ? 'Connected to ${user.name}\'s screen monitor'
                        : 'Failed to connect - Screen capture agent not running on ${user.name}\'s machine',
                    ),
                  ),
                ],
              ),
              backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              duration: Duration(seconds: success ? 3 : 5),
            ),
          );
        }
      } else {
        print('Invalid IP address format for ${user.name}: ${user.ipAddress}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid IP address format for ${user.name}: ${user.ipAddress}'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    } else {
      print('No IP address available for ${user.name}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No IP address available for ${user.name}'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  bool _isValidIPAddress(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    return true;
  }

  Widget _buildStudentMonitor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Student info header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x0A000000),
                offset: Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: const Color(0xFF3B82F6),
                    child: Text(
                      selectedUser!.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedUser!.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B7280).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.badge_rounded, size: 14, color: Color(0xFF6B7280)),
                              const SizedBox(width: 6),
                              Text(
                                'ID: ${selectedUser!.enrollNumber}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.school_rounded, size: 14, color: Color(0xFF8B5CF6)),
                              const SizedBox(width: 6),
                              Text(
                                'Batch: ${selectedUser!.batch} - Section: ${selectedUser!.section}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8B5CF6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2610B981),
                      offset: Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Monitoring',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Exercise list, activity feed, and screen monitoring
        Expanded(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  child: TabBar(
                    labelColor: const Color(0xFF3B82F6),
                    unselectedLabelColor: const Color(0xFF64748B),
                    indicatorColor: const Color(0xFF3B82F6),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.assignment_rounded, size: 20),
                            const SizedBox(width: 8),
                            const Text('Exercises'),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                studentExercises.length.toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.timeline_rounded, size: 20),
                            const SizedBox(width: 8),
                            const Text('Live Activity'),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                studentActivities.length.toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.monitor_rounded, size: 20),
                            const SizedBox(width: 8),
                            const Text('Screen Monitor'),
                            const SizedBox(width: 8),
                            StreamBuilder<List<ClientInfo>>(
                              stream: _screenMonitorService.clientsStream,
                              builder: (context, snapshot) {
                                final clientCount = snapshot.data?.length ?? 0;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    clientCount.toString(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildExercisesList(),
                      _buildLiveActivityFeed(),
                      const ScreenMonitorWidget(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExercisesList() {
    if (isLoadingExercises) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF3B82F6)),
            SizedBox(height: 16),
            Text(
              'Loading exercises...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }
    
    if (studentExercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 48,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No exercises found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This student hasn\'t been assigned any exercises yet',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: studentExercises.length,
      itemBuilder: (context, index) {
        final exercise = studentExercises[index];
        final isCompleted = exercise['completed'] == true;
        final score = exercise['score'];
        final submittedAt = exercise['submitted_at'];
        final activityCount = exercise['activity_count'] ?? 0;
        
        final exerciseKey = 'exercise_${exercise['id']}';
        final isExpanded = expandedExercises[exerciseKey] ?? false;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                offset: Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    expandedExercises[exerciseKey] = !isExpanded;
                  });
                },
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCompleted 
                                  ? const Color(0xFF10B981).withOpacity(0.1)
                                  : const Color(0xFFF59E0B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isCompleted ? Icons.check_circle_rounded : Icons.hourglass_bottom_rounded,
                              color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              exercise['title'] ?? 'Unknown Exercise',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          if (isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white, size: 14),
                                  SizedBox(width: 6),
                                  Text(
                                    'COMPLETED',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Icon(
                                isExpanded ? Icons.expand_less : Icons.expand_more,
                                color: const Color(0xFF64748B),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.book_rounded,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Subject: ${exercise['subject_name'] ?? 'Unknown'}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$activityCount activities',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF3B82F6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (isCompleted) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (score != null) ...[
                                    Icon(
                                      Icons.star_rounded,
                                      size: 16,
                                      color: Colors.amber[600],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Score: $score%',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.amber[700],
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  if (submittedAt != null) ...[
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Completed: ${_formatDateTime(submittedAt)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isCompleted 
                                    ? const Color(0xFF10B981).withOpacity(0.1)
                                    : const Color(0xFFF59E0B).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCompleted 
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFF59E0B),
                                ),
                              ),
                              child: Text(
                                isCompleted ? 'Completed' : 'In Progress',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted 
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _showExerciseDetails(exercise),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: Color(0xFF3B82F6),
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Details',
                                    style: TextStyle(
                                      color: Color(0xFF3B82F6),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded) _buildExerciseExpandedContent(exercise),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildLiveActivityFeed() {
    if (isLoadingActivities) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF10B981)),
            SizedBox(height: 16),
            Text(
              'Loading activities...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }
    
    if (studentActivities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.timeline_outlined,
                size: 48,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No activities found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Activities will appear here when the student\nruns code or submits solutions',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () => _loadStudentActivities(selectedUser!.id),
      color: const Color(0xFF10B981),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: studentActivities.length,
        itemBuilder: (context, index) {
          final activity = studentActivities[index];
          final activityKey = 'activity_${activity['id']}';
          final isExpanded = expandedActivities[activityKey] ?? false;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  offset: Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      expandedActivities[activityKey] = !isExpanded;
                    });
                  },
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: activity['activity_type'] == 'submission'
                                    ? const Color(0xFF10B981).withOpacity(0.1)
                                    : const Color(0xFF3B82F6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                activity['activity_type'] == 'submission'
                                    ? Icons.send_rounded
                                    : Icons.play_arrow_rounded,
                                size: 16,
                                color: activity['activity_type'] == 'submission'
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF3B82F6),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activity['subject_name'] ?? 'Unknown Subject',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xFF3B82F6),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    activity['exercise_title'] ?? 'Unknown Exercise',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatDateTime(activity['created_at']),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Icon(
                                  isExpanded ? Icons.expand_less : Icons.expand_more,
                                  color: const Color(0xFF64748B),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Badges row
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            // Activity type badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: activity['activity_type'] == 'submission'
                                    ? const Color(0xFF10B981).withOpacity(0.1)
                                    : const Color(0xFF3B82F6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: activity['activity_type'] == 'submission'
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF3B82F6),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                activity['activity_type'] == 'submission' ? 'SUBMITTED' : 'TEST RUN',
                                style: TextStyle(
                                  color: activity['activity_type'] == 'submission'
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF3B82F6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: activity['status'] == 'passed' 
                                    ? const Color(0xFF10B981).withOpacity(0.1)
                                    : activity['status'] == 'failed'
                                        ? const Color(0xFFEF4444).withOpacity(0.1)
                                        : const Color(0xFFF59E0B).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: activity['status'] == 'passed' 
                                      ? const Color(0xFF10B981)
                                      : activity['status'] == 'failed'
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFFF59E0B),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    activity['status'] == 'passed' 
                                        ? Icons.check_circle
                                        : activity['status'] == 'failed'
                                            ? Icons.cancel
                                            : Icons.warning,
                                    size: 12,
                                    color: activity['status'] == 'passed' 
                                        ? const Color(0xFF10B981)
                                        : activity['status'] == 'failed'
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFFF59E0B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    activity['status'].toString().toUpperCase(),
                                    style: TextStyle(
                                      color: activity['status'] == 'passed' 
                                          ? const Color(0xFF10B981)
                                          : activity['status'] == 'failed'
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFFF59E0B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Test cases passed
                            if (activity['tests_passed'] != null && activity['total_tests'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF8B5CF6), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.quiz_rounded, size: 12, color: Color(0xFF8B5CF6)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Tests: ${activity['tests_passed']}/${activity['total_tests']}',
                                      style: const TextStyle(
                                        color: Color(0xFF8B5CF6),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            
                            // Score for submissions
                            if (activity['activity_type'] == 'submission' && activity['score'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFF59E0B), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Score: ${activity['score']}%',
                                      style: const TextStyle(
                                        color: Color(0xFFF59E0B),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (isExpanded) ...[
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  _buildActivityCodeDisplay(activity),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
  
  void _showExerciseDetails(Map<String, dynamic> exercise) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService(authService);
      
      final progress = await apiService.getStudentProgress(
        selectedUser!.id,
        exercise['id'],
      );
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  exercise['title'] ?? 'Exercise Details',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 600,
            height: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Exercise info header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.book_rounded, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Text(
                              'Subject: ${exercise['subject_name']}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              exercise['completed'] ? Icons.check_circle : Icons.hourglass_bottom,
                              size: 16,
                              color: exercise['completed'] ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: exercise['completed'] 
                                    ? const Color(0xFF10B981).withOpacity(0.1)
                                    : const Color(0xFFF59E0B).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                exercise['completed'] ? 'Completed' : 'In Progress',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: exercise['completed'] ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (exercise['completed']) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (exercise['score'] != null) ...[
                                const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Score: ${exercise['score']}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              Text(
                                'Submitted: ${_formatDateTime(exercise['submitted_at'])}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Activities:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...progress['activities'].asMap().entries.map<Widget>((entry) {
                    final index = entry.key;
                    final activity = entry.value;
                    final activityKey = 'dialog_${exercise['id']}_$index';
                    final isExpanded = expandedActivities[activityKey] ?? false;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () {
                              setDialogState(() {
                                expandedActivities[activityKey] = !isExpanded;
                              });
                            },
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: activity['activity_type'] == 'submission'
                                              ? const Color(0xFF10B981).withOpacity(0.1)
                                              : const Color(0xFF3B82F6).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Icon(
                                          activity['activity_type'] == 'submission'
                                              ? Icons.send_rounded
                                              : Icons.play_arrow_rounded,
                                          size: 14,
                                          color: activity['activity_type'] == 'submission'
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFF3B82F6),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          activity['activity_type'] == 'submission'
                                              ? 'Submission'
                                              : 'Test Run',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _formatDateTime(activity['created_at']),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        isExpanded ? Icons.expand_less : Icons.expand_more,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: activity['status'] == 'passed' 
                                              ? const Color(0xFF10B981).withOpacity(0.1)
                                              : activity['status'] == 'failed'
                                                  ? const Color(0xFFEF4444).withOpacity(0.1)
                                                  : const Color(0xFFF59E0B).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: activity['status'] == 'passed' 
                                                ? const Color(0xFF10B981)
                                                : activity['status'] == 'failed'
                                                    ? const Color(0xFFEF4444)
                                                    : const Color(0xFFF59E0B),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          'Status: ${activity['status']}',
                                          style: TextStyle(
                                            color: activity['status'] == 'passed' 
                                                ? const Color(0xFF10B981)
                                                : activity['status'] == 'failed'
                                                    ? const Color(0xFFEF4444)
                                                    : const Color(0xFFF59E0B),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (activity['score'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFF3B82F6), width: 1),
                                          ),
                                          child: Text(
                                            'Score: ${activity['score']}%',
                                            style: const TextStyle(
                                              color: Color(0xFF3B82F6),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      if (activity['tests_passed'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF8B5CF6).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFF8B5CF6), width: 1),
                                          ),
                                          child: Text(
                                            'Tests: ${activity['tests_passed']}/${activity['total_tests']}',
                                            style: const TextStyle(
                                              color: Color(0xFF8B5CF6),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isExpanded) ...[
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            _buildActivityCodeDisplay(activity),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
              ),
              child: const Text('Close'),
            ),
          ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading exercise details: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Widget _buildExerciseExpandedContent(Map<String, dynamic> exercise) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exercise Description
            if (exercise['description'] != null && exercise['description'].toString().isNotEmpty) ...[
              const Text(
                'Description:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  exercise['description'],
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Exercise Stats
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            const Text(
                              'Created',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(exercise['created_at']),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.assignment_turned_in_rounded, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            const Text(
                              'Activities',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${exercise['activity_count'] ?? 0}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showExerciseDetails(exercise),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: const Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: IconButton(
                    onPressed: () {
                      // Copy exercise ID to clipboard for reference
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Exercise ID: ${exercise['id']} copied to clipboard'),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.copy_rounded,
                      color: Color(0xFF10B981),
                      size: 16,
                    ),
                    tooltip: 'Copy Exercise ID',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }
  
  String _formatDateTime(String? timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }
  
  Widget _buildActivityCodeDisplay(Map<String, dynamic> activity) {
    // Get code from test_results or from a direct code field
    String? code;
    
    // Try to extract code from test_results JSON
    if (activity['test_results'] != null) {
      try {
        final testResults = activity['test_results'] is String 
            ? jsonDecode(activity['test_results'])
            : activity['test_results'];
        code = testResults['code'];
      } catch (e) {
        print('Error parsing test_results: $e');
      }
    }
    
    // Fallback to direct code field if available
    code ??= activity['code'];
    
    if (code == null || code.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600], size: 16),
            const SizedBox(width: 8),
            Text(
              'No code available for this activity',
              style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.code,
                size: 16,
                color: Colors.grey[700],
              ),
              const SizedBox(width: 8),
              Text(
                'Code Submitted:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Code copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                tooltip: 'Copy code',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'Courier New',
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          if (activity['test_results'] != null) ...[
            const SizedBox(height: 12),
            _buildTestResults(activity['test_results']),
          ],
        ],
      ),
    );
  }
  
  Widget _buildTestResults(dynamic testResults) {
    try {
      final results = testResults is String 
          ? jsonDecode(testResults)
          : testResults;
          
      if (results['testCases'] != null) {
        final testCases = results['testCases'] as List;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Results:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            ...testCases.asMap().entries.map((entry) {
              final index = entry.key;
              final testCase = entry.value;
              final passed = testCase['passed'] == true;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: passed ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: passed ? Colors.green : Colors.red,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          passed ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: passed ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Test Case ${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: passed ? Colors.green[700] : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                    if (testCase['input'] != null) ...[
                      const SizedBox(height: 4),
                      Text('Input: ${testCase['input']}', style: const TextStyle(fontSize: 11)),
                    ],
                    if (testCase['expected'] != null) ...[
                      const SizedBox(height: 2),
                      Text('Expected: ${testCase['expected']}', style: const TextStyle(fontSize: 11)),
                    ],
                    if (testCase['actual'] != null) ...[
                      const SizedBox(height: 2),
                      Text('Actual: ${testCase['actual']}', style: const TextStyle(fontSize: 11)),
                    ],
                  ],
                ),
              );
            }).toList(),
          ],
        );
      }
    } catch (e) {
      print('Error parsing test results: $e');
    }
    
    return const SizedBox.shrink();
  }
}