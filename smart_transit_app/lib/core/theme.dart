import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static bool useDarkPalette = false;

  // --- Core Brand & Neutral Surfaces ---
  static Color get brandNavy =>
      useDarkPalette ? const Color(0xFFF4F7FB) : const Color(0xFF0B1F2A);
  static const Color primaryTeal = Color(0xFF036CEA);
  static Color get surfaceGrey =>
      useDarkPalette ? const Color(0xFF0A1424) : const Color(0xFFF4F7F8);
  static Color get cardSurface =>
      useDarkPalette ? const Color(0xFF111C2D) : const Color(0xFFFFFFFF);
  static Color get borderGrey =>
      useDarkPalette ? const Color(0xFF34445D) : const Color(0xFFD9E2E5);
  static Color get secondaryText =>
      useDarkPalette ? const Color(0xFFB3C0D1) : const Color(0xFF64748B);
  static const Color botswanaSky = Color(0xFF6EC6E8); // Botswana sky accent

  // --- Logo Brand Colors (Extracted Directly From Logo) ---
  static const Color logoNavy = Color(
    0xFF06172F,
  ); // Deep Midnight Navy ("SMART" & S body)
  static const Color logoElectricBlue = Color(
    0xFF036CEA,
  ); // Electric Royal Blue (S circuit & nodes)
  static const Color logoCyan = Color(
    0xFF0088D1,
  ); // Bright Cyan / Sky Blue ("TRANSIT" & speed tracks)

  // --- Transport Mode Colors (Derived from Logo Brand Palette) ---
  static const Color combiColor =
      logoElectricBlue; // Combi (Electric Royal Blue - Urban Corridor)
  static const Color busColor =
      logoNavy; // Bus / Intercity Coach (Deep Midnight Navy - Intercity)
  static const Color taxiColor =
      logoCyan; // Taxi / Special Cab (Cyan / Sky Blue - On-Demand)
  static const Color walkingColor = Color(
    0xFF64748B,
  ); // Walking / neutral transfer (Slate)
  static const Color hailColor = Color(
    0xFFEF4444,
  ); // Passenger hail / urgent rider action (Red)

  // --- Operational Status Colors (Separate from Modes) ---
  static const Color statusSuccess = Color(
    0xFF16A34A,
  ); // Online / on-time / maintain pace (Green)
  static const Color statusWarning = Color(
    0xFFF59E0B,
  ); // Waiting / delayed / slow down / caution (Amber)
  static const Color statusDanger = Color(
    0xFFDC2626,
  ); // Offline / cancelled / alert / hold (Red)
  static const Color statusInfo = Color(
    0xFF2563EB,
  ); // Info / rerouted / speed up (Blue)

  // --- Backward-Compatible Aliases ---
  static Color get black =>
      useDarkPalette ? const Color(0xFFF4F7FB) : brandNavy;
  static Color get white =>
      useDarkPalette ? const Color(0xFF111C2D) : cardSurface;
  static Color get offWhite =>
      useDarkPalette ? const Color(0xFF1A2940) : surfaceGrey;
  static Color get lightGrey =>
      useDarkPalette ? const Color(0xFF34445D) : borderGrey;
  static Color get midGrey =>
      useDarkPalette ? const Color(0xFFB3C0D1) : secondaryText;
  static Color get darkGrey =>
      useDarkPalette ? const Color(0xFFCFD9E8) : const Color(0xFF1E293B);
  static Color get disabledGrey =>
      useDarkPalette ? const Color(0xFF73839A) : const Color(0xFF94A3B8);
  static Color get onPrimary => const Color(0xFFFFFFFF);
  static Color get textPrimary => black;
  static Color get textSecondary => midGrey;
  static Color get surface => white;
  static Color get surfaceContainer => offWhite;
  static Color get outline => lightGrey;
  static const Color accentBlue = statusInfo;
  static const Color accentGreen = statusSuccess;
  static const Color accentRed = statusDanger;
  static const Color accentAmber = statusWarning;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: surfaceGrey,
      colorScheme: ColorScheme.light(
        primary: primaryTeal,
        secondary: logoCyan,
        tertiary: botswanaSky,
        surface: cardSurface,
        error: statusDanger,
        onPrimary: const Color(0xFFFFFFFF),
        onSecondary: const Color(0xFFFFFFFF),
        onSurface: Color(0xFF0B1F2A),
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(
        ThemeData.light().textTheme,
      ).apply(bodyColor: brandNavy, displayColor: brandNavy),
      appBarTheme: AppBarTheme(
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
          side: BorderSide(color: borderGrey, width: 1),
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
          side: BorderSide(color: borderGrey, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceGrey,
        labelStyle: TextStyle(color: secondaryText),
        hintStyle: TextStyle(color: secondaryText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderGrey),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    const background = Color(0xFF0A1424);
    const surface = Color(0xFF111C2D);
    const container = Color(0xFF1A2940);
    const outline = Color(0xFF34445D);
    const text = Color(0xFFF4F7FB);
    const muted = Color(0xFFB3C0D1);
    const accent = Color(0xFF25BDF2);
    final scheme = const ColorScheme.dark(
      primary: accent,
      secondary: Color(0xFF52D2F4),
      tertiary: Color(0xFF6EC6E8),
      surface: surface,
      error: statusDanger,
      onPrimary: Color(0xFF04111F),
      onSecondary: Color(0xFF04111F),
      onSurface: text,
      outline: outline,
      surfaceContainer: container,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      textTheme: GoogleFonts.spaceGroteskTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: text, displayColor: text),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: outline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: const Color(0xFF04111F),
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
          foregroundColor: text,
          side: const BorderSide(color: outline, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: container,
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: outline),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: Color(0xFF243C59),
      ),
      dialogTheme: const DialogThemeData(backgroundColor: surface),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: surface),
      dividerTheme: const DividerThemeData(color: outline),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
    );
  }
}
