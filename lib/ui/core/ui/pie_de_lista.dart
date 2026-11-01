// lib/ui/core/ui/pie_de_lista.dart
//
// Abajo de una lista que llega por páginas (el catálogo, #37, y Novedades,
// #132): el indicador mientras llega la siguiente y el aviso con
// «Reintentar» cuando no pudo llegar. Uno solo, para que las dos se vean y se
// comporten igual (#283).
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';

/// El indicador de abajo mientras llega la siguiente página. [etiqueta] es lo
/// que anuncia un lector de pantalla.
class CargandoMas extends StatelessWidget {
  const CargandoMas({this.etiqueta, super.key});

  final String? etiqueta;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.pierVerde,
            semanticsLabel: etiqueta,
          ),
        ),
      );
}

/// Aviso de una lista: ícono, título, detalle y, si hay [accion],
/// «Reintentar».
class AvisoDeLista extends StatelessWidget {
  const AvisoDeLista({
    required this.icono,
    required this.titulo,
    this.detalle,
    this.accion,
    super.key,
  });

  /// La siguiente página no llegó: [detalle] dice por qué y [alReintentar]
  /// la vuelve a pedir.
  const AvisoDeLista.noCargaronMas({
    required this.detalle,
    required VoidCallback alReintentar,
    super.key,
  })  : icono = LucideIcons.wifiOff,
        titulo = 'No se pudieron cargar más',
        accion = alReintentar;

  final IconData icono;
  final String titulo;
  final String? detalle;
  final VoidCallback? accion;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          children: [
            Icon(icono, size: 36, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (detalle case final detalle?)
              Text(
                detalle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            if (accion != null)
              TextButton(onPressed: accion, child: const Text('Reintentar')),
          ],
        ),
      );
}
