import 'package:flutter/material.dart';

/// App theme definitions with 4 color schemes
class AppTheme {
  // Theme colors
  static const _purple80 = Color(0xFFD0BCFF);
  static const _purpleGrey80 = Color(0xFFCCC2DC);
  static const _pink80 = Color(0xFFEFB8C8);
  static const _purple40 = Color(0xFF6650a4);
  static const _purpleGrey40 = Color(0xFF625b71);
  static const _pink40 = Color(0xFF7D5260);

  // Ocean colors
  static const _oceanBlue = Color(0xFF0077B6);
  static const _oceanCyan = Color(0xFF00B4D8);
  static const _oceanSand = Color(0xFFFFE5B4);

  // Forest colors
  static const _forestLightGreen = Color(0xFF90EE90);
  static const _forestBrown = Color(0xFF8B4513);
  static const _forestGreen = Color(0xFF228B22);

  static final Map<String, ThemeData> themes = {
    'Default': _lightTheme,
    'Ocean': _oceanTheme,
    'Dark Forest': _forestTheme,
    'Dark Purple': _darkPurpleTheme,
  };

  static final ThemeData _lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _purple40,
      brightness: Brightness.light,
      primary: _purple40,
      secondary: _purpleGrey40,
      tertiary: _pink40,
    ),
  );

  static final ThemeData _oceanTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: _oceanBlue,
      secondary: _oceanCyan,
      tertiary: _oceanSand,
      surface: const Color(0xFFF8FEFF),
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: const Color(0xFF191C1D),
      primaryContainer: _oceanBlue,
      onPrimaryContainer: Colors.white,
    ),
  );

  static final ThemeData _forestTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: _forestLightGreen,
      secondary: _forestBrown,
      tertiary: _forestGreen,
      surface: const Color(0xFF151111),
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: const Color(0xFFE2DEDE),
      primaryContainer: _forestGreen,
      onPrimaryContainer: Colors.black,
    ),
  );

  static final ThemeData _darkPurpleTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _purple80,
      brightness: Brightness.dark,
      primary: _purple80,
      secondary: _purpleGrey80,
      tertiary: _pink80,
    ),
  );

  static ThemeData getTheme(String themeName) {
    return themes[themeName] ?? _lightTheme;
  }
}
