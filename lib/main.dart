import 'package:flutter/material.dart';
import 'package:labassistant/screens/students_screen.dart';
import 'package:labassistant/services/socket_services.dart';
import 'package:provider/provider.dart';
import 'package:desktop_window/desktop_window.dart';
import 'services/auth_service.dart';
import 'services/config_service.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard.dart';

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

        // If not authenticated, show login screen
        if (!authService.isAuthenticated) {
          return const LoginScreen();
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
            return const LoginScreen();
          }
        } else if (authService.user?.role == 'student') {
          print('Routing to StudentDashboard');
          return const StudentDashboard();
        } else {
          // Unknown role, logout for security
          print('Unknown user role: ${authService.user?.role}, logging out');
          authService.logout();
          return const LoginScreen();
        }
      },
    );
  }
}