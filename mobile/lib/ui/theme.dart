import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const azulInstitucional = Color(0xFF0B5FA5);
  static const azulClaro = Color(0xFF1976D2);
  static const cinzaClaro = Color(0xFFF5F7FA);
  static const cinzaCampo = Color(0xFFE5E7EB);
  static const verde = Color(0xFF43A047);
  static const vermelho = Color(0xFFE53935);
  static const laranja = Color(0xFFFB8C00);
}

ThemeData buildTheme() {
  final textTheme = GoogleFonts.robotoTextTheme().copyWith(
    titleLarge: GoogleFonts.roboto(fontSize: 28, fontWeight: FontWeight.bold),
    titleMedium: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold),
    bodyMedium: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w400),
  );
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.azulInstitucional),
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.cinzaClaro,
    textTheme: textTheme,
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cinzaCampo,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide.none,
      ),
      contentPadding: EdgeInsets.all(12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.azulInstitucional,
      foregroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
      margin: EdgeInsets.all(8),
    ),
  );
}
