import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Color Palette
  static const Color background = Color(0FF050811);
  static const Color cardBackground = Color(0x1Affffff); // 10% white for glass
  static const Color cardBorder = Color(0x33ffffff); // 20% white border
  
  static const Color primaryCyan = Color(0FF00F2FE);
  static const Color primaryPurple = Color(0FF4FACFE);
  static const Color accentNeon = Color(0FF00FFCC);
  static const Color dangerRed = Color(0FFFF4B4B);
  static const Color successGreen = Color(0FF00E676);
  static const Color warningOrange = Color(0FFFF9100);
  
  static const Color textPrimary = Color(0FFFFFFFF);
  static const Color textSecondary = Color(0x99FFFFFF); // 60% opacity white
  static const Color textMuted = Color(0x66FFFFFF); // 40% opacity white

  // Gradient Backgrounds
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryCyan, primaryPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(0x1CFFFFFF),
      Color(0x0AFFFFFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Theme Data Setup
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryCyan,
      colorScheme: const ColorScheme.dark(
        primary: primaryCyan,
        secondary: primaryPurple,
        surface: background,
        error: dangerRed,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelLarge: GoogleFonts.ibmPlexMono(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: primaryCyan,
        ),
      ),
    );
  }
}
