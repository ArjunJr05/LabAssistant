import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:labassistant/services/socket_services.dart';
import 'package:labassistant/services/api_services.dart';
import 'package:labassistant/services/auth_service.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';

class AdminMonitorScreen extends StatefulWidget {
  final List<User> onlineUsers;

  const AdminMonitorScreen({super.key, required this.onlineUsers});

  @override
  State<AdminMonitorScreen> createState() => _AdminMonitorScreenState();
}

class _AdminMonitorScreenState extends State<AdminMonitorScreen> {
  User? selectedUser;
  Map<String, dynamic> studentActivity = {};
  List<Map<String, dynamic>> studentExercises = [];
  bool isLoadingExercises = false;
  Map<String, bool> expandedActivities = {}; // Track expanded state of activities

  @override
  void initState() {
    super.initState();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    final socketService = Provider.of<SocketService>(context, listen: false);
    
    socketService.socket?.on('student-activity', (data) {
      setState(() {
        studentActivity[data['userId']] = data;
      });
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
    // Filter only students (exclude admins from online users)
    final onlineStudents = widget.onlineUsers.where((user) => user.role == 'student').toList();
    
    return Row(
      children: [
        // Student list
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Online Students (${onlineStudents.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: onlineStudents.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No students online',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Students will appear here when they log in',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: onlineStudents.length,
                          itemBuilder: (context, index) {
                            final user = onlineStudents[index];
                            final isActive = studentActivity.containsKey(user.enrollNumber);
                            final lastActivity = studentActivity[user.enrollNumber];
                            
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isActive ? Colors.green : Colors.blue,
                                child: Text(user.name[0].toUpperCase()),
                              ),
                              title: Text(user.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${user.enrollNumber} - ${user.batch}${user.section}'),
                                  if (lastActivity != null)
                                    Text(
                                      'Last activity: ${_formatTime(lastActivity['timestamp'])}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.green,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    color: Colors.green,
                                    size: 12,
                                  ),
                                  const Text('Online', style: TextStyle(fontSize: 10)),
                                ],
                              ),
                              selected: selectedUser?.id == user.id,
                              onTap: () {
                                setState(() {
                                  selectedUser = user;
                                });
                                _loadStudentExercises(user.id);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        
        // Student monitor panel
        Expanded(
          flex: 2,
          child: onlineStudents.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.monitor_outlined,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 24),
                      Text(
                        'No students to monitor',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Students will appear here when they log in',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : selectedUser == null
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.touch_app,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Select a student to monitor',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _buildStudentMonitor(),
        ),
      ],
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading exercises: $e')),
      );
    } finally {
      setState(() {
        isLoadingExercises = false;
      });
    }
  }

  Widget _buildStudentMonitor() {
    final activity = studentActivity[selectedUser!.enrollNumber];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Student info header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue[50],
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                child: Text(
                  selectedUser!.name[0].toUpperCase(),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedUser!.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('Enrollment: ${selectedUser!.enrollNumber}'),
                  Text('Batch: ${selectedUser!.batch} - Section: ${selectedUser!.section}'),
                ],
              ),
              const Spacer(),
              const Chip(
                label: Text('Monitoring'),
                backgroundColor: Colors.green,
              ),
            ],
          ),
        ),
        
        // Exercise list and activity feed
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Exercises', icon: Icon(Icons.assignment)),
                    Tab(text: 'Activity', icon: Icon(Icons.timeline)),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildExercisesList(),
                      _buildActivityFeed(activity),
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
      return const Center(child: CircularProgressIndicator());
    }
    
    if (studentExercises.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No exercises found', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: studentExercises.length,
      itemBuilder: (context, index) {
        final exercise = studentExercises[index];
        final isCompleted = exercise['completed'] == true;
        final score = exercise['score'];
        final submittedAt = exercise['submitted_at'];
        final activityCount = exercise['activity_count'] ?? 0;
        
        return Card(
          child: ListTile(
            leading: Icon(
              isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isCompleted ? Colors.green : Colors.grey,
              size: 24,
            ),
            title: Row(
              children: [
                Expanded(child: Text(exercise['title'] ?? 'Unknown Exercise')),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'COMPLETED',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Subject: ${exercise['subject_name'] ?? 'Unknown'}'),
                Text('Activities: $activityCount'),
                if (isCompleted && score != null)
                  Text('Score: $score%', style: const TextStyle(color: Colors.green)),
                if (isCompleted && submittedAt != null)
                  Text('Completed: ${_formatDateTime(submittedAt)}'),
              ],
            ),
            trailing: isCompleted
                ? Chip(
                    label: Text('$score%'),
                    backgroundColor: Colors.green[100],
                  )
                : const Chip(
                    label: Text('In Progress'),
                    backgroundColor: Colors.orange,
                  ),
            onTap: () => _showExerciseDetails(exercise),
          ),
        );
      },
    );
  }
  
  Widget _buildActivityFeed(Map<String, dynamic>? activity) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          if (activity != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.code, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Code Execution',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          _formatTime(activity['timestamp']),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Exercise ID: ${activity['data']['exerciseId']}'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        activity['data']['code'],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        maxLines: 10,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 8),
                    Text('No recent activity'),
                  ],
                ),
              ),
            ),
          ],
        ],
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
        builder: (context) => AlertDialog(
          title: Text(exercise['title'] ?? 'Exercise Details'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subject: ${exercise['subject_name']}'),
                  const SizedBox(height: 8),
                  Text('Status: ${exercise['completed'] ? 'Completed' : 'In Progress'}'),
                  if (exercise['completed']) ...[
                    Text('Score: ${exercise['score']}%'),
                    Text('Submitted: ${_formatDateTime(exercise['submitted_at'])}'),
                  ],
                  const SizedBox(height: 16),
                  const Text('Activities:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...progress['activities'].asMap().entries.map<Widget>((entry) {
                    final index = entry.key;
                    final activity = entry.value;
                    final activityKey = '${exercise['id']}_$index';
                    final isExpanded = expandedActivities[activityKey] ?? false;
                    
                    return Card(
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                expandedActivities[activityKey] = !isExpanded;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        activity['activity_type'] == 'submission'
                                            ? Icons.send
                                            : Icons.play_arrow,
                                        size: 16,
                                        color: activity['activity_type'] == 'submission'
                                            ? Colors.green
                                            : Colors.blue,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          activity['activity_type'] == 'submission'
                                              ? 'Submission'
                                              : 'Test Run',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Text(
                                        _formatDateTime(activity['created_at']),
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        isExpanded ? Icons.expand_less : Icons.expand_more,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: activity['status'] == 'passed' 
                                              ? Colors.green.withOpacity(0.1)
                                              : activity['status'] == 'failed'
                                                  ? Colors.red.withOpacity(0.1)
                                                  : Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: activity['status'] == 'passed' 
                                                ? Colors.green
                                                : activity['status'] == 'failed'
                                                    ? Colors.red
                                                    : Colors.orange,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          'Status: ${activity['status']}',
                                          style: TextStyle(
                                            color: activity['status'] == 'passed' 
                                                ? Colors.green[700]
                                                : activity['status'] == 'failed'
                                                    ? Colors.red[700]
                                                    : Colors.orange[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (activity['score'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.blue, width: 1),
                                          ),
                                          child: Text(
                                            'Score: ${activity['score']}%',
                                            style: TextStyle(
                                              color: Colors.blue[700],
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      if (activity['tests_passed'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.purple, width: 1),
                                          ),
                                          child: Text(
                                            'Tests: ${activity['tests_passed']}/${activity['total_tests']}',
                                            style: TextStyle(
                                              color: Colors.purple[700],
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
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
                            const Divider(height: 1),
                            _buildCodeDisplay(activity),
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
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading exercise details: $e')),
      );
    }
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
  
  Widget _buildCodeDisplay(Map<String, dynamic> activity) {
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