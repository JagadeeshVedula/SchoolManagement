// Importing Flutter material package for theme-related classes
import 'package:flutter/material.dart';
// Importing Google Fonts package for custom typography
import 'package:google_fonts/google_fonts.dart';

// AppTheme class contains all theme configurations for the application
class AppTheme {
  // Static final variable for light theme - cannot be changed after compilation
  static final lightTheme = ThemeData(
    useMaterial3: true,
    primaryColor: const Color(0xFF800000), // Maroon
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF800000),
      primary: const Color(0xFF800000),
      secondary: const Color(0xFFF59E0B),
      surface: Colors.white,
      background: const Color(0xFFF8FAFC),
    ),
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      titleTextStyle: GoogleFonts.poppins(
        color: const Color(0xFF1E293B),
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF800000),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.poppins(
        color: const Color(0xFF0F172A),
        fontSize: 32,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: GoogleFonts.poppins(
        color: const Color(0xFF0F172A),
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.inter(
        color: const Color(0xFF334155),
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.inter(
        color: const Color(0xFF64748B),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF800000), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: const Color(0xFFB91C1C), // Lighter Maroon for Dark Mode
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF800000),
      brightness: Brightness.dark,
      primary: const Color(0xFFB91C1C),
      secondary: const Color(0xFFFBBF24),
    ),
    scaffoldBackgroundColor: const Color(0xFF0F172A),
  );
}