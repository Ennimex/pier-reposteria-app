// lib/ui/reviews/widgets/reportar_resena.dart
//
// «Reportar», discreto, en la reseña de otro cliente (#328): abre el correo
// ya escrito que arma el ViewModel y, si no hay app de correo, dice a dónde
// escribir (como «Eliminar mi cuenta», #222). Lo usan «Opiniones» y las
// opiniones destacadas del detalle del producto.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/reviews/view_model/reporte_resena.dart';
import 'package:url_launcher/url_launcher.dart';

class ReportarResena extends StatelessWidget {
  const ReportarResena({required this.correo, super.key});

  /// Arma el correo al tocar (la dirección de contacto se lee entonces).
  final Future<Uri> Function() correo;

  static const etiqueta = 'Reportar';

  Future<void> _reportar(BuildContext context) async {
    final avisos = ScaffoldMessenger.of(context);
    final uri = await correo();
    bool abierto;
    try {
      abierto = await launchUrl(uri);
    } on Exception {
      abierto = false;
    }
    if (!abierto) {
      avisos.showSnackBar(SnackBar(
        content: Text(ReporteResena.sinAppDeCorreo(uri.path)),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.textSecondary.withValues(alpha: 0.7);
    return TextButton.icon(
      onPressed: () => unawaited(_reportar(context)),
      icon: Icon(LucideIcons.flag, size: 13, color: color),
      label: Text(etiqueta, style: TextStyle(fontSize: 12, color: color)),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
