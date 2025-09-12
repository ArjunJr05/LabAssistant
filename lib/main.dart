import 'package:flutter/material.dart';
import 'package:labassistant/services/socket_services.dart';
import 'package:provider/provider.dart';
import 'package:desktop_window/desktop_window.dart';
import 'services/auth_service.dart';
import 'services/config_service.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/students_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Force reset network configuration on app start
  await ConfigService.resetToDefault();
  print(' Network configuration reset to default IP');
  
  // Set window properties for desktop
  await DesktopWindow.setMinWindowSize(const Size(1200, 800));
  await DesktopWindow.setWindowSize(const Size(1400, 900));
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SocketService()),
      ],
      child: MaterialApp(
        title: 'Lab Monitoring System',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const AuthWrapper(),
        routes: {
          '/role-selection': (context) => const RoleSelectionScreen(),
          '/admin-dashboard': (context) => const AdminDashboard(),
          '/student-dashboard': (context) => const StudentDashboard(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // Show loading screen while checking authentication
        if (authService.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            ),
          );
        }

        // If not authenticated, show role selection screen
        if (!authService.isAuthenticated) {
          return const RoleSelectionScreen();
        }

        // Debug: Print user info
        print('AuthWrapper - User: ${authService.user?.name}');
        print('AuthWrapper - Role: ${authService.user?.role}');
        print('AuthWrapper - Enroll Number: ${authService.user?.enrollNumber}');

        // Route based on user role
        if (authService.user?.role == 'admin') {
          // Double-check admin credentials
          if (authService.user?.enrollNumber == 'ADMIN001') {
            print('Routing to AdminDashboard');
            return const AdminDashboard();
          } else {
            // Invalid admin user, logout
            print('Invalid admin user detected, logging out');
            authService.logout();
            return const RoleSelectionScreen();
          }
        } else if (authService.user?.role == 'student') {
          print('Routing to StudentDashboard');
          return const StudentDashboard();
        } else {
          // Unknown role, logout for security
          print('Unknown user role: ${authService.user?.role}, logging out');
          authService.logout();
          return const RoleSelectionScreen();
        }
      },
    );
  }
}

// Role Selection Screen
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Role'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Lab Assistant',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(isAdminMode: false),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              ),
              child: const Text(
                'Student Login',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(isAdminMode: true),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              ),
              child: const Text(
                'Admin Login',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
