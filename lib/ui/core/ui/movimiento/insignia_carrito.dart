// lib/ui/core/ui/movimiento/insignia_carrito.dart
//
// Insignia de cantidad del carrito: aparece creciendo cuando la cantidad
// pasa de 0 a algo, desaparece encogiéndose (y sale del árbol) al volver a
// 0, y rebota SOLO cuando la cantidad sube; si baja (o el backend revierte)
// el número cambia sin rebote. Al montarse no anima (cambiar de pestaña no
// la hace saltar). Sirve igual para cualquier contador de la app.
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/ui/core/themes/app_movimiento.dart';

class InsigniaCarrito extends StatefulWidget {
  const InsigniaCarrito({
    required this.cantidad,
    this.color = Colors.red,
    super.key,
  });

  final int cantidad;
  final Color color;

  @override
  State<InsigniaCarrito> createState() => _InsigniaCarritoState();
}

class _InsigniaCarritoState extends State<InsigniaCarrito>
    with TickerProviderStateMixin {
  static final Animatable<double> _salto = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 1.35,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.35,
          end: 1,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 70,
      ),
    ],
  );

  late final AnimationController _presencia;
  late final CurvedAnimation _escalaPresencia;
  late final AnimationController _rebote;

  // La insignia que se va conserva su último número (no muestra «0»).
  late int _numero = widget.cantidad;

  // Se crean aquí y no de forma perezosa: una insignia que nunca se mostró
  // no debe crear controladores al desmontarse.
  @override
  void initState() {
    super.initState();
    _presencia = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      reverseDuration: AppMovimiento.rapida,
      value: widget.cantidad > 0 ? 1 : 0,
    )..addStatusListener(_alCambiarPresencia);
    _escalaPresencia = CurvedAnimation(
      parent: _presencia,
      curve: AppMovimiento.curvaRebote,
      reverseCurve: Curves.easeIn,
    );
    _rebote = AnimationController(vsync: this, duration: AppMovimiento.enfasis);
  }

  @override
  void didUpdateWidget(InsigniaCarrito oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nueva = widget.cantidad;
    final vieja = oldWidget.cantidad;
    if (nueva == vieja) return;
    if (nueva > 0) _numero = nueva;
    final reducido = AppMovimiento.reducido(context);
    if (nueva > 0 && vieja <= 0) {
      if (reducido) {
        _presencia.value = 1;
      } else {
        _presencia.forward().ignore();
      }
    } else if (nueva <= 0 && vieja > 0) {
      if (reducido) {
        _presencia.value = 0;
      } else {
        _presencia.reverse().ignore();
      }
    } else if (nueva > vieja && !reducido) {
      _rebote.forward(from: 0).ignore();
    }
  }

  void _alCambiarPresencia(AnimationStatus estado) {
    // Al terminar de encogerse sale del árbol.
    if (estado == AnimationStatus.dismissed) setState(() {});
  }

  @override
  void dispose() {
    _escalaPresencia.dispose();
    _presencia.dispose();
    _rebote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_presencia.isDismissed) return const SizedBox.shrink();
    return ScaleTransition(
      scale: _escalaPresencia,
      child: ScaleTransition(
        scale: _rebote.drive(_salto),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
          child: Text(
            '$_numero',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
