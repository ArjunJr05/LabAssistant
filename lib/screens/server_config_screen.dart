import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class ServerConfigScreen extends StatefulWidget {
  const ServerConfigScreen({super.key});

  @override
  State<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen> {
  final _ipController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _ipController.text = authService.serverManager.serverIP;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Configuration'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Server Configuration',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Configure the IP address where the Admin server will run. Students will connect to this IP address.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            
            Consumer<AuthService>(
              builder: (context, authService, child) {
                return Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Server IP Address',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _ipController,
                          decoration: const InputDecoration(
                            labelText: 'IP Address',
                            hintText: '192.168.1.100',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.computer),
                          ),
                          validator: (value) {
                            if (value?.isEmpty == true) {
                              return 'IP address is required';
                            }
                            // Basic IP validation
                            final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
                            if (!ipRegex.hasMatch(value!)) {
                              return 'Please enter a valid IP address';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Icon(
                              authService.serverManager.isServerRunning 
                                  ? Icons.check_circle 
                                  : Icons.cancel,
                              color: authService.serverManager.isServerRunning 
                                  ? Colors.green 
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Server Status: ${authService.serverManager.isServerRunning ? 'Running' : 'Stopped'}',
                              style: TextStyle(
                                color: authService.serverManager.isServerRunning 
                                    ? Colors.green 
                                    : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _saveConfiguration,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text(
                                        'Save Configuration',
                                        style: TextStyle(color: Colors.white),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _testConnection,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              ),
                              child: const Text(
                                'Test',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      '• The server runs on port 3000\n'
                      '• Make sure the IP address is accessible from student machines\n'
                      '• Students will connect to: http://[IP]:3000\n'
                      '• The server starts automatically when Admin logs in',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveConfiguration() async {
    if (_ipController.text.isEmpty) {
      _showSnackBar('Please enter an IP address', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.serverManager.setServerIP(_ipController.text);
      
      _showSnackBar('Configuration saved successfully', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to save configuration: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testConnection() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // Temporarily set the IP for testing
    final originalIP = authService.serverManager.serverIP;
    await authService.serverManager.setServerIP(_ipController.text);
    
    final isOnline = await authService.serverManager.checkServerStatus();
    
    if (isOnline) {
      _showSnackBar('Connection successful!', Colors.green);
    } else {
      _showSnackBar('Connection failed. Check IP address and server status.', Colors.red);
      // Restore original IP if test failed
      await authService.serverManager.setServerIP(originalIP);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }
}
