// Importing Flutter material package for theme-related classes
import 'package:flutter/material.dart';
// Importing Google Fonts package for custom typography
import 'package:google_fonts/google_fonts.dart';

// AppTheme class contains all theme configurations for the application
class AppTheme {
  // Static final variable for light theme - cannot be changed after compilation
  static final lightTheme = ThemeData(
    primarySwatch: Colors.blue, // Primary color swatch for material components
    brightness: Brightness.light, // Overall brightness of the theme
    scaffoldBackgroundColor: const Color(0xFFF8FAFD), // Background color for scaffolds
    appBarTheme: AppBarTheme( // Custom styling for app bars
      backgroundColor: Colors.transparent, // Transparent background for modern look
      elevation: 0, // Remove shadow for flat design
      titleTextStyle: GoogleFonts.poppins( // Custom font for app bar titles
        color: const Color(0xFF1A1D21), // Dark gray color for text
        fontSize: 24, // Large font size for prominence
        fontWeight: FontWeight.w600, // Semi-bold for better readability
      ),
    ),
    textTheme: TextTheme( // Define text styles for different text types
      displayLarge: GoogleFonts.poppins( // Style for large display text
        color: const Color(0xFF1A1D21), // Dark text color
        fontSize: 32, // Large font size for headings
        fontWeight: FontWeight.w700, // Bold weight for emphasis
      ),
      displayMedium: GoogleFonts.poppins( // Style for medium display text
        color: const Color(0xFF1A1D21),
        fontSize: 24, // Medium font size for subheadings
        fontWeight: FontWeight.w600, // Semi-bold weight
      ),
      bodyLarge: GoogleFonts.inter( // Style for large body text
        color: const Color(0xFF2D3748), // Slightly lighter text color
        fontSize: 16, // Standard body text size
        fontWeight: FontWeight.w400, // Regular weight for readability
      ),
      bodyMedium: GoogleFonts.inter( // Style for medium body text
        color: const Color(0xFF718096), // Light gray for less important text
        fontSize: 14, // Smaller font size
        fontWeight: FontWeight.w400, // Regular weight
      ),
    ),
    inputDecorationTheme: InputDecorationTheme( // Styling for input fields
      filled: true, // Fill background of input fields
      fillColor: Colors.white, // White background for inputs
      border: OutlineInputBorder( // Border styling
        borderRadius: BorderRadius.circular(12), // Rounded corners
        borderSide: BorderSide.none, // No border for modern look
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // Inner padding
    ),
  );

  // Dark theme configuration for dark mode
  static final darkTheme = ThemeData(
    primarySwatch: Colors.blue, // Same primary color for consistency
    brightness: Brightness.dark, // Dark brightness for dark mode
    scaffoldBackgroundColor: const Color(0xFF0F1419), // Dark background color
  );
}