// lib/ui/core/ui/movimiento/destello_corazon.dart
//
// Destello al marcar favorito: el corazón da un pop y alrededor sale un aro
// con unos puntos de azúcar. Solo cuando `activo` pasa de false a true
// DESPUÉS de que el usuario tocó el corazón: la carga masiva de favoritos
// (que también voltea corazones) y los toques sin sesión nunca destellan.
// Pintado con un CustomPainter (las pruebas cuentan íconos de corazón: aquí
// no se agrega ninguno) y sin bloquear toques.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/themes/app_movimiento.dart';

class DestelloCorazon extends StatefulWidget {
  const DestelloCorazon({
    required this.activo,
    required this.child,
    this.color = Colors.red,
    this.radio = 24,
    super.key,
  });

  /// Si el producto es favorito.
  final bool activo;

  /// El botón del corazón tal cual (su GestureDetector o IconButton).
  final Widget child;

  /// Color del aro y de la mitad de los puntos (la otra mitad es dorado).
  final Color color;

  /// Alcance del destello desde el centro, en dp (24 o menos dentro de una
  /// tarjeta, para que su recorte no lo corte).
  final double radio;

  @override
  State<DestelloCorazon> createState() => _DestelloCorazonState();
}

class _DestelloCorazonState extends State<DestelloCorazon>
    with SingleTickerProviderStateMixin {
  static final Animatable<double> _pop = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.3,
          end: 0.92,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0.92,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
    ],
  );

  late final AnimationController _control;

  // Hubo un toque dentro del corazón desde el último cambio de `activo`.
  bool _tocado = false;

  @override
  void initState() {
    super.initState();
    _control = AnimationController(
      vsync: this,
      duration: AppMovimiento.enfasis,
    );
  }

  @override
  void didUpdateWidget(DestelloCorazon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activo == widget.activo) return;
    final porElUsuario = _tocado;
    _tocado = false;
    if (widget.activo && porElUsuario && !AppMovimiento.reducido(context)) {
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
    final lado = widget.radio * 2 + 8;
    return Listener(
      onPointerDown: (_) => _tocado = true,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: OverflowBox(
                maxWidth: lado,
                maxHeight: lado,
                child: CustomPaint(
                  size: Size.square(lado),
                  painter: _PintorDestello(
                    avance: _control,
                    radio: widget.radio,
                    colores: <Color>[widget.color, AppColors.pierDorado],
                  ),
                ),
              ),
            ),
          ),
          ScaleTransition(scale: _control.drive(_pop), child: widget.child),
        ],
      ),
    );
  }
}

class _PintorDestello extends CustomPainter {
  _PintorDestello({
    required this.avance,
    required this.radio,
    required this.colores,
  }) : super(repaint: avance);

  static const int _puntos = 8;

  final Animation<double> avance;
  final double radio;
  final List<Color> colores;

  @override
  void paint(Canvas canvas, Size size) {
    final t = avance.value;
    if (t <= 0 || t >= 1) return;
    final centro = size.center(Offset.zero);
    final salida = Curves.easeOutCubic.transform(t);
    final alfa = 1 - t;

    // Aro que se abre y se adelgaza.
    canvas.drawCircle(
      centro,
      radio * (0.45 + 0.55 * salida),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - t)
        ..color = colores.first.withValues(alpha: alfa * 0.8),
    );

    // Puntos de azúcar que se alejan y se apagan.
    final pincel = Paint();
    for (var i = 0; i < _puntos; i++) {
      final angulo = -math.pi / 2 + i * 2 * math.pi / _puntos;
      final distancia = radio * (0.55 + 0.45 * salida);
      pincel.color = colores[i % colores.length].withValues(alpha: alfa);
      canvas.drawCircle(
        centro + Offset(math.cos(angulo), math.sin(angulo)) * distancia,
        2.2 * (1 - 0.5 * t),
        pincel,
      );
    }
  }

  @override
  bool shouldRepaint(_PintorDestello oldDelegate) =>
      oldDelegate.radio != radio ||
      oldDelegate.colores.first != colores.first ||
      oldDelegate.colores.last != colores.last;
}
