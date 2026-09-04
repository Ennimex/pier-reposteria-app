// lib/ui/core/themes/text_styles.dart
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';

/// Escala tipográfica central. Playfair Display para títulos;
/// Roboto (fontFamily del tema) para cuerpo y etiquetas.
class AppTextStyles {
  AppTextStyles._();

  static const String serif = 'Playfair Display';

  static TextTheme textTheme(TextTheme base) {
    return base.copyWith(
      displaySmall: const TextStyle(
          fontFamily: serif,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          height: 1.2),
      headlineMedium: const TextStyle(
          fontFamily: serif,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          height: 1.2),
      headlineSmall: const TextStyle(
          fontFamily: serif,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          height: 1.25),
      titleLarge: const TextStyle(
          fontFamily: serif,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary),
      titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary),
      titleSmall: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary),
      bodyLarge: const TextStyle(
          fontSize: 15, color: AppColors.textPrimary, height: 1.4),
      bodyMedium: const TextStyle(
          fontSize: 14, color: AppColors.textPrimary, height: 1.4),
      bodySmall: const TextStyle(
          fontSize: 12, color: AppColors.textSecondary, height: 1.3),
      labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary),
      labelSmall: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary),
    );
  }
}
