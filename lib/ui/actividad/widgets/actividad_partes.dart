// lib/ui/actividad/widgets/actividad_partes.dart
//
// Piezas que comparten las pestañas de «Actividad del equipo» (#139): el
// título de cada sección con su explicación, la tarjeta blanca, la etiqueta
// (la entidad de un movimiento o «Inactiva»), el aviso de una sección sin
// datos y el de un refresco que no logró poner al día.
import 'package:flutter/material.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';

/// Avisa en terracota por qué no se pudo poner al día; lo cargado se queda.
void avisarActividad(BuildContext context, String motivo) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(motivo),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// El título de una sección y, debajo, lo que muestra.
class TituloActividad extends StatelessWidget {
  const TituloActividad(this.titulo, {super.key, this.detalle});

  final String titulo;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              titulo,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (detalle case final texto?) ...[
            const SizedBox(height: 2),
            Text(
              texto,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta blanca de la lista. Es un Material para que lo que se toca
/// adentro (los filtros) muestre su onda.
class TarjetaActividad extends StatelessWidget {
  const TarjetaActividad({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: child,
        ),
      ),
    );
  }
}

/// Etiqueta de color: la entidad de un movimiento (en gris) o una marca
/// como «Inactiva».
class InsigniaActividad extends StatelessWidget {
  const InsigniaActividad(
    this.texto, {
    super.key,
    this.color = AppColors.textSecondary,
  });

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Una sección sin nada que mostrar.
class SinDatosActividad extends StatelessWidget {
  const SinDatosActividad(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return TarjetaActividad(
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
