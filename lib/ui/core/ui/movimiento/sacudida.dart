// lib/ui/core/ui/movimiento/sacudida.dart
//
// Sacudida de error: el hijo oscila de lado a lado y se apaga (tres vaivenes
// amortiguados). Se dispara de forma declarativa cuando cambia `disparo`; el
// mensaje de error (SnackBar, texto) sigue siendo el de siempre. Solo pinta:
// el layout no se mueve.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pier_reposteria/ui/core/themes/app_movimiento.dart';

class Sacudida extends StatefulWidget {
  const Sacudida({
    required this.disparo,
    required this.child,
    this.amplitud = AppMovimiento.distanciaCorta,
    super.key,
  });

  /// Cada vez que cambia a un valor no nulo, sacude. Lo más simple es un
  /// contador que la pantalla incrementa en cada error (así dos errores
  /// iguales seguidos también sacuden).
  final Object? disparo;

  final Widget child;

  /// Desplazamiento máximo en dp.
  final double amplitud;

  @override
  State<Sacudida> createState() => _SacudidaState();
}

class _SacudidaState extends State<Sacudida>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control;

  @override
  void initState() {
    super.initState();
    _control = AnimationController(
      vsync: this,
      duration: AppMovimiento.enfasis,
    );
  }

  @override
  void didUpdateWidget(Sacudida oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.disparo != oldWidget.disparo &&
        widget.disparo != null &&
        !AppMovimiento.reducido(context)) {
      _control.forward(from: 0).ignore();
    }
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _control,
      child: widget.child,
      builder: (context, hijo) {
        final t = _control.value;
        // Seno de tres ciclos que se apaga: empieza y termina en 0.
        final dx = math.sin(t * math.pi * 6) * (1 - t) * widget.amplitud;
        return Transform.translate(offset: Offset(dx, 0), child: hijo);
      },
    );
  }
}
