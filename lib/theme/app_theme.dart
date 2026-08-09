import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Web App Exact Core Backgrounds
  static const Color background = Color(0xFF090C11);
  static const Color elevatedBackground = Color(0xFF0E131A);
  static const Color cardBackground = Color(0x0CFFFFFF); // rgba(255, 255, 255, 0.045)
  static const Color cardBorder = Color(0x17FFFFFF);     // rgba(255, 255, 255, 0.09)
  
  // Web App Exact Accent Color Palette
  static const Color emerald = Color(0xFF34D399);   // Primary Accent
  static const Color sky = Color(0xFF38BDF8);       // Sky Blue
  static const Color violet = Color(0xFFA78BFA);    // Violet
  static const Color amber = Color(0xFFFBBF24);     // Amber
  static const Color rose = Color(0xFFFB7185);      // Rose
  static const Color dangerRed = Color(0xFFF87171);  // Danger
  static const Color orange = Color(0xFFFB923C);    // Orange
  static const Color pink = Color(0xFFF472B6);      // Pink
  static const Color slate = Color(0xFF94A3B8);     // Slate

  // Color Aliases for 100% Backward Compatibility
  static const Color primaryEmerald = emerald;
  static const Color primaryCyan = emerald; // Maps cyan calls to Web Emerald!
  static const Color primaryPurple = violet;
  static const Color accentNeon = emerald;
  static const Color successGreen = emerald;
  static const Color accentCyan = emerald;
  static const Color accentRed = dangerRed;
  static const Color accentGreen = emerald;

  // Typography High-Contrast Colors
  static const Color textPrimary = Color(0xFFF8FAFC);  // --text-hi
  static const Color textSecondary = Color(0xFFCBD5E1); // --text-mid
  static const Color textMuted = Color(0xFF94A3B8);     // --text-low

  // Web App Exact Linear Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient skyGradient = LinearGradient(
    colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient violetGradient = LinearGradient(
    colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(0x13FFFFFF), // rgba(255, 255, 255, 0.075)
      Color(0x0CFFFFFF), // rgba(255, 255, 255, 0.045)
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Theme Data Setup (Web Match)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: emerald,
      colorScheme: const ColorScheme.dark(
        primary: emerald,
        secondary: sky,
        surface: elevatedBackground,
        error: dangerRed,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0.2,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textSecondary,
        ),
        labelLarge: GoogleFonts.ibmPlexMono(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: emerald,
        ),
      ),
    );
  }
}
