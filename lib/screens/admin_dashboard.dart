import 'package:flutter/material.dart';
import 'package:labassistant/services/api_services.dart';
import 'package:labassistant/services/socket_services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'admin_monitor_screen.dart';
import 'exercise_management_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int currentIndex = 0;
  List<User> onlineUsers = [];
  Map<String, dynamic> analytics = {
    'totalExercises': 0,
    'totalSubjects': 0,
    'totalStudents': 0,
    'totalSubmissions': 0
  };

  // Store service references to avoid context access in dispose
  SocketService? _socketService;
  AuthService? _authService;
  ApiService? _apiService;
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // Store service references early to avoid context access in dispose
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _socketService = Provider.of<SocketService>(context, listen: false);
      _authService = Provider.of<AuthService>(context, listen: false);
      _apiService = ApiService(_authService!);
      
      _initializeSocket();
      _loadAnalytics();
      _fetchOnlineUsers();
      _startPeriodicRefresh();
    });
  }

  void _startPeriodicRefresh() {
    // Refresh online users every 30 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted && !_isRefreshing) {
        print('Periodic refresh: Fetching online users...');
        _fetchOnlineUsers();
      }
    });
  }

  void _initializeSocket() {
    if (_socketService == null || _authService == null) return;
    
    _socketService!.connect();
    
    // Register admin login with socket
    _socketService!.socket?.emit('admin-login', {
      'enrollNumber': _authService!.user?.enrollNumber,
      'name': _authService!.user?.name,
      'role': _authService!.user?.role,
    });
    
    // Listen for user connections
    _socketService!.socket?.on('user-connected', (data) {
      print('User connected: $data');
      _fetchOnlineUsers();
    });
    
    // Listen for user disconnections
    _socketService!.socket?.on('user-disconnected', (data) {
      print('User disconnected: $data');
      _fetchOnlineUsers();
    });
    
    // Listen for online users list updates
    _socketService!.socket?.on('online-users', (data) {
      print('Socket online users update: $data');
      // Don't rely only on socket data, still fetch from API for accuracy
      _fetchOnlineUsers();
    });

    _socketService!.socket?.on('student-activity', (data) {
      print('Student activity: $data');
    });
    
    // Request current online users when socket connects
    _socketService!.socket?.on('connect', (_) {
      print('Socket connected, requesting online users');
      _socketService!.socket?.emit('get-online-users');
      _fetchOnlineUsers(); // Also fetch from API
    });

    // Listen for user status changes
    _socketService!.socket?.on('user-status-changed', (data) {
      print('User status changed: $data');
      _fetchOnlineUsers(); // Refresh from database
    });
  }

  Future<void> _loadAnalytics() async {
    if (_apiService == null) return;
    
    try {
      final data = await _apiService!.getAdminAnalytics();
      if (mounted) {
        setState(() {
          analytics = data;
        });
      }
      print('Loaded analytics: $data');
    } catch (e) {
      print('Error loading analytics: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load analytics: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
  
  Future<void> _fetchOnlineUsers() async {
    if (_apiService == null || _isRefreshing) return;
    
    _isRefreshing = true;
    
    try {
      print('Fetching online users from API...');
      final users = await _apiService!.getOnlineUsers();
      if (mounted) {
        setState(() {
          onlineUsers = users;
        });
      }
      print('Successfully fetched ${users.length} online users from database:');
      for (var user in users) {
        print('  - ${user.name} (${user.enrollNumber}) - Last active: ${user.lastActive}');
      }
    } catch (e) {
      print('Error fetching online users: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch online users: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _isRefreshing = true;
    });
    
    await Future.wait([
      _fetchOnlineUsers(),
      _loadAnalytics(),
    ]);
    
    setState(() {
      _isRefreshing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data refreshed successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // Enhanced admin logout method with proper server shutdown
  Future<void> _handleAdminLogout() async {
    if (_authService == null || _socketService == null || _apiService == null) {
      print('Services not initialized properly');
      return;
    }

    try {
      print('Admin logout initiated...');
      
      // Show confirmation dialog first
      final shouldLogout = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Confirm Admin Logout'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to logout as admin?'),
              SizedBox(height: 12),
              Text(
                'This will:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Disconnect all ${onlineUsers.length} online students'),
              Text('• Stop the server'),
              Text('• End all active sessions'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Logout', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (shouldLogout != true) {
        print('Admin logout cancelled by user');
        return;
      }
      
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Shutting down server...'),
              SizedBox(height: 8),
              Text(
                'Notifying ${onlineUsers.length} online students',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );

      // 1. Emit admin logout event to notify all students
      if (_socketService!.isConnected) {
        print('Emitting admin logout event...');
        _socketService!.socket?.emit('admin-logout', {
          'message': 'Admin is logging out. Server will shut down.',
          'timestamp': DateTime.now().toIso8601String(),
          'onlineStudentCount': onlineUsers.length,
        });
        
        // Give socket time to send the message
        await Future.delayed(Duration(milliseconds: 1000));
      }

      // 2. Call API to send shutdown notification to all students
      try {
        print('Sending shutdown notification API call...');
        
        // This will set all students offline and emit socket events
        await _apiService!.sendAdminShutdownNotification();
        
        print('Shutdown notification sent successfully');
      } catch (e) {
        print('Error sending shutdown notification: $e');
        // Continue with logout even if notification fails
      }

      // 3. Disconnect socket connection
      print('Disconnecting admin socket...');
      _socketService!.disconnect();

      // 4. Call auth service logout (this will stop the server)
      print('Calling auth service logout...');
      await _authService!.logout();

      // 5. Close loading dialog if still mounted
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // 6. Navigate to role selection
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/role-selection');
      }

      print('Admin logout completed successfully');
      
    } catch (e) {
      print('Error during admin logout: $e');
      
      // Close loading dialog if it's open
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Cancel the refresh timer
    _refreshTimer?.cancel();
    
    // Now we can safely disconnect using stored references without accessing context
    _socketService?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          // Refresh button
          IconButton(
            icon: _isRefreshing 
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _handleRefresh,
            tooltip: 'Refresh Data',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.admin_panel_settings, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Admin: ${authService.user?.name}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Admin Logout (Stops Server)',
            onPressed: _handleAdminLogout,
          ),
        ],
      ),
      body: IndexedStack(
        index: currentIndex,
        children: [
          _buildDashboardTab(),
          _buildMonitoringTab(),
          _buildExerciseManagementTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() => currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor),
            label: 'Monitor Students',
          ),
          BottomNavigationBarItem( 
            icon: Icon(Icons.assignment),
            label: 'Manage Exercises',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Admin Overview',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green[800],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Colors.white, size: 12),
                      SizedBox(width: 6),
                      Text(
                        'Server Online',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Stats cards
            Row(
              children: [
                _buildStatCard(
                  'Online Students',
                  onlineUsers.length.toString(),
                  Icons.people,
                  Colors.green,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Total Exercises',
                  analytics['totalExercises']?.toString() ?? '0',
                  Icons.assignment,
                  Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Active Sessions',
                  onlineUsers.length.toString(),
                  Icons.computer,
                  Colors.orange,
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            Row(
              children: [
                Text(
                  'Active Students',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Spacer(),
                Text(
                  'Total: ${onlineUsers.length}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Last updated: ${DateTime.now().toString().substring(11, 19)}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Container(
              height: 400,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Currently Online Students',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Spacer(),
                          if (_isRefreshing)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: onlineUsers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.people_outline,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No students online',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      onPressed: _handleRefresh,
                                      icon: Icon(Icons.refresh),
                                      label: Text('Refresh'),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: onlineUsers.length,
                                itemBuilder: (context, index) {
                                  final user = onlineUsers[index];
                                  final lastActive = user.lastActive;
                                  final timeDiff = lastActive != null 
                                      ? DateTime.now().difference(lastActive).inMinutes
                                      : null;
                                  
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.green,
                                      child: Text(
                                        user.name[0].toUpperCase(),
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    title: Text(user.name),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${user.batch} - ${user.section} (${user.enrollNumber})'),
                                        if (lastActive != null)
                                          Text(
                                            'Last active: ${timeDiff! < 1 ? "Just now" : "$timeDiff min ago"}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          )
                                        else
                                          Text(
                                            'Last active: Unknown',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.circle, color: Colors.green, size: 8),
                                          SizedBox(width: 4),
                                          Text(
                                            'Online',
                                            style: TextStyle(
                                              color: Colors.green[800],
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title, 
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonitoringTab() {
    return AdminMonitorScreen(onlineUsers: onlineUsers);
  }

  Widget _buildExerciseManagementTab() {
    return const ExerciseManagementScreen();
  }
}