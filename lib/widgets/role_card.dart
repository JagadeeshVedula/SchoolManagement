// Import Flutter material package
import 'package:flutter/material.dart';
// Import our custom user role model
import 'package:school_management/models/user_role.dart';
// Import Google Fonts for custom typography
import 'package:google_fonts/google_fonts.dart';

// RoleCard widget displays an interactive card for each user role
class RoleCard extends StatefulWidget {
  final UserRole role; // The role data to display
  final int delay; // Animation delay in milliseconds for staggered animation
  final VoidCallback onTap; // Callback function when card is tapped

  // Constructor with required parameters
  const RoleCard({
    super.key,
    required this.role,
    required this.delay,
    required this.onTap,
  });

  // Create state for this stateful widget
  @override
  State<RoleCard> createState() => _RoleCardState();
}

// State class for RoleCard that handles hover effects and animations
class _RoleCardState extends State<RoleCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller; // Controls card entrance animation
  late Animation<double> _scaleAnimation; // Scale animation for card pop-in effect
  late Animation<double> _fadeAnimation; // Fade animation for smooth appearance

  bool _isHovered = false; // Track whether mouse is hovering over card

  // Initialize state when widget is created
  @override
  void initState() {
    super.initState();
    // Initialize animation controller with duration based on delay
    _controller = AnimationController(
      duration: Duration(milliseconds: 600 + widget.delay), // Longer duration with delay
      vsync: this, // Use this class as ticker provider
    );

    // Scale animation: card starts scaled down and grows to normal size
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut, // Bouncy elastic curve for fun effect
      ),
    );

    // Fade animation: card starts invisible and fades in
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn), // Delay fade slightly
      ),
    );

    // Start animation after a delay for staggered entrance effect
    Future.delayed(Duration(milliseconds: widget.delay), () {
      _controller.forward(); // Start the animation
    });
  }

  // Clean up animation controller when widget is disposed
  @override
  void dispose() {
    _controller.dispose(); // Prevent memory leaks
    super.dispose();
  }

  // Build the role card widget
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder( // Rebuild when animation values change
      animation: _controller,
      builder: (context, child) {
        return Transform.scale( // Apply scale transformation
          scale: _scaleAnimation.value, // Animated scale value
          child: Opacity( // Apply fade effect
            opacity: _fadeAnimation.value, // Animated opacity value
            child: child, // The actual card widget
          ),
        );
      },
      child: MouseRegion( // Detect mouse hover for web/desktop
        onEnter: (_) => setState(() => _isHovered = true), // Set hover state to true
        onExit: (_) => setState(() => _isHovered = false), // Set hover state to false
        child: GestureDetector( // Detect taps for mobile devices
          onTap: widget.onTap, // Call the provided onTap callback
          child: AnimatedContainer( // Container with animated properties
            duration: const Duration(milliseconds: 300), // Animation duration
            curve: Curves.easeInOut, // Smooth easing curve
            transform: Matrix4.identity() // Apply transform matrix
              ..translate( // Move card up when hovered
                0.0,
                _isHovered ? -8.0 : 0.0, // Lift effect on hover
              ),
            decoration: BoxDecoration( // Card styling
              gradient: LinearGradient( // Gradient background using role colors
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.role.gradientStart,
                  widget.role.gradientEnd,
                ],
              ),
              borderRadius: BorderRadius.circular(20), // Rounded corners
              boxShadow: [ // Shadow effects
                if (_isHovered) // Only show enhanced shadow when hovered
                  BoxShadow(
                    color: widget.role.color.withOpacity(0.4), // Color-based shadow
                    blurRadius: 20, // Soft blur
                    offset: const Offset(0, 10), // Shadow position
                  ),
                BoxShadow( // Base shadow always present
                  color: widget.role.color.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack( // Stack for layered content
              children: [
                // Background Pattern - large faded icon in background
                Positioned(
                  right: -20, // Position outside right edge
                  bottom: -20, // Position outside bottom edge
                  child: Icon(
                    widget.role.icon, // Same icon as foreground but larger
                    size: 120, // Large size for background
                    color: Colors.white.withOpacity(0.1), // Very transparent white
                  ),
                ),

                // Main Content
                Padding(
                  padding: const EdgeInsets.all(24.0), // Inner padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // Left-align content
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space out items
                    children: [
                      // Role Icon Container
                      Container(
                        width: 60, // Fixed width
                        height: 60, // Fixed height
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2), // Semi-transparent white
                          borderRadius: BorderRadius.circular(16), // Rounded corners
                        ),
                        child: Icon( // Role icon
                          widget.role.icon,
                          color: Colors.white, // White icon
                          size: 32, // Icon size
                        ),
                      ),

                      // Text Content Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text( // Role title
                            widget.role.title,
                            style: GoogleFonts.poppins( // Custom font
                              color: Colors.white, // White text
                              fontSize: 22, // Large font size
                              fontWeight: FontWeight.w600, // Semi-bold
                            ),
                          ),
                          const SizedBox(height: 8), // Space between title and description
                          Text( // Role description
                            widget.role.description,
                            style: GoogleFonts.inter( // Different font for description
                              color: Colors.white.withOpacity(0.8), // Semi-transparent white
                              fontSize: 14, // Smaller font size
                            ),
                          ),
                        ],
                      ),

                      // Animated Arrow Icon
                      Align( // Align to right side
                        alignment: Alignment.centerRight,
                        child: AnimatedContainer( // Container with animated properties
                          duration: const Duration(milliseconds: 300), // Animation duration
                          width: _isHovered ? 44 : 40, // Grow on hover
                          height: _isHovered ? 44 : 40, // Grow on hover
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(_isHovered ? 0.3 : 0.2), // More opaque on hover
                            borderRadius: BorderRadius.circular(12), // Rounded corners
                          ),
                          child: Icon( // Forward arrow icon
                            Icons.arrow_forward_rounded,
                            color: Colors.white, // White icon
                            size: _isHovered ? 24 : 20, // Grow icon on hover
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}