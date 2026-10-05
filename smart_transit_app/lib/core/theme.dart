import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- Core Brand & Neutral Surfaces ---
  static const Color brandNavy = Color(0xFF0B1F2A);      // Primary text & core brand navy
  static const Color primaryTeal = Color(0xFF087E8B);    // Primary SmartTransit teal & CTA
  static const Color surfaceGrey = Color(0xFFF4F7F8);    // App canvas / background grey
  static const Color cardSurface = Color(0xFFFFFFFF);    // Elevated cards & modals
  static const Color borderGrey = Color(0xFFD9E2E5);     // Clean dividers & subtle borders
  static const Color secondaryText = Color(0xFF64748B);  // Subtitles, metadata & captions
  static const Color botswanaSky = Color(0xFF6EC6E8);    // Botswana sky accent

  // --- Transport Mode Colors (Strict Semantic Separation) ---
  static const Color combiColor = Color(0xFF087E8B);     // Combi (Teal)
  static const Color busColor = Color(0xFF6366F1);       // Bus / Intercity Coach (Indigo)
  static const Color taxiColor = Color(0xFFFB7345);      // Taxi / Special Cab (Coral Orange)
  static const Color walkingColor = Color(0xFF64748B);   // Walking / neutral transfer (Slate)
  static const Color hailColor = Color(0xFFEF4444);      // Passenger hail / urgent rider action (Red)

  // --- Operational Status Colors (Separate from Modes) ---
  static const Color statusSuccess = Color(0xFF16A34A);  // Online / on-time / maintain pace (Green)
  static const Color statusWarning = Color(0xFFF59E0B);  // Waiting / delayed / slow down / caution (Amber)
  static const Color statusDanger = Color(0xFFDC2626);   // Offline / cancelled / alert / hold (Red)
  static const Color statusInfo = Color(0xFF2563EB);     // Info / rerouted / speed up (Blue)

  // --- Backward-Compatible Aliases ---
  static const Color black = brandNavy;
  static const Color white = cardSurface;
  static const Color offWhite = surfaceGrey;
  static const Color lightGrey = borderGrey;
  static const Color midGrey = secondaryText;
  static const Color darkGrey = Color(0xFF1E293B);
  static const Color disabledGrey = Color(0xFF94A3B8);
  static const Color accentBlue = statusInfo;
  static const Color accentGreen = statusSuccess;
  static const Color accentRed = statusDanger;
  static const Color accentAmber = statusWarning;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: surfaceGrey,
      colorScheme: const ColorScheme.light(
        primary: brandNavy,
        secondary: primaryTeal,
        tertiary: botswanaSky,
        surface: cardSurface,
        error: statusDanger,
        onPrimary: cardSurface,
        onSecondary: cardSurface,
        onSurface: brandNavy,
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(
        ThemeData.light().textTheme,
      ).apply(
        bodyColor: brandNavy,
        displayColor: brandNavy,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardSurface,
        foregroundColor: brandNavy,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderGrey, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandNavy,
          foregroundColor: cardSurface,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brandNavy,
          side: const BorderSide(color: borderGrey, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
