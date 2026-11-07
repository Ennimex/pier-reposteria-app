// lib/ui/reviews/widgets/reportar_resena.dart
//
// «Reportar», discreto, en la reseña de otro cliente (#328): el botón común
// (BotonReportar, también en los comentarios de Novedades) con el aviso de
// las reseñas si no hay app de correo. Lo usan «Opiniones» y las opiniones
// destacadas del detalle del producto.
import 'package:flutter/material.dart';
import 'package:pier_reposteria/ui/core/ui/boton_reportar.dart';
import 'package:pier_reposteria/ui/reviews/view_model/reporte_resena.dart';

class ReportarResena extends StatelessWidget {
  const ReportarResena({required this.correo, super.key});

  /// Arma el correo al tocar (la dirección de contacto se lee entonces).
  final CorreoDeReporte correo;

  static const String etiqueta = BotonReportar.etiqueta;

  @override
  Widget build(BuildContext context) => BotonReportar(
        correo: correo,
        sinAppDeCorreo: ReporteResena.sinAppDeCorreo,
      );
}
