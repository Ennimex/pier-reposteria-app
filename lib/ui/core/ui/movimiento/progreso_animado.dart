// lib/ui/core/ui/movimiento/progreso_animado.dart
//
// Relleno tipo «manga pastelera»: un valor que se llena a ritmo parejo. En
// el primer cuadro visible va de 0 a `valor` (también en una pestaña oculta:
// espera a mostrarse) y, si después `valor` cambia, avanza desde donde iba.
// ProgresoAnimado entrega el número a un builder (para líneas de tiempo con
// pasos); BarraRelleno es la barra lista para usar.
import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';
import 'package:pier_reposteria/ui/core/themes/app_movimiento.dart';

/// Anima un número y se lo da a [builder]. Para una línea de tiempo,
/// `valor` puede ser el paso actual (0, 1, 2…): cada segmento i se pinta
/// lleno en `clampDouble(progreso - i, 0, 1)`.
class ProgresoAnimado extends StatefulWidget {
  const ProgresoAnimado({
    required this.valor,
    required this.builder,
    this.child,
    this.duracion = AppMovimiento.relleno,
    this.retraso = Duration.zero,
    this.curva = Curves.easeInOutCubic,
    this.desdeCero = true,
    super.key,
  });

  final double valor;
  final ValueWidgetBuilder<double> builder;

  /// Parte fija que el builder recibe sin reconstruirse.
  final Widget? child;

  final Duration duracion;

  /// Espera antes del primer llenado (p. ej. a que termine el push).
  final Duration retraso;

  final Curve curva;

  /// false: el primer valor se muestra ya lleno y solo se animan cambios.
  final bool desdeCero;

  @override
  State<ProgresoAnimado> createState() => _ProgresoAnimadoState();
}

class _ProgresoAnimadoState extends State<ProgresoAnimado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control;
  late double _desde = widget.desdeCero ? 0 : widget.valor;
  late double _hasta = widget.valor;
  late Curve _curva = widget.curva;
  bool _iniciado = false;

  double get _actual =>
      _desde + (_hasta - _desde) * _curva.transform(_control.value);

  @override
  void initState() {
    super.initState();
    _control = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    if (_desde == _hasta ||
        widget.duracion <= Duration.zero ||
        AppMovimiento.reducido(context)) {
      _llenar();
      return;
    }
    final total = widget.retraso + widget.duracion;
    _control.duration = total;
    _curva = Interval(
      widget.retraso.inMicroseconds / total.inMicroseconds,
      1,
      curve: widget.curva,
    );
    // Desde un post-frame: en una pestaña oculta espera a mostrarse.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _control.forward().ignore();
    });
  }

  void _llenar() {
    _desde = _hasta;
    _control.value = 1;
  }

  @override
  void didUpdateWidget(ProgresoAnimado oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valor == widget.valor) return;
    _desde = _actual;
    _hasta = widget.valor;
    if (AppMovimiento.reducido(context) ||
        !TickerMode.valuesOf(context).enabled ||
        widget.duracion <= Duration.zero) {
      _llenar();
      return;
    }
    _curva = widget.curva;
    _control.duration = widget.duracion;
    _control.forward(from: 0).ignore();
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
      builder: (context, child) => widget.builder(context, _actual, child),
    );
  }
}

/// Barra que se llena hasta [fraccion] (0 a 1): estados de entregas,
/// distribución de reseñas, conectores de una línea de tiempo. En vertical
/// necesita un alto dado por el padre.
class BarraRelleno extends StatelessWidget {
  const BarraRelleno({
    required this.fraccion,
    required this.color,
    this.fondo,
    this.grosor = 6,
    this.eje = Axis.horizontal,
    this.duracion = AppMovimiento.relleno,
    this.retraso = Duration.zero,
    super.key,
  });

  final double fraccion;
  final Color color;

  /// Color del riel; por defecto [color] muy tenue.
  final Color? fondo;

  final double grosor;
  final Axis eje;
  final Duration duracion;
  final Duration retraso;

  @override
  Widget build(BuildContext context) {
    final horizontal = eje == Axis.horizontal;
    final redondeo = BorderRadius.circular(grosor / 2);
    return ClipRRect(
      borderRadius: redondeo,
      child: SizedBox(
        width: horizontal ? null : grosor,
        height: horizontal ? grosor : null,
        child: ColoredBox(
          color: fondo ?? color.withValues(alpha: 0.15),
          child: ProgresoAnimado(
            valor: clampDouble(fraccion, 0, 1),
            duracion: duracion,
            retraso: retraso,
            builder: (context, avance, _) => FractionallySizedBox(
              alignment: horizontal
                  ? AlignmentDirectional.centerStart
                  : AlignmentDirectional.topCenter,
              widthFactor: horizontal ? avance : 1,
              heightFactor: horizontal ? 1 : avance,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: redondeo,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
