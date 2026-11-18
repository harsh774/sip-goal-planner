import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tokens from the Claude Design canvas (docs/LLD.md §6.2).
abstract final class AppColors {
  static const background = Color(0xFF0B0B0C);
  static const layer = Color(0xFF161618);
  static const layer2 = Color(0xFF1F1F22);
  static const field = Color(0xFF232327);
  static const border = Color(0xFF2E2E33);
  static const borderStrong = Color(0xFF6B6B70);
  static const text = Color(0xFFF2F0EA);
  static const text2 = Color(0xFFB3B0A8);
  static const text3 = Color(0xFF8F8C84);
  static const gold = Color(0xFFD4AF37);
  static const goldHover = Color(0xFFE2C15A);
  static const onGold = Color(0xFF0B0B0C);
  static const goldTint = Color(0xFF2A2410);
  static const header = Color(0xFF000000);
  static const danger = Color(0xFFFF6B6B);
  static const dangerBg = Color(0xFF2D1215);
  static const success = Color(0xFF42BE65);
  static const successBg = Color(0xFF0E2A17);
  static const seriesLevel = Color(0xFF5B8DEF);
  static const seriesStepUp = Color(0xFFB38C25);
}

abstract final class AppRadius {
  static const button = 12.0;
}

abstract final class Breakpoints {
  static const compact = 640.0;
  static const contentMaxWidth = 1120.0;
}

abstract final class AppTheme {
  static ThemeData dark() {
    final base = ThemeData(brightness: .dark, useMaterial3: true);
    final text = GoogleFonts.ibmPlexSansTextTheme(
      base.textTheme,
    ).apply(bodyColor: AppColors.text, displayColor: AppColors.text);
    const square = RoundedRectangleBorder();
    final rounded = RoundedRectangleBorder(borderRadius: .circular(AppRadius.button));

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        onPrimary: AppColors.onGold,
        secondary: AppColors.seriesLevel,
        surface: AppColors.layer,
        onSurface: AppColors.text,
        error: AppColors.danger,
        outline: AppColors.borderStrong,
      ),
      textTheme: text,
      dividerColor: AppColors.border,
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.field,
        isDense: true,
        contentPadding: .symmetric(horizontal: 16, vertical: 12),
        border: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.borderStrong)),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.borderStrong)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.gold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.danger, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.danger, width: 2),
        ),
        labelStyle: TextStyle(color: AppColors.text2, fontSize: 13),
        floatingLabelBehavior: .always,
        helperStyle: TextStyle(color: AppColors.text2, fontSize: 12),
        errorStyle: TextStyle(color: AppColors.danger, fontSize: 12),
        errorMaxLines: 3,
        helperMaxLines: 2,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.onGold,
          minimumSize: const Size(64, 48),
          shape: rounded,
          elevation: 2,
          shadowColor: AppColors.gold.withValues(alpha: 0.4),
          textStyle: const TextStyle(fontSize: 15, fontWeight: .w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          minimumSize: const Size(64, 48),
          shape: rounded,
          side: const BorderSide(color: AppColors.borderStrong),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.gold,
          minimumSize: const Size(44, 44),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: AppColors.gold,
        side: BorderSide(color: AppColors.borderStrong),
        labelStyle: TextStyle(color: AppColors.text, fontSize: 14),
        secondaryLabelStyle: TextStyle(color: AppColors.onGold, fontSize: 14),
        shape: StadiumBorder(),
        showCheckmark: false,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.gold,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.gold,
        overlayColor: Color(0x33D4AF37),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.layer,
        shape: square,
        margin: EdgeInsets.zero,
      ),
      dialogTheme: const DialogThemeData(backgroundColor: AppColors.layer, shape: square),
      popupMenuTheme: const PopupMenuThemeData(color: AppColors.layer, shape: square),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.layer2,
        contentTextStyle: TextStyle(color: AppColors.text),
        behavior: .floating,
      ),
    );
  }
}
