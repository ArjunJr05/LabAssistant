import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  // Service references
  SocketService? _socketService;
  AuthService? _authService;
  ApiService? _apiService;
  
  // Status tracking
  Timer? _statusCheckTimer;
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  bool _socketConnected = false;
  bool _serverOnline = false;
  
  // Last update tracking
  DateTime? _lastDataUpdate;
  DateTime? _lastDataFetch;
  Map<String, dynamic>? _cachedAnalytics;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
      _initializeSocket();
      _setupSocketListeners();
      _startPeriodicRefresh();
      _fetchInitialData();
    });
  }

  void _initializeServices() {
    _socketService = Provider.of<SocketService>(context, listen: false);
    _authService = Provider.of<AuthService>(context, listen: false);
    _apiService = ApiService(_authService!);
  }

  void _initializeSocket() {
    if (_socketService == null || _authService == null) return;
    
    print('Admin connecting to socket...');
    _socketService!.connect();
    
    // Register admin login with socket
    _socketService!.socket?.emit('admin-login', {
      'enrollNumber': _authService!.user?.enrollNumber,
      'name': _authService!.user?.name,
      'role': _authService!.user?.role,
    });
  }

  void _setupSocketListeners() {
    if (_socketService?.socket == null) return;

    print('Setting up socket listeners for admin dashboard');

    // Connection status
    _socketService!.socket!.on('connect', (_) {
      print('Admin socket connected');
      _socketConnected = true;
      _serverOnline = true;
      if (mounted) setState(() {});
      
      // Immediately request online users when admin connects
      Timer(Duration(milliseconds: 500), () {
        _socketService!.socket!.emit('get-online-users');
        print('Requested online users from server');
      });
    });

    _socketService!.socket!.on('disconnect', (_) {
      print('Admin socket disconnected');
      _socketConnected = false;
      _serverOnline = false;
      if (mounted) setState(() {});
    });

    // Listen for student login events
    _socketService!.socket!.on('student-login', (data) {
      print('STUDENT LOGIN EVENT RECEIVED: $data');
      _handleUserConnected(data);
      // Force immediate refresh from database
      Future.delayed(Duration(milliseconds: 500), () {
        _fetchOnlineUsers();
      });
    });

    // Listen for student logout events
    _socketService!.socket!.on('student-logout', (data) {
      print('STUDENT LOGOUT EVENT RECEIVED: $data');
      _handleUserDisconnected(data);
      // Force immediate refresh from database
      Future.delayed(Duration(milliseconds: 500), () {
        _fetchOnlineUsers();
      });
    });

    // Listen for user connected/disconnected events
    _socketService!.socket!.on('user-connected', (data) {
      print('USER CONNECTED EVENT RECEIVED: $data');
      _handleUserConnected(data);
      Future.delayed(Duration(milliseconds: 500), () {
        _fetchOnlineUsers();
      });
    });

    _socketService!.socket!.on('user-disconnected', (data) {
      print('USER DISCONNECTED EVENT RECEIVED: $data');
      _handleUserDisconnected(data);
      Future.delayed(Duration(milliseconds: 500), () {
        _fetchOnlineUsers();
      });
    });

    // Listen for online users updates
    _socketService!.socket!.on('online-users', (data) {
      print('ONLINE USERS UPDATE RECEIVED: ${data is List ? data.length : 0} users');
      _updateOnlineUsersFromSocket(data);
    });

    _socketService!.socket!.on('user-status-update', (data) {
      print('USER STATUS UPDATE RECEIVED: ${data is List ? data.length : 0} users');
      if (data is List) {
        _updateOnlineUsersFromSocket(data);
      }
    });
  }

  void _startPeriodicRefresh() {
    // More frequent refresh for better real-time updates
    _refreshTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (mounted && !_isRefreshing) {
        final now = DateTime.now();
        final shouldRefresh = _lastDataFetch == null || 
            now.difference(_lastDataFetch!).inSeconds > 10 ||
            !_socketConnected;
        
        if (shouldRefresh) {
          print('Real-time refresh: Updating student data');
          _fetchOnlineUsers();
        }
      }
    });
  }

  void _handleUserConnected(dynamic data) {
    if (data == null) return;

    final enrollNumber = data['enrollNumber'] ?? data['enroll_number'];
    final name = data['name'];
    
    if (enrollNumber == null || name == null) return;

    print('Adding user: $name ($enrollNumber)');

    // Remove if exists, then add updated version
    onlineUsers.removeWhere((user) => user.enrollNumber == enrollNumber);
    
    // Add new user
    final newUser = User(
      id: data['id'] ?? 0,
      name: name,
      enrollNumber: enrollNumber,
      year: data['year'] ?? '',
      section: data['section'] ?? '',
      batch: data['batch'] ?? '',
      role: data['role'] ?? 'student',
      isOnline: true,
      lastActive: DateTime.now(),
    );

    onlineUsers.add(newUser);
    _lastDataUpdate = DateTime.now();

    if (mounted) {
      setState(() {});
      print('UI updated - ${onlineUsers.length} users online');
    }
  }

  void _handleUserDisconnected(dynamic data) {
    if (data == null) return;

    final enrollNumber = data['enrollNumber'] ?? data['enroll_number'];
    if (enrollNumber == null) return;

    print('Removing user: $enrollNumber');

    // Remove user from list
    final initialCount = onlineUsers.length;
    onlineUsers.removeWhere((user) => user.enrollNumber == enrollNumber);
    
    if (onlineUsers.length != initialCount) {
      _lastDataUpdate = DateTime.now();
      if (mounted) {
        setState(() {});
        print('UI updated - ${onlineUsers.length} users online');
      }
    }
  }

  void _updateOnlineUsersFromSocket(dynamic data) {
    if (data is List && mounted) {
      final socketUsers = <User>[];
      
      for (final userData in data) {
        if (userData is Map<String, dynamic>) {
          // Only include users that are actually marked as online
          final isOnline = userData['is_online'] ?? userData['isOnline'] ?? false;
          
          if (isOnline) {
            final user = User(
              id: userData['id'] ?? 0,
              name: userData['name'] ?? '',
              enrollNumber: userData['enroll_number'] ?? userData['enrollNumber'] ?? '',
              year: userData['year'] ?? '',
              section: userData['section'] ?? '',
              batch: userData['batch'] ?? '',
              role: userData['role'] ?? 'student',
              isOnline: true,
              lastActive: userData['last_active'] != null 
                  ? DateTime.tryParse(userData['last_active'].toString()) ?? DateTime.now()
                  : DateTime.now(),
            );
            socketUsers.add(user);
          }
        }
      }

      setState(() {
        onlineUsers = socketUsers;
        _lastDataUpdate = DateTime.now();
      });
      
      print('Updated from socket: ${onlineUsers.length} users online');
    }
  }

  Future<void> _fetchOnlineUsers() async {
    if (_isRefreshing || _apiService == null) return;

    print('Refreshing online users from database...');
    _isRefreshing = true;

    try {
      final users = await _apiService!.getOnlineUsers();
      
      // Filter to only include actually online users
      final actuallyOnlineUsers = users.where((user) => user.isOnline == true).toList();
      
      print('Database returned ${users.length} total, ${actuallyOnlineUsers.length} actually online');
      
      if (mounted) {
        setState(() {
          onlineUsers = actuallyOnlineUsers;
          _lastDataUpdate = DateTime.now();
          _lastDataFetch = DateTime.now();
        });
      }
    } catch (e) {
      print('Error refreshing online users: $e');
      
      // If API fails, clear the list to prevent showing stale data
      if (mounted) {
        setState(() {
          onlineUsers = [];
        });
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _fetchInitialData() async {
    print('Fetching initial data...');
    await Future.wait([
      _fetchOnlineUsers(),
      _loadAnalytics(),
    ]);
  }

  Future<void> _loadAnalytics() async {
    if (_apiService == null) return;
    
    // Reduced cache time for more frequent analytics updates
    if (_cachedAnalytics != null && _lastDataFetch != null) {
      final cacheAge = DateTime.now().difference(_lastDataFetch!);
      if (cacheAge.inSeconds < 30) { // Changed from 5 minutes to 30 seconds
        print('Using cached analytics data');
        if (mounted) {
          setState(() {
            analytics = _cachedAnalytics!;
          });
        }
        return;
      }
    }
    
    try {
      final data = await _apiService!.getAdminAnalytics();
      if (mounted) {
        setState(() {
          analytics = data;
          _cachedAnalytics = data;
          _lastDataFetch = DateTime.now();
        });
      }
      print('Loaded fresh analytics: $data');
    } catch (e) {
      print('Error loading analytics: $e');
      if (_cachedAnalytics != null && mounted) {
        setState(() {
          analytics = _cachedAnalytics!;
        });
        print('Using cached analytics as fallback');
      }
    }
  }

  Future<void> _handleRefresh() async {
    print('Manual refresh triggered');
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      // Force socket to request fresh data
      if (_socketConnected) {
        _socketService?.socket?.emit('get-online-users');
      }
      
      // Clean up any stale online users first
      await _cleanupStaleUsers();
      
      await Future.wait([
        _fetchOnlineUsers(),
        _loadAnalytics(),
      ]);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data refreshed - ${onlineUsers.length} students online'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Refresh error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _cleanupStaleUsers() async {
    try {
      if (_apiService != null) {
        // Call the cleanup endpoint to fix stale online statuses
        final response = await _apiService!.retryRequest(() async {
          final authService = Provider.of<AuthService>(context, listen: false);
          final apiUrl = await authService.serverManager.serverUrl;
          
          final response = await http.post(
            Uri.parse('$apiUrl/api/admin/cleanup-stale-users'),
            headers: authService.authHeaders,
          );
          
          return response;
        });
        
        print('Stale users cleaned up');
      }
    } catch (e) {
      print('Error cleaning up stale users: $e');
    }
  }

  Future<void> _handleAdminLogout() async {
    if (_authService == null || _socketService == null || _apiService == null) {
      return;
    }

    try {
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
              Text('This will:'),
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

      if (shouldLogout != true) return;
      
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
            ],
          ),
        ),
      );

      // Emit admin logout
      if (_socketConnected) {
        _socketService!.socket?.emit('admin-logout', {
          'message': 'Admin is logging out. Server will shut down.',
          'timestamp': DateTime.now().toIso8601String(),
        });
        await Future.delayed(Duration(milliseconds: 500));
      }

      // Send shutdown notification
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
    print('Disposing AdminDashboard');
    _statusCheckTimer?.cancel();
    _refreshTimer?.cancel();
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
            tooltip: 'Force Refresh & Cleanup',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _serverOnline ? Icons.cloud_done : Icons.cloud_off,
                    size: 20,
                    color: _serverOnline ? Colors.green : Colors.red,
                  ),
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
                    color: _serverOnline ? Colors.green[800] : Colors.red[800],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _serverOnline ? Icons.circle : Icons.circle_outlined, 
                        color: Colors.white, 
                        size: 12
                      ),
                      SizedBox(width: 6),
                      Text(
                        _serverOnline ? 'Server Online' : 'Server Offline',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Server status details
            if (!_serverOnline)
              Container(
                margin: EdgeInsets.only(top: 16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Server offline - Socket: $_socketConnected | Students may not be able to connect',
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),
              
            const SizedBox(height: 20),
            
            // Stats cards
            Row(
              children: [
                _buildStatCard(
                  'Online Students',
                  onlineUsers.length.toString(),
                  Icons.people,
                  _serverOnline ? Colors.green : Colors.red,
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
                  'Server Status',
                  _serverOnline ? 'Online' : 'Offline',
                  _serverOnline ? Icons.check_circle : Icons.error,
                  _serverOnline ? Colors.green : Colors.red,
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
                if (_lastDataUpdate != null)
                  Text(
                    'Updated: ${DateTime.now().difference(_lastDataUpdate!).inSeconds}s ago',
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
                          IconButton(
                            icon: Icon(Icons.cleaning_services, size: 20),
                            onPressed: () async {
                              await _cleanupStaleUsers();
                              _handleRefresh();
                            },
                            tooltip: 'Cleanup Stale Users',
                          ),
                          IconButton(
                            icon: Icon(Icons.refresh, size: 20),
                            onPressed: _handleRefresh,
                            tooltip: 'Refresh Now',
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
                                    Text(
                                      _serverOnline 
                                          ? 'Waiting for students to connect...' 
                                          : 'Server offline - check connection',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    SizedBox(height: 16),
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
                                      backgroundColor: user.isOnline ? Colors.green : Colors.grey,
                                      child: Text(
                                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
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
                                          ),
                                        Text(
                                          'DB Status: ${user.isOnline ? "Online" : "Offline"}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: user.isOnline ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: user.isOnline ? Colors.green[100] : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.circle, 
                                            color: user.isOnline ? Colors.green : Colors.grey, 
                                            size: 8
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            user.isOnline ? 'Online' : 'Offline',
                                            style: TextStyle(
                                              color: user.isOnline ? Colors.green[800] : Colors.grey[600],
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