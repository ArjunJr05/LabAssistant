// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'server_config_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _enrollController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isAdminMode = false;
  
  // Registration fields
  final _nameController = TextEditingController();
  final _yearController = TextEditingController();
  final _sectionController = TextEditingController();
  final _batchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue, Colors.indigo],
          ),
        ),
        child: Center(
          child: Card(
            elevation: 8,
            margin: const EdgeInsets.all(32),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lab Monitoring System',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    
                    // Admin/Student Mode Toggle
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Mode: '),
                          ChoiceChip(
                            label: Text('Student'),
                            selected: !_isAdminMode,
                            onSelected: (selected) {
                              setState(() {
                                _isAdminMode = false;
                                _isLogin = true; // Reset to login when switching modes
                                _clearFields();
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text('Admin'),
                            selected: _isAdminMode,
                            onSelected: (selected) {
                              setState(() {
                                _isAdminMode = true;
                                _isLogin = true; // Admins can only login, not register
                                _clearFields();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Show admin credentials hint and server config
                    if (_isAdminMode)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Admin Credentials:',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text('Username: ADMIN001'),
                                    Text('Password: Admin_aids@smvec'),
                                  ],
                                ),
                                IconButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const ServerConfigScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.settings),
                                  tooltip: 'Server Configuration',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    
                    if (_isAdminMode) const SizedBox(height: 16),
                    
                    // Toggle between login and register (only for students)
                    if (!_isAdminMode)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _isLogin = true),
                            child: Text(
                              'Login',
                              style: TextStyle(
                                color: _isLogin ? Colors.blue : Colors.grey,
                                fontWeight: _isLogin ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          const Text(' | '),
                          TextButton(
                            onPressed: () => setState(() => _isLogin = false),
                            child: Text(
                              'Register',
                              style: TextStyle(
                                color: !_isLogin ? Colors.blue : Colors.grey,
                                fontWeight: !_isLogin ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    
                    const SizedBox(height: 16),
                    
                    if (!_isLogin && !_isAdminMode) ...[
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value?.isEmpty == true ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    TextFormField(
                      controller: _enrollController,
                      decoration: InputDecoration(
                        labelText: _isAdminMode ? 'Admin Username' : 'Enrollment Number',
                        border: const OutlineInputBorder(),
                        hintText: _isAdminMode ? 'ADMIN001' : 'e.g., STU001',
                      ),
                      validator: (value) =>
                          value?.isEmpty == true ? 'This field is required' : null,
                    ),
                    
                    if (!_isLogin && !_isAdminMode) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _yearController,
                              decoration: const InputDecoration(
                                labelText: 'Year (I-IV)',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value?.isEmpty == true ? 'Year is required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _sectionController,
                              decoration: const InputDecoration(
                                labelText: 'Section (A-D)',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value?.isEmpty == true ? 'Section is required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _batchController,
                        decoration: const InputDecoration(
                          labelText: 'Batch (2025-2029)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value?.isEmpty == true ? 'Batch is required' : null,
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        hintText: _isAdminMode ? 'Admin_aids@smvec' : null,
                      ),
                      obscureText: true,
                      validator: (value) =>
                          value?.isEmpty == true ? 'Password is required' : null,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Consumer<AuthService>(
                      builder: (context, authService, child) {
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: authService.isLoading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isAdminMode ? Colors.red : Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: authService.isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    _isAdminMode 
                                        ? 'Admin Login' 
                                        : (_isLogin ? 'Student Login' : 'Register'),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _clearFields() {
    _enrollController.clear();
    _passwordController.clear();
    _nameController.clear();
    _yearController.clear();
    _sectionController.clear();
    _batchController.clear();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    bool success;

    if (_isLogin || _isAdminMode) {
      success = await authService.login(
        _enrollController.text,
        _passwordController.text,
      );
    } else {
      success = await authService.register(
        name: _nameController.text,
        enrollNumber: _enrollController.text,
        year: _yearController.text,
        section: _sectionController.text,
        batch: _batchController.text,
        password: _passwordController.text,
      );
    }

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isAdminMode 
                ? 'Admin login failed' 
                : (_isLogin ? 'Login failed' : 'Registration failed')
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _enrollController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _yearController.dispose();
    _sectionController.dispose();
    _batchController.dispose();
    super.dispose();
  }
}