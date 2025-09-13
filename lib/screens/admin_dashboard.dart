import 'package:labassistant/services/socket_services.dart';
import 'package:labassistant/services/api_services.dart';
import 'package:labassistant/services/auth_service.dart';
import 'package:labassistant/screens/exercise_management_screen.dart';
import 'package:labassistant/screens/admin_monitor_screen.dart';
import 'package:labassistant/widgets/screen_monitor_widget.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with TickerProviderStateMixin {
  int currentIndex = 0;
  List<User> onlineUsers = [];
  Map<String, dynamic> analytics = {
    'totalExercises': 0,
    'totalSubjects': 0,
    'totalStudents': 0,
    'totalSubmissions': 0,
    'onlineStudents': 0,
    'recentSubmissions': [],
    'subjectStats': [],
    'dailyActivity': [],
    'difficultyDistribution': {'easy': 0, 'medium': 0, 'hard': 0},
    'completionRates': [],
  };

  // Store service references to avoid context access in dispose
  SocketService? _socketService;
  AuthService? _authService;
  ApiService? _apiService;
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  bool _isLoading = true;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _statsController;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _statsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    // Store service references early
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _socketService = Provider.of<SocketService>(context, listen: false);
      _authService = Provider.of<AuthService>(context, listen: false);
      _apiService = ApiService(_authService!);
      
      _initializeSocket();
      _loadInitialData();
      _startPeriodicRefresh();
      
      // Start animations
      _fadeController.forward();
      _slideController.forward();
      _statsController.forward();
    });
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    await Future.wait([
      _loadAnalytics(),
      _fetchOnlineUsers(),
    ]);
    
    setState(() => _isLoading = false);
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && !_isRefreshing) {
        _fetchOnlineUsers();
        if (currentIndex == 0) {
          _loadAnalytics();
        }
      }
    });
  }

  void _initializeSocket() {
    if (_socketService == null || _authService == null) return;
    
    _socketService!.connect();
    
    _socketService!.socket?.emit('admin-login', {
      'enrollNumber': _authService!.user?.enrollNumber,
      'name': _authService!.user?.name,
      'role': _authService!.user?.role,
    });
    
    _socketService!.socket?.on('user-connected', (data) {
      _fetchOnlineUsers();
    });
    
    _socketService!.socket?.on('user-disconnected', (data) {
      _fetchOnlineUsers();
    });
    
    _socketService!.socket?.on('online-users', (data) {
      _fetchOnlineUsers();
    });

    _socketService!.socket?.on('student-activity', (data) {
      if (currentIndex == 0) {
        _loadAnalytics();
      }
    });
    
    _socketService!.socket?.on('connect', (_) {
      _socketService!.socket?.emit('get-online-users');
      _fetchOnlineUsers();
    });

    _socketService!.socket?.on('user-status-changed', (data) {
      _fetchOnlineUsers();
    });
  }

  Future<void> _loadAnalytics() async {
    if (_apiService == null) return;
    
    try {
      final data = await _apiService!.getAdminAnalytics();
      if (mounted) {
        setState(() {
          analytics = {
            ...analytics,
            ...data,
            'subjectStats': _generateSubjectStats(),
            'dailyActivity': _generateDailyActivity(),
            'difficultyDistribution': _generateDifficultyDistribution(),
            'completionRates': _generateCompletionRates(),
          };
        });
      }
    } catch (e) {
      print('Error loading analytics: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to load analytics: $e');
      }
    }
  }
  
  Future<void> _fetchOnlineUsers() async {
    if (_apiService == null || _isRefreshing) return;
    
    _isRefreshing = true;
    
    try {
      final users = await _apiService!.getOnlineUsers();
      if (mounted) {
        setState(() {
          onlineUsers = users;
          analytics['onlineStudents'] = users.length;
        });
      }
    } catch (e) {
      print('Error fetching online users: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  // Generate sample data for visualizations
  List<Map<String, dynamic>> _generateSubjectStats() {
    return [
      {'name': 'C Programming', 'exercises': 15, 'submissions': 180, 'avgScore': 78.5},
      {'name': 'Advanced C', 'exercises': 12, 'submissions': 144, 'avgScore': 72.3},
      {'name': 'Data Structures', 'exercises': 20, 'submissions': 240, 'avgScore': 65.8},
      {'name': 'Algorithms', 'exercises': 18, 'submissions': 216, 'avgScore': 68.2},
    ];
  }

  List<Map<String, dynamic>> _generateDailyActivity() {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      return {
        'date': date.toString().substring(5, 10),
        'submissions': math.Random().nextInt(50) + 20,
        'users': math.Random().nextInt(20) + 5,
      };
    });
  }

  Map<String, int> _generateDifficultyDistribution() {
    return {
      'easy': analytics['totalExercises'] != null ? (analytics['totalExercises'] * 0.4).round() : 12,
      'medium': analytics['totalExercises'] != null ? (analytics['totalExercises'] * 0.4).round() : 16,
      'hard': analytics['totalExercises'] != null ? (analytics['totalExercises'] * 0.2).round() : 8,
    };
  }

  List<Map<String, dynamic>> _generateCompletionRates() {
    return [
      {'range': '90-100%', 'count': 15, 'color': Colors.green},
      {'range': '80-89%', 'count': 22, 'color': Colors.lightGreen},
      {'range': '70-79%', 'count': 28, 'color': Colors.orange},
      {'range': '60-69%', 'count': 18, 'color': Colors.deepOrange},
      {'range': '<60%', 'count': 12, 'color': Colors.red},
    ];
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    
    await Future.wait([
      _fetchOnlineUsers(),
      _loadAnalytics(),
    ]);
    
    setState(() => _isRefreshing = false);
    
    if (mounted) {
      _showSuccessSnackBar('Data refreshed successfully');
    }
  }

  Future<void> _handleAdminLogout() async {
    if (_authService == null || _socketService == null || _apiService == null) return;

    try {
      final shouldLogout = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.orange[600], size: 28),
              const SizedBox(width: 12),
              const Text(
                'Confirm Admin Logout',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to logout as admin?',
                style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This will:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                    const SizedBox(height: 4),
                    Text('• Disconnect all ${onlineUsers.length} online students', 
                         style: const TextStyle(color: Color(0xFF92400E))),
                    const Text('• Stop the server', style: TextStyle(color: Color(0xFF92400E))),
                    const Text('• End all active sessions', style: TextStyle(color: Color(0xFF92400E))),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Logout'),
            ),
          ],
        ),
      );

      if (shouldLogout != true) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF2563EB)),
              const SizedBox(height: 16),
              const Text(
                'Shutting down server...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Text(
                'Notifying ${onlineUsers.length} online students',
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );

      if (_socketService!.isConnected) {
        _socketService!.socket?.emit('admin-logout', {
          'message': 'Admin is logging out. Server will shut down.',
          'timestamp': DateTime.now().toIso8601String(),
          'onlineStudentCount': onlineUsers.length,
        });
        
        await Future.delayed(const Duration(milliseconds: 500));
      }

      try {
        await _apiService!.sendAdminShutdownNotification();
      } catch (e) {
        print('Error sending shutdown notification: $e');
      }

      _socketService!.disconnect();
      await _authService!.logout();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.of(context).pushReplacementNamed('/role-selection');
      }
      
    } catch (e) {
      print('Error during admin logout: $e');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showErrorSnackBar('Logout failed: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    _statsController.dispose();
    _socketService?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: _isRefreshing 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _isRefreshing ? null : _handleRefresh,
            tooltip: 'Refresh Data',
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings_rounded, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Admin: ${authService.user?.name ?? 'Administrator'}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Admin Logout (Stops Server)',
            onPressed: _handleAdminLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2563EB),
              ),
            )
          : IndexedStack(
              index: currentIndex,
              children: [
                _buildDashboardTab(),
                _buildMonitoringTab(),
                _buildExerciseManagementTab(),
                _buildLiveMonitoringTab(),
              ],
            ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x0F000000),
              offset: Offset(0, -2),
              blurRadius: 8,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            setState(() => currentIndex = index);
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFF2563EB),
          unselectedItemColor: const Color(0xFF64748B),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.monitor_rounded),
              label: 'Monitor',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_rounded),
              label: 'Manage',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.live_tv_rounded),
              label: 'Live',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    return FadeTransition(
      opacity: _fadeController,
      child: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: const Color(0xFF2563EB),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.3),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _slideController,
                  curve: Curves.easeOutCubic,
                )),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A3B82F6),
                        offset: Offset(0, 4),
                        blurRadius: 20,
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
                          Icons.admin_panel_settings_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome, Administrator',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'System Overview & Analytics',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x2610B981),
                              offset: Offset(0, 2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 8),
                            SizedBox(width: 6),
                            Text(
                              'Server Online',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Stats Cards
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _statsController,
                  curve: Curves.easeOutCubic,
                )),
                child: Row(
                  children: [
                    _buildAnimatedStatCard(
                      'Online Students',
                      analytics['onlineStudents']?.toString() ?? '0',
                      Icons.people_rounded,
                      const Color(0xFF10B981),
                      'Currently active',
                      0,
                    ),
                    const SizedBox(width: 16),
                    _buildAnimatedStatCard(
                      'Total Exercises',
                      analytics['totalExercises']?.toString() ?? '0',
                      Icons.assignment_rounded,
                      const Color(0xFF3B82F6),
                      'Across all subjects',
                      1,
                    ),
                    const SizedBox(width: 16),
                    _buildAnimatedStatCard(
                      'Total Submissions',
                      analytics['totalSubmissions']?.toString() ?? '0',
                      Icons.send_rounded,
                      const Color(0xFF8B5CF6),
                      'All time',
                      2,
                    ),
                    const SizedBox(width: 16),
                    _buildAnimatedStatCard(
                      'Active Subjects',
                      analytics['totalSubjects']?.toString() ?? '0',
                      Icons.book_rounded,
                      const Color(0xFFF59E0B),
                      'Available courses',
                      3,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Charts and Visualizations
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _buildActivityChart(),
                        const SizedBox(height: 20),
                        _buildSubjectStatsCard(),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 20),
                  
                  // Right Column
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        _buildDifficultyDistribution(),
                        const SizedBox(height: 20),
                        _buildCompletionRatesCard(),
                        const SizedBox(height: 20),
                        _buildRecentActivityCard(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
    int index,
  ) {
    return Expanded(
      child: TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 800 + (index * 200)),
        tween: Tween<double>(begin: 0, end: 1),
        builder: (context, animationValue, child) {
          return Transform.translate(
            offset: Offset(0, 20 * (1 - animationValue)),
            child: Opacity(
              opacity: animationValue,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.1),
                      offset: const Offset(0, 4),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const Spacer(),
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 1000 + (index * 100)),
                      tween: Tween<double>(begin: 0, end: double.tryParse(value) ?? 0),
                      builder: (context, animatedValue, child) {
                        return Text(
                          animatedValue.round().toString(),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityChart() {
    final dailyActivityRaw = analytics['dailyActivity'] ?? [];
    final dailyActivity = (dailyActivityRaw as List).cast<Map<String, dynamic>>();
    final maxSubmissions = dailyActivity.isNotEmpty 
        ? dailyActivity.map((d) => d['submissions'] as int).reduce(math.max)
        : 1;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 4),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.timeline_rounded,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Daily Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Last 7 days',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: dailyActivity.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                final submissions = data['submissions'] as int;
                final height = (submissions / maxSubmissions) * 150;
                
                return TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 1000 + (index * 100)),
                  tween: Tween<double>(begin: 0, end: height),
                  builder: (context, animatedHeight, child) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          submissions.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 24,
                          height: animatedHeight,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                const Color(0xFF3B82F6),
                                const Color(0xFF60A5FA),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data['date'],
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectStatsCard() {
    final subjectStatsRaw = analytics['subjectStats'] ?? [];
    final subjectStats = (subjectStatsRaw as List).cast<Map<String, dynamic>>();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 4),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.book_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Subject Performance',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...subjectStats.asMap().entries.map((entry) {
            final index = entry.key;
            final subject = entry.value;
            final avgScore = subject['avgScore'] as double;
            final scoreColor = avgScore >= 75 
                ? const Color(0xFF10B981)
                : avgScore >= 60 
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFEF4444);
            
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 800 + (index * 200)),
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, animationValue, child) {
                return Opacity(
                  opacity: animationValue,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
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
                            Expanded(
                              child: Text(
                                subject['name'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: scoreColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${avgScore.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: scoreColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Exercises: ${subject['exercises']}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    'Submissions: ${subject['submissions']}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              height: 4,
                              child: LinearProgressIndicator(
                                value: avgScore / 100,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDifficultyDistribution() {
    final distributionRaw = analytics['difficultyDistribution'] ?? {};
    final distribution = Map<String, int>.from(distributionRaw);
    final total = distribution.values.reduce((a, b) => a + b);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 4),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Color(0xFFF59E0B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Difficulty',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Donut Chart - Now properly sized to fit container
          SizedBox(
            height: 200,
            width: double.infinity,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CustomPaint(
                      painter: DonutChartPainter(distribution, total),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        total.toString(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const Text(
                        'Exercises',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Legend
          ...distribution.entries.map((entry) {
            final difficulty = entry.key;
            final count = entry.value;
            final percentage = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0.0';
            
            Color color;
            switch (difficulty) {
              case 'easy':
                color = const Color(0xFF10B981);
                break;
              case 'medium':
                color = const Color(0xFFF59E0B);
                break;
              case 'hard':
                color = const Color(0xFFEF4444);
                break;
              default:
                color = const Color(0xFF64748B);
            }
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      difficulty.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Text(
                    '$count ($percentage%)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCompletionRatesCard() {
    final completionRatesRaw = analytics['completionRates'] ?? [];
    final completionRates = (completionRatesRaw as List).cast<Map<String, dynamic>>();
    final maxCount = completionRates.isNotEmpty 
        ? completionRates.map((r) => r['count'] as int).reduce(math.max)
        : 1;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 4),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Completion Rates',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...completionRates.asMap().entries.map((entry) {
            final index = entry.key;
            final rate = entry.value;
            final count = rate['count'] as int;
            final range = rate['range'] as String;
            final color = rate['color'] as Color;
            final width = (count / maxCount) * 100;
            
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 1000 + (index * 200)),
              tween: Tween<double>(begin: 0, end: width),
              builder: (context, animatedWidth, child) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            range,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            count.toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: animatedWidth / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    final recentSubmissions = analytics['recentSubmissions'] as List? ?? [];
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 4),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  color: Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (recentSubmissions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No recent activity',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            )
          else
            ...recentSubmissions.take(5).map((submission) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            submission['user_name'] ?? 'Unknown User',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            submission['exercise_title'] ?? 'Unknown Exercise',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${submission['score'] ?? 0}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildMonitoringTab() {
    return AdminMonitorScreen(onlineUsers: onlineUsers);
  }

  Widget _buildExerciseManagementTab() {
    return const ExerciseManagementScreen();
  }

  Widget _buildLiveMonitoringTab() {
    return const ScreenMonitorWidget();
  }
}

// Custom painter for donut chart
class DonutChartPainter extends CustomPainter {
  final Map<String, int> data;
  final int total;

  DonutChartPainter(this.data, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final innerRadius = radius * 0.6;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius - innerRadius;

    double startAngle = -math.pi / 2;

    data.forEach((difficulty, count) {
      Color color;
      switch (difficulty) {
        case 'easy':
          color = const Color(0xFF10B981);
          break;
        case 'medium':
          color = const Color(0xFFF59E0B);
          break;
        case 'hard':
          color = const Color(0xFFEF4444);
          break;
        default:
          color = const Color(0xFF64748B);
      }

      final sweepAngle = (count / total) * 2 * math.pi;
      
      paint.color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - paint.strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}