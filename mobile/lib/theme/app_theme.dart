import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();
  static const primary = Color(0xFF4A1D5C);
  static const deep = Color(0xFF2B1038);
  static const pink = Color(0xFFD9A7A0);
  static const canvas = Color(0xFFFBF8F3);
  static const border = Color(0xFFEADFCB);
  // Slightly darker than the original #81778F so small text passes 4.5:1 contrast.
  static const muted = Color(0xFF6F6376);
  static const lavender = Color(0xFFF3E9D6);
  static const panel = Color(0xFFF6EFE2);
  static const water = Color(0xFF278BD8);
  static const waterSoft = Color(0xFFE5F4FF);
  static const success = Color(0xFF27845C);
  static const danger = Color(0xFFC54B62);
  static const sleep = Color(0xFF7B69C9);
  static const journal = Color(0xFFD27A45);
  static const insight = Color(0xFF2F8F7E);
  // Premium accent
  static const gold = Color(0xFFC9A66B);
  static const goldSoft = Color(0xFFFBF3E2);
}

class AppText {
  AppText._();
  static const pageTitle = TextStyle(
    color: AppColors.deep,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.15,
  );
  static const sectionTitle = TextStyle(
    color: AppColors.deep,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );
  static const cardTitle = TextStyle(
    color: AppColors.deep,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );
  static const body = TextStyle(
    color: AppColors.deep,
    fontSize: 14,
    height: 1.45,
  );
  static const bodyMuted = TextStyle(
    color: AppColors.muted,
    fontSize: 14,
    height: 1.45,
  );
  static const label = TextStyle(
    color: AppColors.muted,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );
  static const eyebrow = TextStyle(
    color: AppColors.primary,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
  );
  static const caption = TextStyle(
    color: AppColors.muted,
    fontSize: 12.5,
    height: 1.35,
  );
}

const double kRadius = 20;

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        surface: Colors.white,
      ).copyWith(
        primary: AppColors.primary,
        secondary: AppColors.gold,
        error: AppColors.danger,
      );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final fieldRadius = BorderRadius.circular(14);
  OutlineInputBorder outline(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: fieldRadius,
    borderSide: BorderSide(color: c, width: w),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.canvas,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.deep,
      displayColor: AppColors.deep,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.deep,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      shape: const Border(bottom: BorderSide(color: AppColors.border)),
      titleTextStyle: GoogleFonts.plusJakartaSans(
        color: AppColors.deep,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.lavender,
      selectedColor: AppColors.primary,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: GoogleFonts.plusJakartaSans(
        color: AppColors.deep,
        fontWeight: FontWeight.w600,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.deep,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: outline(AppColors.border),
      enabledBorder: outline(AppColors.border),
      focusedBorder: outline(AppColors.primary, 2),
      errorBorder: outline(AppColors.danger),
      focusedErrorBorder: outline(AppColors.danger, 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: fieldRadius),
        textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(0, 50),
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: fieldRadius),
        textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(48, 48),
        textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.lavender,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      space: 1,
      thickness: 1,
    ),
  );
}
