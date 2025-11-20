// Importing Flutter material package for basic Flutter widgets and functionality
import 'package:flutter/material.dart';
// Importing our custom role selection screen
import 'package:school_management/screens/role_selection_screen.dart';
import 'package:school_management/screens/home_tabs_screen.dart';
// Importing custom app theme configuration
import 'package:school_management/theme/app_theme.dart';
// Importing Supabase service for database initialization
import 'package:school_management/services/supabase_service.dart';

// Main function - entry point of the Flutter application
void main() async {
  // Initialize Supabase before running the app
  await SupabaseService.initialize();
  // runApp function initializes the Flutter framework and runs the app
  runApp(const SchoolManagementApp());
}

// Root widget of the application that sets up the material app
class SchoolManagementApp extends StatelessWidget {
  // Constructor with const keyword for better performance
  const SchoolManagementApp({super.key});

  // Build method required for all StatelessWidget, defines the UI
  @override
  Widget build(BuildContext context) {
    // MaterialApp is the root widget that provides material design components
    return MaterialApp(
      title: 'EduManage', // App name shown in device app switcher
      theme: AppTheme.lightTheme, // Custom light theme for the app
      darkTheme: AppTheme.darkTheme, // Custom dark theme for the app
      themeMode: ThemeMode.light, // Default to light theme
      debugShowCheckedModeBanner: false, // Remove debug banner in corner
      home: const RoleSelectionScreen(), // First screen shown when app launches
      // Handle /home route so we can pass role/username via arguments
      onGenerateRoute: (settings) {
        if (settings.name == '/home') {
          final args = settings.arguments as Map<String, dynamic>?;
          final role = args != null && args['role'] is String ? args['role'] as String : 'student';
          final username = args != null && args['username'] is String ? args['username'] as String : '';
          final parentMobile = args != null && args['parentMobile'] is String ? args['parentMobile'] as String : null;
          return MaterialPageRoute(
            builder: (_) => HomeTabsScreen(role: role, username: username, parentMobile: parentMobile),
            settings: settings,
          );
        }
        if (settings.name == '/') {
          return MaterialPageRoute(
            builder: (_) => const RoleSelectionScreen(),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}