// lib/ui/core/ui/movimiento/entrada_dialogo.dart
//
// «Caja que se abre»: el contenido de un diálogo crece de 0.92 a 1 mientras
// el diálogo aparece con su fundido (y se encoge un poco al cerrarse). Va
// dentro del builder de showDialog, junto con AppMovimiento.estiloDialogo.
// Usa la animación de la propia ruta del diálogo: no crea controladores.
import 'package:flutter/material.dart';
import 'package:pier_reposteria/ui/core/themes/app_movimiento.dart';

class EntradaDialogo extends StatelessWidget {
  const EntradaDialogo({required this.child, super.key});

  /// El diálogo de siempre (AlertDialog, Dialog…).
  final Widget child;

  static final Animatable<double> _escala = Tween<double>(
    begin: 0.92,
    end: 1,
  ).chain(CurveTween(curve: AppMovimiento.curvaEnfasis));

  @override
  Widget build(BuildContext context) {
    final animacion = ModalRoute.of(context)?.animation;
    return ScaleTransition(
      scale: animacion == null || AppMovimiento.reducido(context)
          ? kAlwaysCompleteAnimation
          : animacion.drive(_escala),
      child: child,
    );
  }
}
