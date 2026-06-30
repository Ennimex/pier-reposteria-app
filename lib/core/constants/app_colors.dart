//app/lib/core/constants/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // Paleta Oficial de Pier Repostería
  static const Color pierVerde = Color(0xFF6B7C3E);
  static const Color pierVerdeOscuro = Color(0xFF4A5A2B);
  static const Color pierDorado = Color(0xFFD4A574);
  static const Color pierDoradoOscuro = Color(0xFFB8895C);
  static const Color pierArena = Color(0xFFF5F1ED);

  // Colores de texto de apoyo
  static const Color textPrimary = Color(0xFF222222);
  static const Color textSecondary = Color(0xFF757575);

  // Semánticos derivados (estado de pedido / feedback) — dentro de la familia Pier.
  // Se declaran después de la paleta base para referenciarla sin forward-reference.
  static const Color estadoPendiente   = pierDorado;        // espera (cálido)
  static const Color estadoPreparacion = pierDoradoOscuro;  // en proceso
  static const Color estadoListo       = pierVerde;         // listo / go
  static const Color estadoCompletado  = textSecondary;     // cerrado
  static const Color estadoCancelado   = Color(0xFFC1665A); // terracota Pier
  static const Color exito = pierVerde;
  static const Color aviso = pierDoradoOscuro;
  static const Color error = Color(0xFFC1665A);
}