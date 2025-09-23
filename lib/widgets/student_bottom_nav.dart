import 'package:flutter/material.dart';
import '../services/screen_monitor_service.dart';

class StudentBottomNav extends StatefulWidget {
  final Function(String clientId) onStudentTap;
  final String? selectedClientId;

  const StudentBottomNav({
    super.key,
    required this.onStudentTap,
    this.selectedClientId,
  });

  @override
  State<StudentBottomNav> createState() => _StudentBottomNavState();
}

class _StudentBottomNavState extends State<StudentBottomNav> {
  late ScreenMonitorService _screenService;

  @override
  void initState() {
    super.initState();
    _screenService = ScreenMonitorService();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClientInfo>>(
      stream: _screenService.clientsStream,
      builder: (context, snapshot) {
        final clients = snapshot.data ?? [];
        final connectedClients = clients.where((c) => c.isConnected).toList();

        if (connectedClients.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                offset: const Offset(0, -2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people_rounded,
                      color: Color(0xFF3B82F6),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Connected Students (${connectedClients.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Students list
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: connectedClients.length,
                  itemBuilder: (context, index) {
                    final client = connectedClients[index];
                    final isSelected = widget.selectedClientId == client.id;
                    
                    return GestureDetector(
                      onTap: () => widget.onStudentTap(client.id),
                      child: Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 12, bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? const Color(0xFF3B82F6).withOpacity(0.1)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected 
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFFE2E8F0),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: client.isConnected 
                                        ? const Color(0xFF10B981) 
                                        : const Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    client.computerName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected 
                                          ? const Color(0xFF3B82F6)
                                          : const Color(0xFF1E293B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              client.userName,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
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
        );
      },
    );
  }
}
