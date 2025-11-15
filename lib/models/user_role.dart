// Import Flutter material for colors and icons
import 'package:flutter/material.dart';

// UserRole class defines the structure for different user roles in the app
class UserRole {
  final String id; // Unique identifier for the role (e.g., 'student', 'staff')
  final String title; // Display name of the role (e.g., 'Student', 'Staff')
  final String description; // Brief description of what the role can do
  final IconData icon; // Icon that represents the role visually
  final Color color; // Primary color for this role's theme
  final Color gradientStart; // Start color for gradient backgrounds
  final Color gradientEnd; // End color for gradient backgrounds

  // Constant constructor - all fields are final and required
  const UserRole({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.gradientStart,
    required this.gradientEnd,
  });

  // Static getter that returns a list of all available user roles
  // Using getter instead of static final List for better encapsulation
  static List<UserRole> get roles => [
        // Staff role definition
        UserRole(
          id: 'staff',
          title: 'Staff',
          description: 'Manage classes and track student progress',
          icon: Icons.people, // People icon for staff
          color: Color(0xFF059669), // Emerald green
          gradientStart: Color(0xFF10B981), // Lighter green
          gradientEnd: Color(0xFF34D399), // Bright green
        ),
        // Admin role definition
        UserRole(
          id: 'admin',
          title: 'Admin',
          description: 'System administration and management',
          icon: Icons.admin_panel_settings, // Admin shield icon
          color: Color(0xFFDC2626), // Red color
          gradientStart: Color(0xFFEF4444), // Lighter red
          gradientEnd: Color(0xFFF87171), // Pinkish red
        ),
        // Parent role definition
        UserRole(
          id: 'parent',
          title: 'Parent',
          description: 'View your child\'s academic information',
          icon: Icons.family_restroom, // Family icon
          color: Color(0xFF7C3AED), // Purple color
          gradientStart: Color(0xFFA78BFA), // Lighter purple
          gradientEnd: Color(0xFFDDD6FE), // Light lavender
        ),
      ];
}
