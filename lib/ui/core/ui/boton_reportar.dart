// lib/ui/core/ui/boton_reportar.dart
//
// «Reportar», discreto, en lo que publican otros clientes (#328): las
// reseñas (ReportarResena) y los comentarios de Novedades. Abre el correo ya
// escrito que arma el ViewModel y, si no hay app de correo, dice a dónde
// escribir (como «Eliminar mi cuenta», #222).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

/// Arma el correo de «Reportar» al tocarlo (la dirección de contacto se lee
/// entonces).
typedef CorreoDeReporte = Future<Uri> Function();

class BotonReportar extends StatelessWidget {
  const BotonReportar({
    required this.correo,
    required this.sinAppDeCorreo,
    super.key,
  });

  final CorreoDeReporte correo;

  /// El aviso si no hay app de correo, con la dirección a la que iba.
  final String Function(String destinatario) sinAppDeCorreo;

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
      avisos.showSnackBar(
        SnackBar(
          content: Text(sinAppDeCorreo(uri.path)),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
