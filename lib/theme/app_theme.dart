import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Monex Primary Signature Royal Blue Palette
  static const Color monexBlue = Color(0xFF2B59FF);
  static const Color monexBlueHover = Color(0xFF1E4CE6);
  static const Color monexBlueDark = Color(0xFF1738B3);
  static const Color monexBlueLight = Color(0xFFEEF2FF);
  static const Color monexBlueSubtle = Color(0xFFF0F4FF);
  static const Color monexNavy = Color(0xFF0F172A);

  // Background & Surface Canvas
  static const Color background = Color(0xFFF8F9FE);
  static const Color backgroundElevated = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF101828);
  static const Color cardDark = Color(0xFF161F30);

  // Borders & Dividers
  static const Color borderLight = Color(0xFFE9ECF2);
  static const Color borderSubtle = Color(0xFFF1F3F9);
  static const Color cardBorder = Color(0xFFEAECF0);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Typography Colors
  static const Color textPrimary = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF667085);
  static const Color textMuted = Color(0xFF98A2B3);
  static const Color textLight = Color(0xFFFFFFFF);

  // Transaction & Status Accents
  static const Color successGreen = Color(0xFF12B76A);
  static const Color dangerRed = Color(0xFFF04438);
  static const Color warningOrange = Color(0xFFFB6514);
  static const Color warningAmber = Color(0xFFF79009);
  static const Color purple = Color(0xFF7A5AF8);
  static const Color sky = Color(0xFF0BA5EC);

  // Dynamic Theme Helpers
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
  static Color getBg(BuildContext context) => isDark(context) ? const Color(0xFF090D16) : const Color(0xFFF8F9FE);
  static Color getCardBg(BuildContext context) => isDark(context) ? const Color(0xFF131A29) : Colors.white;
  static Color getCardElevatedBg(BuildContext context) => isDark(context) ? const Color(0xFF1A2234) : const Color(0xFFF8F9FC);
  static Color getTxtPrimary(BuildContext context) => isDark(context) ? const Color(0xFFF8FAFC) : const Color(0xFF101828);
  static Color getTxtSecondary(BuildContext context) => isDark(context) ? const Color(0xFF94A3B8) : const Color(0xFF667085);
  static Color getTxtMuted(BuildContext context) => isDark(context) ? const Color(0xFF64748B) : const Color(0xFF98A2B3);
  static Color getBorder(BuildContext context) => isDark(context) ? const Color(0xFF1E293B) : const Color(0xFFF1F3F9);
  static Color getCardBorder(BuildContext context) => isDark(context) ? const Color(0xFF1E293B) : const Color(0xFFEAECF0);

  // Backward-compatible color aliases for existing modules
  static const Color primaryEmerald = monexBlue;
  static const Color primaryCyan = monexBlue;
  static const Color primaryPurple = purple;
  static const Color accentNeon = monexBlue;
  static const Color mint = monexBlue;
  static const Color mintBright = monexBlueLight;
  static const Color mintDark = monexBlueDark;
  static const Color emerald = successGreen;
  static const Color mintAccent = monexBlue;
  static const Color violet = purple;
  static const Color amber = warningAmber;
  static const Color coral = dangerRed;
  static const Color pink = Color(0xFFEE46BC);
  static const Color rose = Color(0xFFF63D68);
  static const Color orange = warningOrange;
  static const Color slate = textSecondary;
  static const Color accentPurple = purple;
  static const Color accentPink = dangerRed;
  static const Color accentCyan = monexBlue;
  static const Color accentRed = dangerRed;
  static const Color expenseRed = dangerRed;
  static const Color accentGreen = successGreen;

  // Modern Soft Ambient Shadows
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF101828).withValues(alpha: 0.05),
          blurRadius: 16,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFF101828).withValues(alpha: 0.03),
          blurRadius: 6,
          spreadRadius: -1,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get heroBlueShadow => [
        BoxShadow(
          color: monexBlue.withValues(alpha: 0.35),
          blurRadius: 20,
          spreadRadius: -2,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get buttonShadow => [
        BoxShadow(
          color: monexBlue.withValues(alpha: 0.3),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get cardSoftShadow => cardShadow;
  static List<BoxShadow> get mintGlowShadow => heroBlueShadow;

  // Gradients
  static const LinearGradient blueHeroGradient = LinearGradient(
    colors: [Color(0xFF3B66FF), Color(0xFF2550E8), Color(0xFF1A40D0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardWhiteGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFFAFBFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient heroMintGradient = blueHeroGradient;
  static const LinearGradient darkCardGradient = blueHeroGradient;
  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(0x1F2B59FF),
      Color(0x0A2B59FF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Main Monex Theme Data
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: monexBlue,
      colorScheme: const ColorScheme.light(
        primary: monexBlue,
        secondary: monexBlueLight,
        surface: surfaceLight,
        error: dangerRed,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textPrimary, size: 20),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textMuted,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: monexBlue,
        ),
      ),
    );
  }

  // Dark Theme support
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF090D16),
      primaryColor: monexBlue,
      cardColor: const Color(0xFF131A29),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF38BDF8),
        secondary: Color(0xFF1E293B),
        surface: Color(0xFF131A29),
        error: dangerRed,
        onSurface: Color(0xFFF8FAFC),
        onPrimary: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFF8FAFC), size: 20),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFF8FAFC),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFF8FAFC),
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFF8FAFC),
          letterSpacing: -0.2,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFF8FAFC),
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFF8FAFC),
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFF8FAFC),
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF94A3B8),
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF64748B),
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF38BDF8),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF1E293B),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        textColor: const Color(0xFFF8FAFC),
        iconColor: const Color(0xFF94A3B8),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFF8FAFC),
        ),
        subtitleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF94A3B8),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF131A29),
        modalBackgroundColor: Color(0xFF131A29),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF131A29),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: const Color(0xFFF8FAFC),
        ),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}
