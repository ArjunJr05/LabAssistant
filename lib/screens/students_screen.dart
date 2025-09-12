// lib/screens/student_dashboard.dart
import 'package:flutter/material.dart';
import 'package:labassistant/models/excercise_model.dart';
import 'package:labassistant/services/api_services.dart';
import 'package:labassistant/services/socket_services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/subject_model.dart';
import 'code_editor_screen.dart' hide Exercise;

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  List<Subject> subjects = [];
  List<Exercise> exercises = [];
  Subject? selectedSubject;
  bool isLoading = false;
  Set<int> completedExerciseIds = {};
  
  // Store service references to avoid context access in dispose
  SocketService? _socketService;
  AuthService? _authService;

  @override
  void initState() {
    super.initState();
    // Store service references early
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _socketService = Provider.of<SocketService>(context, listen: false);
      _authService = Provider.of<AuthService>(context, listen: false);
      
      _checkOnlineStatus();
      _initializeSocket();
      _loadSubjects();
    });
  }

  Future<void> _checkOnlineStatus() async {
    if (_authService == null) return;
    
    // Check if user is still online in database
    if (_authService!.user?.isOnline == false) {
      // User is marked offline, redirect to role selection
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/role-selection');
        }
      });
      return;
    }
  }

  void _initializeSocket() {
    if (_socketService == null || _authService == null) return;
    
    _socketService!.connect();
    _socketService!.socket?.emit('user-login', {
      'enrollNumber': _authService!.user?.enrollNumber,
      'name': _authService!.user?.name,
      'role': _authService!.user?.role,
    });
    
    // Listen for admin shutdown events
    _socketService!.socket?.on('admin-shutdown', (data) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin has logged out. Redirecting to login...'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Redirect to role selection after a short delay
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/role-selection');
          }
        });
      }
    });
  }

  Future<void> _loadSubjects() async {
    if (!mounted) return;
    
    setState(() => isLoading = true);
    
    try {
      if (_authService != null) {
        final apiService = ApiService(_authService!);
        subjects = await apiService.getSubjects();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading subjects: $e')),
        );
      }
    }
    
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadExercises(int subjectId) async {
    if (!mounted) return;
    
    setState(() => isLoading = true);
    
    try {
      if (_authService != null) {
        final apiService = ApiService(_authService!);
        exercises = await apiService.getExercisesBySubject(subjectId);
        
        // Load completed exercises
        final completedExercises = await apiService.getCompletedExercises();
        completedExerciseIds = completedExercises
            .map<int>((exercise) => exercise['exercise_id'] as int)
            .toSet();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading exercises: $e')),
        );
      }
    }
    
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  // Enhanced logout method that properly handles student logout
  Future<void> _handleLogout() async {
    try {
      print('🔄 Student logout initiated...');
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Logging out...'),
            ],
          ),
        ),
      );

      // 1. Emit logout event through socket to notify server
      if (_socketService?.isConnected == true && _authService?.user != null) {
        print('📡 Emitting user logout event...');
        _socketService!.socket?.emit('user-logout', {
          'enrollNumber': _authService!.user!.enrollNumber,
          'name': _authService!.user!.name,
          'role': _authService!.user!.role,
        });
        
        // Give socket time to send the message
        await Future.delayed(Duration(milliseconds: 500));
      }

      // 2. Disconnect socket connection
      print('🔌 Disconnecting socket...');
      _socketService?.disconnect();

      // 3. Call auth service logout (this will update is_online to false)
      print('🔓 Calling auth service logout...');
      await _authService?.logout();

      // 4. Close loading dialog if still mounted
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // 5. Navigate to role selection
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/role-selection');
      }

      print('✅ Student logout completed successfully');
      
    } catch (e) {
      print('❌ Error during logout: $e');
      
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
    // Now we can safely disconnect using stored references
    _socketService?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                'Welcome, ${authService.user?.name ?? 'Student'}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout, // Use the enhanced logout method
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Sidebar with subjects
                Container(
                  width: 300,
                  color: Colors.grey[100],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Subjects',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: subjects.length,
                          itemBuilder: (context, index) {
                            final subject = subjects[index];
                            return ListTile(
                              title: Text(subject.name),
                              subtitle: Text(subject.code),
                              selected: selectedSubject?.id == subject.id,
                              onTap: () {
                                setState(() {
                                  selectedSubject = subject;
                                });
                                _loadExercises(subject.id);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Main content area
                Expanded(
                  child: selectedSubject == null
                      ? const Center(
                          child: Text(
                            'Select a subject to view exercises',
                            style: TextStyle(fontSize: 18),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                '${selectedSubject!.name} - Exercises',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: exercises.isEmpty
                                  ? const Center(
                                      child: Text('No exercises available'),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: exercises.length,
                                      itemBuilder: (context, index) {
                                        final exercise = exercises[index];
                                        final isCompleted = completedExerciseIds.contains(exercise.id);
                                        
                                        return Card(
                                          child: ListTile(
                                            leading: isCompleted 
                                                ? Icon(
                                                    Icons.check_circle,
                                                    color: Colors.green,
                                                    size: 24,
                                                  )
                                                : Icon(
                                                    Icons.radio_button_unchecked,
                                                    color: Colors.grey,
                                                    size: 24,
                                                  ),
                                            title: Row(
                                              children: [
                                                Expanded(child: Text(exercise.title)),
                                                if (isCompleted)
                                                  Container(
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green,
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      'COMPLETED',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            subtitle: Text(exercise.description),
                                            trailing: Chip(
                                              label: Text(exercise.difficultyLevel),
                                              backgroundColor: _getDifficultyColor(
                                                exercise.difficultyLevel,
                                              ),
                                            ),
                                            onTap: () async {
                                              final result = await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      CodeEditorScreen(
                                                    exercise: exercise,
                                                  ),
                                                ),
                                              );
                                              
                                              // Refresh completion status if exercise was completed
                                              if (result == true && selectedSubject != null) {
                                                _loadExercises(selectedSubject!.id);
                                              }
                                            },
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green[200]!;
      case 'medium':
        return Colors.orange[200]!;
      case 'hard':
        return Colors.red[200]!;
      default:
        return Colors.grey[200]!;
    }
  }
}