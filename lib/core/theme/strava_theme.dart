import 'package:flutter/material.dart';

/// Strava brand colors and app theme
/// Primary: #FC4C02 (tangelo), Secondary: #CC4200 (grenadier)
class StravaTheme {
  StravaTheme._();

  static const Color orange = Color(0xFFFC4C02);
  static const Color orangeDark = Color(0xFFCC4200);
  static const Color orangeLight = Color(0xFFFF6B2C);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey800 = Color(0xFF424242);
  static const Color green = Color(0xFF1DB954);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: orange,
      scaffoldBackgroundColor: grey100,
      colorScheme: ColorScheme.light(
        primary: orange,
        secondary: orangeDark,
        surface: white,
        error: Colors.red.shade700,
        onPrimary: white,
        onSecondary: white,
        onSurface: black,
        onError: white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: orange,
        foregroundColor: white,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: white,
        selectedItemColor: orange,
        unselectedItemColor: grey600,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: orange,
          side: const BorderSide(color: orange),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: orange),
      ),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: orange),
        ),
        focusColor: orange,
      ),
    );
  }
}
