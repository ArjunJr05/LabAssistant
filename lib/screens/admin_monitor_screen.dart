import 'package:flutter/material.dart';
import 'package:labassistant/services/socket_services.dart';
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
  }

  @override
  Widget build(BuildContext context) {
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
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Online Students',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.onlineUsers.length,
                    itemBuilder: (context, index) {
                      final user = widget.onlineUsers[index];
                      final isActive = studentActivity.containsKey(user.enrollNumber);
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive ? Colors.green : Colors.grey,
                          child: Text(user.name[0].toUpperCase()),
                        ),
                        title: Text(user.name),
                        subtitle: Text('${user.enrollNumber} - ${user.batch}${user.section}'),
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
          child: selectedUser == null
              ? const Center(
                  child: Text(
                    'Select a student to monitor',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : _buildStudentMonitor(),
        ),
      ],
    );
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
        
        // Activity feed
        Expanded(
          child: Padding(
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
                              Text(
                                'Code Execution',
                                style: const TextStyle(fontWeight: FontWeight.bold),
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
                
                const SizedBox(height: 16),
                
                // Screen monitoring placeholder
                Card(
                  child: Container(
                    height: 200,
                    padding: const EdgeInsets.all(16),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.monitor,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Screen Monitoring',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Live screen view will appear here',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
}