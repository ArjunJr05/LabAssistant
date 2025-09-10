import 'package:flutter/material.dart';
import 'package:labassistant/services/api_services.dart';
import 'package:labassistant/services/socket_services.dart';
import 'package:provider/provider.dart';
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
  Map<String, dynamic> analytics = {};

  @override
  void initState() {
    super.initState();
    _initializeSocket();
    _loadAnalytics();
  }

  void _initializeSocket() {
    final socketService = Provider.of<SocketService>(context, listen: false);
    socketService.connect();
    
    socketService.socket?.on('user-status-update', (data) {
      setState(() {
        onlineUsers = (data as List)
            .map((user) => User.fromJson(user))
            .toList();
      });
    });

    socketService.socket?.on('student-activity', (data) {
      // Handle real-time student activity
      print('Student activity: $data');
    });
  }

  Future<void> _loadAnalytics() async {
    try {
      // Load analytics data
      // This would be implemented in your API
    } catch (e) {
      print('Error loading analytics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                'Admin: ${authService.user?.name}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authService.logout(),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: Theme.of(context).textTheme.headlineMedium,
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
                '12', // This would come from API
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
          
          Text(
            'Batch Performance',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Activity',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: onlineUsers.length,
                        itemBuilder: (context, index) {
                          final user = onlineUsers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(user.name[0].toUpperCase()),
                            ),
                            title: Text(user.name),
                            subtitle: Text('${user.batch} - ${user.section}'),
                            trailing: const Chip(
                              label: Text('Online'),
                              backgroundColor: Colors.green,
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
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
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