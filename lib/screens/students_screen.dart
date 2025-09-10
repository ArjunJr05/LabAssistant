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

  @override
  void initState() {
    super.initState();
    _initializeSocket();
    _loadSubjects();
  }

  void _initializeSocket() {
    final socketService = Provider.of<SocketService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    
    socketService.connect();
    socketService.socket?.emit('user-login', {
      'enrollNumber': authService.user?.enrollNumber,
      'name': authService.user?.name,
      'role': authService.user?.role,
    });
  }

  Future<void> _loadSubjects() async {
    setState(() => isLoading = true);
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService(authService);
      subjects = await apiService.getSubjects();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading subjects: $e')),
        );
      }
    }
    
    setState(() => isLoading = false);
  }

  Future<void> _loadExercises(int subjectId) async {
    setState(() => isLoading = true);
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService(authService);
      exercises = await apiService.getExercisesBySubject(subjectId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading exercises: $e')),
        );
      }
    }
    
    setState(() => isLoading = false);
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
                'Welcome, ${authService.user?.name}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.logout();
            },
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
                                        return Card(
                                          child: ListTile(
                                            title: Text(exercise.title),
                                            subtitle: Text(exercise.description),
                                            trailing: Chip(
                                              label: Text(exercise.difficultyLevel),
                                              backgroundColor: _getDifficultyColor(
                                                exercise.difficultyLevel,
                                              ),
                                            ),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      CodeEditorScreen(
                                                    exercise: exercise,
                                                  ),
                                                ),
                                              );
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