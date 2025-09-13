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

class _StudentDashboardState extends State<StudentDashboard> with TickerProviderStateMixin {
  List<Subject> subjects = [];
  List<Exercise> exercises = [];
  Subject? selectedSubject;
  bool isLoading = false;
  bool isLoadingExercises = false;
  Set<int> completedExerciseIds = {};
  late AnimationController _fadeController;
  late AnimationController _slideController;
  
  // Store service references to avoid context access in dispose
  SocketService? _socketService;
  AuthService? _authService;
  ApiService? _apiService;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Store service references early
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _socketService = Provider.of<SocketService>(context, listen: false);
      _authService = Provider.of<AuthService>(context, listen: false);
      _apiService = _authService != null ? ApiService(_authService!) : null;
      
      _checkOnlineStatus();
      _initializeSocket();
      _loadSubjects();
      
      // Start animations
      _fadeController.forward();
      _slideController.forward();
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
        _showAdminShutdownDialog();
      }
    });
  }

  void _showAdminShutdownDialog() {
    showDialog(
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
              'Server Shutdown',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ],
        ),
        content: const Text(
          'Admin has logged out. You will be redirected to the login screen.',
          style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/role-selection');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSubjects() async {
    if (!mounted) return;
    
    setState(() => isLoading = true);
    
    try {
      if (_apiService != null) {
        subjects = await _apiService!.getSubjects();
        print('✅ Loaded ${subjects.length} subjects');
      }
    } catch (e) {
      print('❌ Error loading subjects: $e');
      if (mounted) {
        _showErrorSnackBar('Error loading subjects: $e');
      }
    }
    
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadExercises(int subjectId) async {
    if (!mounted) return;
    
    setState(() => isLoadingExercises = true);
    
    try {
      if (_apiService != null) {
        print('🔄 Loading exercises for subject ID: $subjectId');
        
        // Load exercises
        exercises = await _apiService!.getExercisesBySubject(subjectId);
        print('✅ Loaded ${exercises.length} exercises');
        
        // Load completed exercises with improved error handling
        await _loadCompletedExercises();
      }
    } catch (e) {
      print('❌ Error loading exercises: $e');
      if (mounted) {
        _showErrorSnackBar('Error loading exercises: $e');
      }
    }
    
    if (mounted) {
      setState(() => isLoadingExercises = false);
    }
  }

  Future<void> _loadCompletedExercises() async {
    try {
      if (_apiService != null && _authService?.user != null) {
        print('🔄 Loading completed exercises for user: ${_authService!.user!.enrollNumber}');
        
        final completedExercises = await _apiService!.getCompletedExercises();
        print('📋 Raw completed exercises data: $completedExercises');
        
        Set<int> newCompletedIds = {};
        
        for (var item in completedExercises) {
          int? exerciseId;
          
          if (item is Map<String, dynamic>) {
            // Try different possible key names for exercise ID
            var rawId = item['exercise_id'] ?? 
                       item['exerciseId'] ?? 
                       item['id'] ??
                       item['exercise']?['id'];
            
            if (rawId is int) {
              exerciseId = rawId;
            } else if (rawId is String) {
              exerciseId = int.tryParse(rawId);
            }
            
            // Also check if this item represents a passed submission
            var status = item['status'];
            if (status != null && status != 'passed') {
              continue; // Skip non-passed submissions
            }
          } else if (item is int) {
            exerciseId = item as int?;
          }
          
          if (exerciseId != null) {
            newCompletedIds.add(exerciseId);
          }
        }
        
        print('✅ Processed completed exercise IDs: $newCompletedIds');
        
        if (mounted) {
          setState(() {
            completedExerciseIds = newCompletedIds;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading completed exercises: $e');
    }
  }

  // Method to mark exercise as completed with improved API integration
  Future<void> _markExerciseCompleted(int exerciseId) async {
    try {
      print('🔄 Marking exercise $exerciseId as completed');
      
      // Update local state immediately for better UX
      if (mounted) {
        setState(() {
          completedExerciseIds.add(exerciseId);
        });
      }
      
      // Reload completed exercises to ensure accuracy
      await _loadCompletedExercises();
      
      print('✅ Exercise $exerciseId completion status updated');
    } catch (e) {
      print('❌ Error updating exercise completion status: $e');
      if (mounted) {
        _showErrorSnackBar('Error updating completion status');
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      print('🔄 Student logout initiated...');
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFF2563EB)),
              const SizedBox(width: 16),
              const Text(
                'Logging out...',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1E3A8A),
                ),
              ),
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
        await Future.delayed(const Duration(milliseconds: 500));
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

  // Add this method to your _StudentDashboardState class (or _StudentsScreenState if that's where the error is)
Future<void> _refreshCompletionStatus() async {
  try {
    if (selectedSubject != null && _apiService != null) {
      print('🔄 Refreshing completion status...');
      
      // Reload completed exercises from the database
      await _loadCompletedExercises();
      
      // Trigger UI rebuild to reflect changes
      if (mounted) {
        setState(() {});
      }
      
      print('✅ Completion status refreshed');
    }
  } catch (e) {
    print('❌ Error refreshing completion status: $e');
  }
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
    _fadeController.dispose();
    _slideController.dispose();
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
          'Student Dashboard',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
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
                Icon(Icons.person_outline, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Welcome, ${authService.user?.name ?? 'Student'}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2563EB),
              ),
            )
          : FadeTransition(
              opacity: _fadeController,
              child: Row(
                children: [
                  // Enhanced Sidebar with subjects
                  Container(
                    width: 320,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x0F000000),
                          offset: Offset(2, 0),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Sidebar Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
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
                                  Icons.book_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Subjects',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Subjects List
                        Expanded(
                          child: subjects.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.library_books_outlined,
                                        size: 48,
                                        color: Color(0xFFCBD5E1),
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'No subjects available',
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: subjects.length,
                                  itemBuilder: (context, index) {
                                    final subject = subjects[index];
                                    final isSelected = selectedSubject?.id == subject.id;
                                    
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected 
                                            ? const Color(0xFF3B82F6).withOpacity(0.1)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF3B82F6)
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFF3B82F6)
                                                : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.subject,
                                            color: isSelected 
                                                ? Colors.white
                                                : const Color(0xFF64748B),
                                            size: 20,
                                          ),
                                        ),
                                        title: Text(
                                          subject.name,
                                          style: TextStyle(
                                            fontWeight: isSelected 
                                                ? FontWeight.bold 
                                                : FontWeight.w500,
                                            color: isSelected 
                                                ? const Color(0xFF1E40AF) 
                                                : const Color(0xFF1E293B),
                                            fontSize: 15,
                                          ),
                                        ),
                                        subtitle: Text(
                                          subject.code,
                                          style: TextStyle(
                                            color: isSelected 
                                                ? const Color(0xFF3B82F6) 
                                                : const Color(0xFF64748B),
                                            fontSize: 13,
                                          ),
                                        ),
                                        onTap: () {
                                          setState(() {
                                            selectedSubject = subject;
                                          });
                                          _loadExercises(subject.id);
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Enhanced Main content area
                  Expanded(
                    child: selectedSubject == null
                        ? Center(
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.3),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: _slideController,
                                curve: Curves.easeOutCubic,
                              )),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(32),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x0A000000),
                                          offset: Offset(0, 4),
                                          blurRadius: 20,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.menu_book_rounded,
                                          size: 80,
                                          color: const Color(0xFF3B82F6).withOpacity(0.6),
                                        ),
                                        const SizedBox(height: 20),
                                        const Text(
                                          'Select a Subject',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Choose a subject from the sidebar to view exercises',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Color(0xFF64748B),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              // Enhanced Header
                              Container(
                                width: double.infinity,
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
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.assignment_outlined,
                                        color: Color(0xFF3B82F6),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            selectedSubject!.name,
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Code: ${selectedSubject!.code}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (exercises.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF059669),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${completedExerciseIds.where((id) => exercises.any((e) => e.id == id)).length}/${exercises.length} Completed',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    if (isLoadingExercises)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 16),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF3B82F6),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              
                              // Enhanced Exercises list
                              Expanded(
                                child: isLoadingExercises
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF3B82F6),
                                        ),
                                      )
                                    : exercises.isEmpty
                                        ? Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.assignment_outlined,
                                                  size: 64,
                                                  color: const Color(0xFF94A3B8).withOpacity(0.6),
                                                ),
                                                const SizedBox(height: 16),
                                                const Text(
                                                  'No exercises available',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                const Text(
                                                  'Exercises for this subject will appear here',
                                                  style: TextStyle(
                                                    color: Color(0xFF94A3B8),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : ListView.builder(
                                            padding: const EdgeInsets.all(20),
                                            itemCount: exercises.length,
                                            itemBuilder: (context, index) {
                                              final exercise = exercises[index];
                                              final isCompleted = completedExerciseIds.contains(exercise.id);
                                              
                                              return AnimatedContainer(
                                                duration: const Duration(milliseconds: 300),
                                                curve: Curves.easeOutCubic,
                                                margin: const EdgeInsets.only(bottom: 16),
                                                child: Card(
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                    side: BorderSide(
                                                      color: isCompleted
                                                          ? const Color(0xFF059669).withOpacity(0.3)
                                                          : const Color(0xFFE2E8F0),
                                                      width: isCompleted ? 2 : 1,
                                                    ),
                                                  ),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(16),
                                                      gradient: isCompleted
                                                          ? LinearGradient(
                                                              begin: Alignment.topLeft,
                                                              end: Alignment.bottomRight,
                                                              colors: [
                                                                const Color(0xFF059669).withOpacity(0.05),
                                                                Colors.white,
                                                              ],
                                                            )
                                                          : null,
                                                      color: isCompleted ? null : Colors.white,
                                                    ),
                                                    child: ListTile(
                                                      contentPadding: const EdgeInsets.all(20),
                                                      leading: AnimatedContainer(
                                                        duration: const Duration(milliseconds: 300),
                                                        width: 48,
                                                        height: 48,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          gradient: isCompleted 
                                                              ? const LinearGradient(
                                                                  colors: [
                                                                    Color(0xFF10B981),
                                                                    Color(0xFF059669),
                                                                  ],
                                                                )
                                                              : LinearGradient(
                                                                  colors: [
                                                                    const Color(0xFF3B82F6).withOpacity(0.1),
                                                                    const Color(0xFF1E40AF).withOpacity(0.1),
                                                                  ],
                                                                ),
                                                          boxShadow: isCompleted
                                                              ? [
                                                                  BoxShadow(
                                                                    color: const Color(0xFF10B981).withOpacity(0.3),
                                                                    offset: const Offset(0, 4),
                                                                    blurRadius: 12,
                                                                  ),
                                                                ]
                                                              : null,
                                                        ),
                                                        child: Icon(
                                                          isCompleted 
                                                              ? Icons.check_rounded
                                                              : Icons.code_rounded,
                                                          color: isCompleted 
                                                              ? Colors.white
                                                              : const Color(0xFF3B82F6),
                                                          size: 24,
                                                        ),
                                                      ),
                                                      title: Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              exercise.title,
                                                              style: TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 18,
                                                                color: isCompleted
                                                                    ? const Color(0xFF059669)
                                                                    : const Color(0xFF1E293B),
                                                              ),
                                                            ),
                                                          ),
                                                          if (isCompleted) ...[
                                                            const SizedBox(width: 12),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                horizontal: 12, vertical: 6),
                                                              decoration: BoxDecoration(
                                                                gradient: const LinearGradient(
                                                                  colors: [
                                                                    Color(0xFF10B981),
                                                                    Color(0xFF059669),
                                                                  ],
                                                                ),
                                                                borderRadius: BorderRadius.circular(20),
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color: const Color(0xFF10B981).withOpacity(0.3),
                                                                    offset: const Offset(0, 2),
                                                                    blurRadius: 6,
                                                                  ),
                                                                ],
                                                              ),
                                                              child: const Text(
                                                                'COMPLETED',
                                                                style: TextStyle(
                                                                  color: Colors.white,
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.bold,
                                                                  letterSpacing: 0.5,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      subtitle: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          const SizedBox(height: 8),
                                                          Text(
                                                            exercise.description,
                                                            style: const TextStyle(
                                                              color: Color(0xFF64748B),
                                                              fontSize: 14,
                                                              height: 1.4,
                                                            ),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          const SizedBox(height: 12),
                                                          Row(
                                                            children: [
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(
                                                                  horizontal: 12, vertical: 6),
                                                                decoration: BoxDecoration(
                                                                  color: _getDifficultyColor(
                                                                    exercise.difficultyLevel,
                                                                  ),
                                                                  borderRadius: BorderRadius.circular(20),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    Icon(
                                                                      _getDifficultyIcon(exercise.difficultyLevel),
                                                                      size: 14,
                                                                      color: _getDifficultyTextColor(exercise.difficultyLevel),
                                                                    ),
                                                                    const SizedBox(width: 4),
                                                                    Text(
                                                                      exercise.difficultyLevel.toUpperCase(),
                                                                      style: TextStyle(
                                                                        fontSize: 11,
                                                                        fontWeight: FontWeight.bold,
                                                                        color: _getDifficultyTextColor(exercise.difficultyLevel),
                                                                        letterSpacing: 0.5,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              const Spacer(),
                                                              if (isCompleted)
                                                                Container(
                                                                  padding: const EdgeInsets.all(6),
                                                                  decoration: BoxDecoration(
                                                                    color: const Color(0xFF10B981).withOpacity(0.1),
                                                                    shape: BoxShape.circle,
                                                                  ),
                                                                  child: const Icon(
                                                                    Icons.verified_rounded,
                                                                    color: Color(0xFF10B981),
                                                                    size: 16,
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                      trailing: Container(
                                                        padding: const EdgeInsets.all(8),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: const Icon(
                                                          Icons.arrow_forward_ios_rounded,
                                                          color: Color(0xFF3B82F6),
                                                          size: 16,
                                                        ),
                                                      ),
                                                      onTap: () async {
                                                        final result = await Navigator.push(
                                                          context,
                                                          PageRouteBuilder(
                                                            pageBuilder: (context, animation, secondaryAnimation) =>
                                                                CodeEditorScreen(exercise: exercise),
                                                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                              const begin = Offset(1.0, 0.0);
                                                              const end = Offset.zero;
                                                              const curve = Curves.easeInOutCubic;
                                                              
                                                              var tween = Tween(begin: begin, end: end).chain(
                                                                CurveTween(curve: curve),
                                                              );
                                                              
                                                              return SlideTransition(
                                                                position: animation.drive(tween),
                                                                child: child,
                                                              );
                                                            },
                                                            transitionDuration: const Duration(milliseconds: 400),
                                                          ),
                                                        );
                                                        
                                                        // Always refresh completion status after returning from code editor
                                                        print('🔄 Returned from code editor, refreshing completion status...');
                                                        await _refreshCompletionStatus();
                                                        
                                                        // Handle the result from code editor
                                                        if (result == true && !isCompleted) {
                                                          // Exercise was completed for the first time
                                                          print('✅ Exercise ${exercise.id} completed successfully!');
                                                          
                                                          // Force refresh the completion data
                                                          await _loadCompletedExercises();
                                                          
                                                          // Show success message
                                                          _showSuccessSnackBar('Exercise completed successfully!');
                                                        } else if (result == true && isCompleted) {
                                                          // Exercise was already completed, just refreshed
                                                          print('🔄 Exercise ${exercise.id} status refreshed');
                                                        }
                                                      },
                                                    ),
                                                  ),
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
    ));
  }

  // Enhanced color methods for better UI
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const Color(0xFF10B981).withOpacity(0.1);
      case 'medium':
        return const Color(0xFFF59E0B).withOpacity(0.1);
      case 'hard':
        return const Color(0xFFDC2626).withOpacity(0.1);
      default:
        return const Color(0xFF6B7280).withOpacity(0.1);
    }
  }

  Color _getDifficultyTextColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const Color(0xFF10B981);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'hard':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getDifficultyIcon(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Icons.trending_down_rounded;
      case 'medium':
        return Icons.trending_flat_rounded;
      case 'hard':
        return Icons.trending_up_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}