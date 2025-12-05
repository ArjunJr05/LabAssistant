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

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _hasCleared = false;

  @override
  void initState() {
    super.initState();
    // Clear stored credentials on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasCleared) {
        final authService = Provider.of<AuthService>(context, listen: false);
        authService.logout();
        _hasCleared = true;
        print(' App started - Cleared stored credentials');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // Always show Role Selection screen on app start
        return const RoleSelectionScreen();
      },
    );
  }
}