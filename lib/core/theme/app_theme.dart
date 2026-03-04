//app/lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      // Colores Base
      primaryColor: AppColors.pierVerde,
      scaffoldBackgroundColor: AppColors.pierArena, // Fondo color crema
      colorScheme: const ColorScheme.light(
        primary: AppColors.pierVerde,
        secondary: AppColors.pierDorado,
      ),
      
      // Tipografía general del sistema (Roboto/SF Pro)
      fontFamily: 'Roboto', // O deja el por defecto quitando esta línea

      // Estilo del AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.pierVerde,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          fontFamily: 'Playfair Display', // Tipografía oficial para títulos
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),

      // Estilo de botones principales
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pierVerde,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
      
      // Estilo de botones secundarios
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.pierVerde,
          side: const BorderSide(color: AppColors.pierVerde),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}