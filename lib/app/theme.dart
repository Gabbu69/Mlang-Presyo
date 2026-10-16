import 'package:flutter/material.dart';

ThemeData appTheme() {
  const green = Color(0xFF174D38);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: green,
        brightness: Brightness.light,
      ).copyWith(
        primary: green,
        secondary: const Color(0xFF8F430D),
        surface: const Color(0xFFFFFCF5),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF7F3E9),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF7F3E9),
      foregroundColor: green,
      centerTitle: false,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontSize: 16),
      bodyMedium: TextStyle(fontSize: 16),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.all(16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52)),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xFFFFFCF5),
    ),
    visualDensity: VisualDensity.standard,
  );
}
