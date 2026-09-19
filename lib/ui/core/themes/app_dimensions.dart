// lib/ui/core/themes/app_dimensions.dart
import 'package:flutter/widgets.dart';

/// Escala de espaciado (base 8pt), radios y elevaciones de Pier.
class AppDimensions {
  AppDimensions._();

  // Espaciado
  static const double space2 = 2;
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space48 = 48;

  // Radios
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusPill = 50;

  // Elevaciones
  static const double elevationNone = 0;
  static const double elevationLow = 2;
  static const double elevationMed = 4;

  // Padding de pantalla reutilizable
  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: space20);
}
