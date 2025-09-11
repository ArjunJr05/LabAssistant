// lib/screens/role_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:labassistant/screens/admin_dashboard.dart';
import 'package:labassistant/screens/students_screen.dart';
import 'package:labassistant/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/college.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.5),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    margin: const EdgeInsets.all(24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // App Logo/Icon
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.blue[600]!, Colors.indigo[600]!],
                                  ),
                                  borderRadius: BorderRadius.circular(25),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.4),
                                      blurRadius: 25,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.school,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 30),
                              
                              // Title
                              Text(
                                'Lab Monitoring System',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      offset: const Offset(2, 2),
                                      blurRadius: 4,
                                      color: Colors.black.withOpacity(0.5),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'SMVEC College Portal',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  shadows: [
                                    Shadow(
                                      offset: const Offset(1, 1),
                                      blurRadius: 3,
                                      color: Colors.black.withOpacity(0.5),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 50),
                              
                              // Role Selection Title
                              Text(
                                'Select Your Role',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      offset: const Offset(1, 1),
                                      blurRadius: 3,
                                      color: Colors.black.withOpacity(0.5),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 30),
                              
                              // Student Button
                              _buildRoleButton(
                                title: 'Student',
                                subtitle: 'Access student portal',
                                icon: Icons.person,
                                gradient: [Colors.blue[400]!, Colors.blue[600]!],
                                onTap: () => _navigateToLogin(false),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Admin Button
                              _buildRoleButton(
                                title: 'Admin',
                                subtitle: 'Administrative access',
                                icon: Icons.admin_panel_settings,
                                gradient: [Colors.red[400]!, Colors.red[600]!],
                                onTap: () => _navigateToLogin(true),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient[1].withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToLogin(bool isAdmin) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => LoginScreen(isAdminMode: isAdmin),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.ease;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: tween.animate(animation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

class LoginScreen extends StatefulWidget {
  final bool isAdminMode;
  
  const LoginScreen({super.key, required this.isAdminMode});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _enrollController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Registration fields
  final _nameController = TextEditingController();
  final _yearController = TextEditingController();
  final _sectionController = TextEditingController();
  final _batchController = TextEditingController();

  // Admin registration fields
  final _adminNameController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _masterPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/college.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.2),
                Colors.black.withOpacity(0.4),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Back button and header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          // Explicitly navigate back to RoleSelectionScreen
                          Navigator.pushReplacement(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) => 
                                  const RoleSelectionScreen(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                const begin = Offset(-1.0, 0.0);
                                const end = Offset.zero;
                                const curve = Curves.ease;

                                var tween = Tween(begin: begin, end: end).chain(
                                  CurveTween(curve: curve),
                                );

                                return SlideTransition(
                                  position: tween.animate(animation),
                                  child: child,
                                );
                              },
                              transitionDuration: const Duration(milliseconds: 300),
                            ),
                          );
                        },
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                
                // Main content
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  color: Colors.white.withOpacity(0.1),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                padding: const EdgeInsets.all(40),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Role indicator icon
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: widget.isAdminMode 
                                                ? [Colors.red[600]!, Colors.red[800]!]
                                                : [Colors.blue[600]!, Colors.indigo[600]!],
                                          ),
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (widget.isAdminMode ? Colors.red : Colors.blue).withOpacity(0.3),
                                              blurRadius: 20,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          widget.isAdminMode ? Icons.admin_panel_settings : Icons.person,
                                          size: 40,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      
                                      // Title
                                      Text(
                                        widget.isAdminMode ? 'Admin Access' : 'Student Login',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              offset: const Offset(1, 1),
                                              blurRadius: 3,
                                              color: Colors.black.withOpacity(0.5),
                                            ),
                                          ],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 32),
                                      
                                      // Login/Register toggle
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        margin: const EdgeInsets.only(bottom: 24),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () => setState(() => _isLogin = true),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                                  decoration: BoxDecoration(
                                                    color: _isLogin ? (widget.isAdminMode ? Colors.red : Colors.blue) : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    'Login',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: _isLogin ? Colors.white : Colors.white70,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () => setState(() => _isLogin = false),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                                  decoration: BoxDecoration(
                                                    color: !_isLogin ? (widget.isAdminMode ? Colors.red : Colors.blue) : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    widget.isAdminMode ? 'Register Admin' : 'Register',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: !_isLogin ? Colors.white : Colors.white70,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Form fields
                                      if (!_isLogin && !widget.isAdminMode) ...[
                                        _buildTextField(
                                          controller: _nameController,
                                          label: 'Full Name',
                                          icon: Icons.person,
                                          validator: (value) => value?.isEmpty == true ? 'Name is required' : null,
                                        ),
                                        const SizedBox(height: 20),
                                      ],
                                      
                                      if (!_isLogin && widget.isAdminMode) ...[
                                        _buildTextField(
                                          controller: _adminNameController,
                                          label: 'Admin Name',
                                          icon: Icons.person,
                                          validator: (value) => value?.isEmpty == true ? 'Admin name is required' : null,
                                        ),
                                        const SizedBox(height: 20),
                                        _buildTextField(
                                          controller: _enrollController,
                                          label: 'Admin Username',
                                          icon: Icons.admin_panel_settings,
                                          hint: 'e.g., ADMIN002',
                                          validator: (value) => value?.isEmpty == true ? 'Admin username is required' : null,
                                        ),
                                        const SizedBox(height: 20),
                                        _buildTextField(
                                          controller: _adminPasswordController,
                                          label: 'Admin Password',
                                          icon: Icons.lock,
                                          obscureText: true,
                                          validator: (value) => value?.isEmpty == true ? 'Admin password is required' : null,
                                        ),
                                        const SizedBox(height: 20),
                                        _buildTextField(
                                          controller: _masterPasswordController,
                                          label: 'Master Password',
                                          icon: Icons.security,
                                          hint: 'Admin_aids@smvec',
                                          obscureText: true,
                                          validator: (value) {
                                            if (value?.isEmpty == true) return 'Master password is required';
                                            if (value != 'Admin_aids@smvec') return 'Invalid master password';
                                            return null;
                                          },
                                        ),
                                      ] else ...[
                                        _buildTextField(
                                          controller: _enrollController,
                                          label: widget.isAdminMode ? 'Admin Username' : 'Enrollment Number',
                                          icon: widget.isAdminMode ? Icons.admin_panel_settings : Icons.badge,
                                          hint: widget.isAdminMode ? 'ADMIN001' : 'e.g., STU001',
                                          validator: (value) => value?.isEmpty == true ? 'This field is required' : null,
                                        ),
                                      ],
                                      
                                      if (!_isLogin && !widget.isAdminMode) ...[
                                        const SizedBox(height: 20),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildTextField(
                                                controller: _yearController,
                                                label: 'Year',
                                                icon: Icons.calendar_today,
                                                hint: 'I-IV',
                                                validator: (value) => value?.isEmpty == true ? 'Year is required' : null,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: _buildTextField(
                                                controller: _sectionController,
                                                label: 'Section',
                                                icon: Icons.group,
                                                hint: 'A-D',
                                                validator: (value) => value?.isEmpty == true ? 'Section is required' : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        _buildTextField(
                                          controller: _batchController,
                                          label: 'Batch',
                                          icon: Icons.school,
                                          hint: '2025-2029',
                                          validator: (value) => value?.isEmpty == true ? 'Batch is required' : null,
                                        ),
                                      ],
                                      
                                      if (_isLogin || !widget.isAdminMode)
                                        _buildTextField(
                                          controller: _passwordController,
                                          label: 'Password',
                                          icon: Icons.lock,
                                          hint: widget.isAdminMode ? 'Admin_aids@smvec' : null,
                                          obscureText: true,
                                          validator: (value) => value?.isEmpty == true ? 'Password is required' : null,
                                        ),
                                      
                                      const SizedBox(height: 32),
                                      
                                      // Submit button
                                      Consumer<AuthService>(
                                        builder: (context, authService, child) {
                                          return Container(
                                            width: double.infinity,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: widget.isAdminMode 
                                                    ? [Colors.red[400]!, Colors.red[600]!]
                                                    : [Colors.blue[400]!, Colors.indigo[600]!],
                                              ),
                                              borderRadius: BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: (widget.isAdminMode ? Colors.red : Colors.blue).withOpacity(0.3),
                                                  blurRadius: 20,
                                                  spreadRadius: 2,
                                                  offset: const Offset(0, 8),
                                                ),
                                              ],
                                            ),
                                            child: ElevatedButton(
                                              onPressed: authService.isLoading ? null : _handleSubmit,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                              ),
                                              child: authService.isLoading
                                                  ? const SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child: CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                    )
                                                  : Text(
                                                      widget.isAdminMode 
                                                          ? (_isLogin ? 'Admin Login' : 'Register Admin')
                                                          : (_isLogin ? 'Student Login' : 'Register'),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                      ),
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
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(fontSize: 16, color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.isAdminMode 
                  ? [Colors.red[400]!, Colors.red[600]!]
                  : [Colors.blue[400]!, Colors.indigo[600]!],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: widget.isAdminMode ? Colors.red[400]! : Colors.blue[400]!, 
            width: 2
          ),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    bool success;

    if (_isLogin) {
      success = await authService.login(
        _enrollController.text.trim(),
        _passwordController.text,
      );
    } else if (widget.isAdminMode) {
      success = await authService.registerAdmin(
        name: _adminNameController.text.trim(),
        username: _enrollController.text.trim(),
        password: _adminPasswordController.text,
        masterPassword: _masterPasswordController.text,
      );
    } else {
      success = await authService.register(
        name: _nameController.text.trim(),
        enrollNumber: _enrollController.text.trim(),
        year: _yearController.text.trim(),
        section: _sectionController.text.trim().toUpperCase(),
        batch: _batchController.text.trim(),
        password: _passwordController.text,
      );
    }

    if (!success && mounted) {
      String errorMessage;
      if (widget.isAdminMode && !_isLogin) {
        errorMessage = 'Admin registration failed. Check master password and try again.';
      } else if (widget.isAdminMode) {
        errorMessage = 'Admin login failed. Check credentials and server status.';
      } else if (_isLogin) {
        errorMessage = 'Student login failed. Make sure admin is logged in first.';
      } else {
        errorMessage = 'Registration failed. Check your details and try again.';
      }
      _showError(errorMessage);
    } else if (success && mounted) {
      // Handle successful authentication
      if (widget.isAdminMode) {
        _showSuccess('Admin login successful!');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminDashboard()),
            );
          }
        });
      } else {
        _showSuccess(_isLogin ? 'Student login successful!' : 'Registration successful!');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const StudentDashboard()),
            );
          }
        });
      }
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _enrollController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _yearController.dispose();
    _sectionController.dispose();
    _batchController.dispose();
    _adminNameController.dispose();
    _adminPasswordController.dispose();
    _masterPasswordController.dispose();
    super.dispose();
  }
}