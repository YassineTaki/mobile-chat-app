// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg = Color(0xFF0A0C10);
  static const surface = Color(0xFF111318);
  static const surface2 = Color(0xFF171B22);
  static const surface3 = Color(0xFF1E232D);
  static const border = Color(0x12FFFFFF);
  static const border2 = Color(0x1FFFFFFF);
  static const accent = Color(0xFF4FFFB0);
  static const accentDim = Color(0x1F4FFFB0);
  static const accent2 = Color(0xFF7B61FF);
  static const accent2Dim = Color(0x1F7B61FF);
  static const danger = Color(0xFFFF4F6A);
  static const dangerDim = Color(0x1FFF4F6A);
  static const text = Color(0xFFE8ECF4);
  static const text2 = Color(0xFF8B919E);
  static const text3 = Color(0xFF555B68);
  static const bubbleOut = Color(0xFF1B2A22);
  static const bubbleIn = Color(0xFF171B22);
  static const warning = Color(0xFFFF9F40);
}

class AppTextStyles {
  static TextStyle mono({Color color = AppColors.text, double size = 12}) =>
      TextStyle(fontFamily: 'DMMono', color: color, fontSize: size);
}

ThemeData buildTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accent2,
      surface: AppColors.surface,
      error: AppColors.danger,
    ),
    textTheme: GoogleFonts.soraTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface2,
      hintStyle: const TextStyle(color: AppColors.text3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    ),
    dividerColor: AppColors.border,
    useMaterial3: true,
  );
}
