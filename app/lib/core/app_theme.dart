import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryNeon = Color(0xFF75FF9E);
  static const Color primaryContainer = Color(0xFF00E676);
  static const Color onPrimary = Color(0xFF003918);
  static const Color onPrimaryContainer = Color(0xFF00210B);

  static const Color surfaceBase = Color(0xFF051612);
  static const Color surfaceContainerLowest = Color(0xFF02110D);
  static const Color surfaceContainerLow = Color(0xFF0D1F1A);
  static const Color surfaceContainer = Color(0xFF11231E);
  static const Color surfaceContainerHigh = Color(0xFF1C2D28);
  static const Color surfaceContainerHighest = Color(0xFF263833);

  static const Color onSurface = Color(0xFFD2E7DF);
  static const Color onSurfaceVariant = Color(0xFFBACBB9);
  static const Color outlineVariant = Color(0xFF3B4A3D);
  static const Color error = Color(0xFFFFB4AB);
  static const Color errorLight = Color(0xFFBA1A1A);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryNeon,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        surface: surfaceBase,
        onSurface: onSurface,
        surfaceContainerLow: surfaceContainerLow,
        surfaceContainer: surfaceContainer,
        surfaceContainerHigh: surfaceContainerHigh,
        surfaceContainerHighest: surfaceContainerHighest,
        onSurfaceVariant: onSurfaceVariant,
        outlineVariant: outlineVariant,
      ),
      scaffoldBackgroundColor: surfaceBase,
      
      // Typography
      textTheme: TextTheme(
        displayLarge: GoogleFonts.spaceGrotesk(
          fontSize: 64,
          fontWeight: FontWeight.bold,
          letterSpacing: -2.0,
          color: onSurface,
        ),
        headlineSmall: GoogleFonts.spaceGrotesk(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2, // All-Caps Technical Manual Feel
          color: onSurface,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: onSurface,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: onSurfaceVariant,
        ),
      ),

      // Component Themes following the "No-Line" Rule
      cardTheme: CardThemeData(
        color: surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
          side: BorderSide.none,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: primaryNeon, width: 2),
        ),
        labelStyle: GoogleFonts.inter(color: onSurfaceVariant),
        hintStyle: GoogleFonts.inter(color: onSurfaceVariant.withValues(alpha: 0.5)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryContainer,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    // High-contrast, premium "Lumina Light" palette
    const Color forestPrimary = Color(0xFF1BA34A);   // Deeper, richer green
    const Color forestDeep   = Color(0xFF061409);    // Near-black for primary text
    const Color forestMid    = Color(0xFF2A3D2D);    // Dark green-grey for secondary text
    const Color mintBase     = Color(0xFFF4FBF5);    // Subtle cool mint background

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: forestPrimary,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFDCFCE7),
        onPrimaryContainer: forestDeep,
        surface: Colors.white,
        onSurface: forestDeep,
        surfaceContainerLowest: mintBase,
        surfaceContainerLow: const Color(0xFFECF8EE),
        surfaceContainer: const Color(0xFFE3F4E6),
        surfaceContainerHigh: const Color(0xFFD8EFDC),
        surfaceContainerHighest: const Color(0xFFCCE9D1),
        onSurfaceVariant: forestMid,
        outlineVariant: const Color(0xFFB2CEB5),
        error: errorLight,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: mintBase,

      textTheme: TextTheme(
        displayLarge: GoogleFonts.spaceGrotesk(
          fontSize: 64,
          fontWeight: FontWeight.bold,
          letterSpacing: -2.0,
          color: forestDeep,
        ),
        headlineSmall: GoogleFonts.spaceGrotesk(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: forestDeep,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: forestDeep,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: forestMid,
        ),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFCCE9D1), width: 1.5),
        ),
        shadowColor: const Color(0xFF1BA34A).withValues(alpha: 0.08),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFECF8EE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFB2CEB5), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: forestPrimary, width: 2),
        ),
        labelStyle: GoogleFonts.inter(color: forestMid),
        hintStyle: GoogleFonts.inter(color: forestMid.withValues(alpha: 0.5)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: forestPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
