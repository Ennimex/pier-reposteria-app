// lib/ui/core/ui/movimiento/presion_escala.dart
//
// Respuesta al tocar para tarjetas y controles hechos con GestureDetector
// (que no tienen la tinta de InkWell): el hijo se hunde un poco mientras el
// dedo está abajo y regresa con un rebote leve al soltar. Si el dedo se
// arrastra (un scroll que empezó encima), regresa ya sin terminar de hundirse.
//
// Usa un Listener: nunca entra a la arena de gestos, así que el onTap del
// GestureDetector de adentro sigue igual (se dispara al soltar, como antes).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/ui/core/themes/app_movimiento.dart';

class PresionEscala extends StatefulWidget {
  const PresionEscala({
    required this.child,
    this.escala = AppMovimiento.escalaPresion,
    super.key,
  });

  final Widget child;

  /// Escala al estar presionado: AppMovimiento.escalaPresion en tarjetas y
  /// AppMovimiento.escalaPresionChica en controles redondos y chips.
  final double escala;

  @override
  State<PresionEscala> createState() => _PresionEscalaState();
}

class _PresionEscalaState extends State<PresionEscala>
    with SingleTickerProviderStateMixin {
  // Punteros que ya hundió una PresionEscala más interna: la de afuera no se
  // hunde (tocar el corazón o el «+» no hunde la tarjeta completa). Los
  // eventos llegan primero al widget más profundo.
  static final Set<int> _reclamados = <int>{};

  // Atenuado que sustituye a la escala con movimiento reducido.
  static final Animatable<double> _atenuado = Tween<double>(
    begin: 1,
    end: 0.82,
  );

  late final AnimationController _control;
  late final CurvedAnimation _curva;
  late Animation<double> _escala;

  int? _puntero;
  Offset _origen = Offset.zero;
  bool _reducido = false;

  @override
  void initState() {
    super.initState();
    _control = AnimationController(
      vsync: this,
      duration: AppMovimiento.presion,
      reverseDuration: const Duration(milliseconds: 220),
    )..addStatusListener(_alCambiarEstado);
    // Al soltar regresa con easeInBack invertido: se pasa un poco de 1 y
    // asienta (un resorte corto).
    _curva = CurvedAnimation(
      parent: _control,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeInBack,
    );
    _escala = _curva.drive(Tween<double>(begin: 1, end: widget.escala));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducido = AppMovimiento.reducido(context);
  }

  @override
  void didUpdateWidget(PresionEscala oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.escala != widget.escala) {
      _escala = _curva.drive(Tween<double>(begin: 1, end: widget.escala));
    }
  }

  // El GestureBinding guarda el camino del toque: si la tarjeta se desmonta
  // con el dedo abajo (la lista se recargó), los eventos siguientes todavía
  // llegan aquí. Desmontada, ya no hace nada.
  void _alBajar(PointerDownEvent evento) {
    if (!mounted || _puntero != null || !_reclamados.add(evento.pointer)) {
      return;
    }
    _puntero = evento.pointer;
    _origen = evento.position;
    _control.forward().ignore();
  }

  void _alMover(PointerMoveEvent evento) {
    // Si el dedo se arrastra es un scroll, no un toque: se cancela ya.
    if (mounted &&
        evento.pointer == _puntero &&
        (evento.position - _origen).distance > kTouchSlop) {
      _cancelar();
    }
  }

  void _alLevantar(PointerUpEvent evento) {
    if (mounted && evento.pointer == _puntero) _soltar();
  }

  void _alCancelarPuntero(PointerCancelEvent evento) {
    if (mounted && evento.pointer == _puntero) _cancelar();
  }

  void _liberar() {
    _reclamados.remove(_puntero);
    _puntero = null;
  }

  // Toque terminado: en un toque rápido el hundido aún no termina y el
  // status listener lo regresa al completarse, así el pulso siempre se
  // alcanza a ver.
  void _soltar() {
    _liberar();
    if (!_control.isAnimating) _control.reverse().ignore();
  }

  // Scroll o puntero cancelado: no fue un toque, regresa ya desde donde va
  // (un scroll que empieza sobre la tarjeta casi no la hunde).
  void _cancelar() {
    _liberar();
    _control.reverse().ignore();
  }

  void _alCambiarEstado(AnimationStatus estado) {
    if (estado == AnimationStatus.completed && _puntero == null) {
      _control.reverse().ignore();
    }
  }

  @override
  void dispose() {
    final puntero = _puntero;
    if (puntero != null) _reclamados.remove(puntero);
    _puntero = null;
    _curva.dispose();
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _alBajar,
      onPointerMove: _alMover,
      onPointerUp: _alLevantar,
      onPointerCancel: _alCancelarPuntero,
      child: FadeTransition(
        opacity: _reducido
            ? _control.drive(_atenuado)
            : kAlwaysCompleteAnimation,
        child: ScaleTransition(
          scale: _reducido ? kAlwaysCompleteAnimation : _escala,
          child: widget.child,
        ),
      ),
    );
  }
}
