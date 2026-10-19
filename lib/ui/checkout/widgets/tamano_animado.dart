// lib/ui/checkout/widgets/tamano_animado.dart
//
// AnimatedSize con el ritmo de Pier para el carrito y el checkout: cuando
// una sección cambia de alto (recoger ↔ domicilio, la lista de direcciones
// que recarga, el bloque de descuentos que aparece), lo de abajo se desliza
// en vez de saltar. Con movimiento reducido el cambio es casi instantáneo
// (AnimatedSize no admite duración cero: se resuelve al cuadro siguiente).
import 'package:flutter/material.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';

class TamanoAnimado extends StatelessWidget {
  const TamanoAnimado({
    required this.child,
    this.duracion = AppMovimiento.corta,
    this.alineacion = Alignment.topCenter,
    this.holgura,
    super.key,
  });

  final Widget child;
  final Duration duracion;
  final AlignmentGeometry alineacion;

  /// Sin holgura, lo que sobresale se recorta solo mientras el alto crece
  /// (como AnimatedSize). Con holgura, nunca se recorta dentro de ese margen
  /// alrededor (sombras de las tarjetas, contenido que entra deslizándose de
  /// lado) y sí más allá (lo que todavía no cabe mientras el alto crece no
  /// se encima en la sección de abajo).
  final double? holgura;

  static const Duration _instante = Duration(milliseconds: 1);

  @override
  Widget build(BuildContext context) {
    final margen = holgura;
    final tamano = AnimatedSize(
      duration: AppMovimiento.reducido(context) ? _instante : duracion,
      curve: AppMovimiento.curvaEnfasis,
      alignment: alineacion,
      clipBehavior: margen == null ? Clip.hardEdge : Clip.none,
      child: child,
    );
    if (margen == null) return tamano;
    return ClipRect(clipper: _ConHolgura(margen), child: tamano);
  }
}

/// Recorte del tamaño actual agrandado [margen] por cada lado.
class _ConHolgura extends CustomClipper<Rect> {
  const _ConHolgura(this.margen);

  final double margen;

  @override
  Rect getClip(Size size) => (Offset.zero & size).inflate(margen);

  @override
  bool shouldReclip(_ConHolgura oldClipper) => oldClipper.margen != margen;
}
