import 'package:flutter/material.dart';
class AppThemes{
BuildContext context;
AppThemes({required this.context});
ThemeData themeData = ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF8B5CF6), // A vibrant purple accent
        scaffoldBackgroundColor: const Color(0xFF1E1E2C), // Dark background
        cardColor: const Color(0xFF28283D), // Slightly lighter background for cards/panels
        dialogBackgroundColor: const Color(0xFF28283D), // Dialog background
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF28283D), // AppBar background
          foregroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 60, // Adjust height as seen in images
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Colors.white),
          displayMedium: TextStyle(color: Colors.white),
          displaySmall: TextStyle(color: Colors.white),
          headlineLarge: TextStyle(color: Colors.white),
          headlineMedium: TextStyle(color: Colors.white),
          headlineSmall: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
          titleMedium: TextStyle(color: Colors.white),
          titleSmall: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white70),
          bodyMedium: TextStyle(color: Colors.white70),
          bodySmall: TextStyle(color: Colors.white60),
          labelLarge: TextStyle(color: Colors.white),
          labelMedium: TextStyle(color: Colors.white),
          labelSmall: TextStyle(color: Colors.white54),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF33334A), // Search bar and input field background
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Color(Colors.primaries.length)),
          ),
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIconColor: Colors.white54,
          suffixIconColor: Colors.white54,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.white70),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF8B5CF6), // Purple accent
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white30),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: MaterialStateProperty.all(const Color(0xFF33334A)),
            surfaceTintColor: MaterialStateProperty.all(Colors.white),
          ),
          textStyle: const TextStyle(color: Colors.white70),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: const Color(0xFF33334A),
          textStyle: const TextStyle(color: Colors.white70),
        ),
        listTileTheme: const ListTileThemeData(
          textColor: Colors.white70,
          iconColor: Colors.white70,
          selectedColor: Color(0xFF8B5CF6),
          selectedTileColor: Color(0xFF33334A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8.0))),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF33334A),
          labelStyle: const TextStyle(color: Colors.white70),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        )
      );}