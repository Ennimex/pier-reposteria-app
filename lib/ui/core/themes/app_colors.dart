//app/lib/core/constants/app_colors.dart
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/ui/core/themes/tema_catalogo.dart';

/// Fachada de color de la app. Los tokens de MARCA ya no son const: leen la
/// paleta ACTIVA del tema de temporada, que TemaProvider aplica con
/// [aplicarPaleta] — mismo modelo que las variables CSS --pier-* de la web.
/// Por eso ninguna expresión `const` puede referenciarlos; las pantallas
/// observan TemaProvider para repintarse cuando el tema cambia.
class AppColors {
  AppColors._();

  static PaletaPier _paleta = temaNormal.colores;
  static void aplicarPaleta(PaletaPier paleta) => _paleta = paleta;

  // Paleta Oficial de Pier Repostería (dinámica por tema de temporada)
  static Color get pierVerde => _paleta.verde;
  static Color get pierVerdeOscuro => _paleta.verdeOscuro;
  static Color get pierVerdeClaro => _paleta.verdeClaro;
  static Color get pierDorado => _paleta.dorado;
  static Color get pierDoradoOscuro => _paleta.doradoOscuro;
  static Color get pierDoradoClaro => _paleta.doradoClaro;
  static Color get pierArena => _paleta.arena;
  static Color get pierArenaOscuro => _paleta.arenaOscuro;

  // Colores de texto de apoyo (fijos: no cambian con el tema)
  static const Color textPrimary = Color(0xFF222222);
  static const Color textSecondary = Color(0xFF757575);

  // Semánticos derivados (estado de pedido / feedback): los que apuntan a la
  // paleta siguen al tema activo; error/cancelado son terracota fija.
  static Color get estadoPendiente => pierDorado; // espera (cálido)
  static Color get estadoPreparacion => pierDoradoOscuro; // en proceso
  static Color get estadoListo => pierVerde; // listo / go
  static const Color estadoCompletado = textSecondary; // cerrado
  static const Color estadoCancelado = Color(0xFFC1665A); // terracota Pier
  static Color get exito => pierVerde;
  static Color get aviso => pierDoradoOscuro;
  static const Color error = Color(0xFFC1665A);

  // Estados de entrega a domicilio (repartidor). Azul apizarrado fijo para
  // "en camino" (tránsito), distinguible del verde de "entregada".
  static Color get estadoAsignada => pierDorado; // por iniciar (cálido)
  static const Color estadoEnCamino = Color(0xFF5B7BA5); // en tránsito
  static Color get estadoEntregada => pierVerde; // entregada OK
  static const Color estadoFallida = error; // fallo (terracota)
}
