import 'package:flutter/material.dart';
//import 'package:google_fonts/google_fonts.dart';

class AppThemes {

 // Awesome Dark Theme
 static final ThemeData awesomeDarkTheme = ThemeData(
 primarySwatch: Colors.blueGrey,
 brightness: Brightness.dark, // Awesome style often includes dark theme
 visualDensity: VisualDensity.adaptivePlatformDensity,
 appBarTheme: const AppBarTheme(
 elevation: 0,
 centerTitle: true,
 backgroundColor: Colors.black12,
 ),
 scaffoldBackgroundColor: Colors.black87,
 cardColor: Colors.black26, // For cards/sections
 textTheme: const TextTheme( // Replaced .apply with direct TextTheme definition
 bodyLarge: TextStyle(color: Colors.white70),
 displayLarge: TextStyle(color: Colors.white),
 bodyMedium: TextStyle(color: Colors.white70), // Fallback for other text styles
 bodySmall: TextStyle(color: Colors.white70), // Fallback for other text styles
 titleLarge: TextStyle(color: Colors.white),
 ),
 inputDecorationTheme: InputDecorationTheme(
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 borderSide: BorderSide.none,
 ),
 filled: true,
 fillColor: Colors.white.withOpacity(0.08),
 hintStyle: const TextStyle(color: Colors.white30),
 labelStyle: const TextStyle(color: Colors.white70),
 contentPadding: const EdgeInsets.symmetric(
 horizontal: 16,
 vertical: 12,
 ),
 ),
 switchTheme: SwitchThemeData(
 thumbColor: MaterialStateProperty.resolveWith((states) {
 if (states.contains(MaterialState.selected)) {
 return Colors.tealAccent;
 }
 return Colors.grey[600];
 }),
 trackColor: MaterialStateProperty.resolveWith((states) {
 if (states.contains(MaterialState.selected)) {
 return Colors.tealAccent.withOpacity(0.5);
 }
 return Colors.grey[700];
 }),
 ),
 sliderTheme: SliderThemeData(
 trackHeight: 4,
 activeTrackColor: Colors.tealAccent,
 inactiveTrackColor: Colors.white.withOpacity(0.3),
 thumbColor: Colors.tealAccent,
 overlayColor: Colors.tealAccent.withOpacity(0.2),
 valueIndicatorColor: Colors.tealAccent,
 valueIndicatorTextStyle: const TextStyle(color: Colors.black),
 showValueIndicator: ShowValueIndicator.always,
 ),
 elevatedButtonTheme: ElevatedButtonThemeData(
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.teal, // Button background color
 foregroundColor: Colors.white, // Button text color
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(10),
 ),
 textStyle: const TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.bold,
 ),
 ),
 ),
 );
}