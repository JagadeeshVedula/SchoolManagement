// Importing Flutter material package
import 'package:flutter/material.dart';
// Importing custom role card widget
import 'package:school_management/widgets/role_card.dart';
// Importing user role model
import 'package:school_management/models/user_role.dart';
// Importing login screen for navigation
import 'package:school_management/screens/login_screen.dart';
// Importing Google Fonts for custom typography
import 'package:google_fonts/google_fonts.dart';

// RoleSelectionScreen displays the main screen with role selection cards
class RoleSelectionScreen extends StatefulWidget {
  // Constructor with const for better performance
  const RoleSelectionScreen({super.key});

  // Create state for this stateful widget
  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

// State class for RoleSelectionScreen that handles animations and interactions
class _RoleSelectionScreenState extends State<RoleSelectionScreen> 
    with SingleTickerProviderStateMixin { // Mixin for animation support
  late AnimationController _controller; // Controls animation timeline and state
  late Animation<double> _fadeAnimation; // Animation for fade effects
  late Animation<double> _slideAnimation; // Animation for slide effects

  // Initialize state when widget is created
  @override
  void initState() {
    super.initState(); // Call parent initState
    // Initialize animation controller with 1 second duration
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this, // Use this class as the ticker provider
    );

    // Fade animation: goes from invisible (0.0) to fully visible (1.0)
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller, // Link to main controller
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn), // Animate first half
      ),
    );

    // Slide animation: starts 50px below and moves to normal position
    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut), // Animate later with ease-out
      ),
    );

    // Start the animation when screen loads
    _controller.forward();
  }

  // Clean up resources when widget is disposed
  @override
  void dispose() {
    _controller.dispose(); // Dispose animation controller to prevent memory leaks
    super.dispose(); // Call parent dispose
  }

  // Build method that creates the UI for this screen
  @override
  Widget build(BuildContext context) {
    return Scaffold( // Basic material design scaffold
      body: Container( // Container for background gradient
        decoration: const BoxDecoration( // Background decoration
          gradient: LinearGradient( // Gradient from blue to purple
            begin: Alignment.topLeft, // Gradient starts at top-left
            end: Alignment.bottomRight, // Gradient ends at bottom-right
            colors: [
              Color(0xFF667EEA), // Light blue color
              Color(0xFF764BA2), // Purple color
            ],
          ),
        ),
        child: SafeArea( // Ensures content is not covered by device notches
          child: Padding( // Add padding around all content
            padding: const EdgeInsets.all(24.0), // 24 pixels padding on all sides
            child: Column( // Vertical layout for header, cards, and footer
              crossAxisAlignment: CrossAxisAlignment.start, // Align children to left
              children: [
                // Header Section with animations
                AnimatedBuilder( // Rebuilds when animation values change
                  animation: _controller, // Watch the animation controller
                  builder: (context, child) {
                    return Transform.translate( // Apply slide animation
                      offset: Offset(0, _slideAnimation.value), // Move vertically based on animation
                      child: Opacity( // Apply fade animation
                        opacity: _fadeAnimation.value, // Control visibility based on animation
                        child: child, // The actual widget to animate
                      ),
                    );
                  },
                  child: Column( // Header content in vertical layout
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20), // Spacer above header
                      Container( // Container for app icon
                        width: 60, // Fixed width
                        height: 60, // Fixed height
                        decoration: BoxDecoration( // Styling for the container
                          color: Colors.white.withOpacity(0.2), // Semi-transparent white
                          borderRadius: BorderRadius.circular(16), // Rounded corners
                        ),
                        child: const Icon( // App icon
                          Icons.school, // Education icon
                          color: Colors.white, // White color
                          size: 32, // Icon size
                        ),
                      ),
                      const SizedBox(height: 16), // Space between icon and text
                      Text( // "Welcome to" text
                        'Welcome to',
                        style: GoogleFonts.poppins( // Custom font
                          color: Colors.white.withOpacity(0.8), // Semi-transparent white
                          fontSize: 18, // Medium font size
                          fontWeight: FontWeight.w500, // Medium weight
                        ),
                      ),
                      const SizedBox(height: 4), // Small space between text lines
                      Text( // App name text
                        'EduManage',
                        style: GoogleFonts.poppins(
                          color: Colors.white, // Solid white color
                          fontSize: 36, // Large font size for emphasis
                          fontWeight: FontWeight.w700, // Bold weight
                        ),
                      ),
                      const SizedBox(height: 8), // Space between heading and subtitle
                      Text( // Subtitle text
                        'Select your role to continue',
                        style: GoogleFonts.inter( // Different font for subtitle
                          color: Colors.white.withOpacity(0.7), // Semi-transparent white
                          fontSize: 16, // Standard body size
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40), // Space between header and role cards

                // Role Cards Section
                Expanded( // Takes remaining vertical space
                  child: AnimatedBuilder( // Animated builder for cards
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _slideAnimation.value * 2), // Double the slide for dramatic effect
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: GridView.count( // Grid layout for role cards
                      crossAxisCount: _getCrossAxisCount(context), // Responsive column count
                      crossAxisSpacing: 20, // Space between columns
                      mainAxisSpacing: 20, // Space between rows
                      childAspectRatio: 0.8, // Width to height ratio for cards
                      children: [
                        // Generate role cards for each user role
                        for (int i = 0; i < UserRole.roles.length; i++)
                          RoleCard(
                            role: UserRole.roles[i], // Pass role data
                            delay: i * 200, // Stagger animation delays
                            onTap: () {
                              _navigateToLoginScreen(UserRole.roles[i]); // Handle tap
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                // Footer Section
                AnimatedBuilder( // Animated footer
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Center( // Center the footer text
                    child: Text(
                      'School Management System © 2024',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.6), // Subtle white color
                        fontSize: 14, // Small font size
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

  // Helper method to determine grid columns based on screen width
  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width; // Get screen width
    if (width > 600) return 3; // 3 columns on tablets and larger screens
    if (width > 400) return 2; // 2 columns on medium phones
    return 1; // 1 column on small phones
  }

  // Navigate to login screen with custom page transition
  void _navigateToLoginScreen(UserRole role) {
    Navigator.push( // Navigate to new screen
      context,
      PageRouteBuilder( // Custom page route for transition animation
        pageBuilder: (context, animation, secondaryAnimation) =>
            LoginScreen(userRole: role), // Destination screen
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0); // Start from right side
          const end = Offset.zero; // End at normal position
          const curve = Curves.easeInOut; // Smooth easing curve
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween); // Create the animation

          return SlideTransition( // Apply slide transition
            position: offsetAnimation,
            child: child, // The screen to transition to
          );
        },
        transitionDuration: const Duration(milliseconds: 500), // Transition duration
      ),
    );
  }
}