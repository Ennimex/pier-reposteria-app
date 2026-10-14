// lib/ui/core/ui/movimiento/insignia_carrito.dart
//
// Insignia de cantidad del carrito: aparece creciendo cuando la cantidad
// pasa de 0 a algo, desaparece encogiéndose (y sale del árbol) al volver a
// 0, y rebota SOLO cuando la cantidad sube; si baja (o el backend revierte)
// el número cambia sin rebote. Al montarse no anima (cambiar de pestaña no
// la hace saltar). Sirve igual para cualquier contador de la app.
//
// Bajo el ámbito del vuelo al carrito, con una miniatura en camino (en el
// aire, o reservada por un alta que espera al backend: lanzarAlConfirmar),
// no se adelanta: el número cambia al instante pero no rebota (la reacción
// es el trago del destino) y, si aparece desde 0, crece cuando la miniatura
// llega o la reserva se suelta sin vuelo. Vale para la del destino (la
// barra) y para cualquier otra del ámbito (el carrito del encabezado del
// catálogo, que así no reacciona antes de que el producto llegue).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/ui/core/themes/app_movimiento.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/vuelo_al_carrito.dart';

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

  // Mientras espera a una miniatura para aparecer: los vuelos en camino y
  // cuántos había la última vez (bajan cuando una aterriza o cuando una
  // reserva se suelta sin vuelo).
  ValueListenable<int>? _enCamino;
  int _vuelosVistos = 0;

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
    // Una miniatura en camino al carrito (en el aire o reservada): la
    // insignia no se adelanta, sea la del destino o la de otro carrito del
    // mismo ámbito.
    final enCamino = reducido
        ? null
        : DestinoVuelo.enCamino(context) ?? VueloAlCarrito.enCamino(context);
    final vuelo = enCamino != null && enCamino.value > 0 ? enCamino : null;
    if (nueva > 0 && vieja <= 0) {
      if (reducido) {
        _presencia.value = 1;
      } else if (vuelo != null) {
        _esperarVuelo(vuelo);
      } else {
        _presencia.forward().ignore();
      }
    } else if (nueva <= 0 && vieja > 0) {
      _dejarDeEsperar();
      if (reducido) {
        _presencia.value = 0;
      } else {
        _presencia.reverse().ignore();
      }
    } else if (nueva > vieja && !reducido && vuelo == null) {
      _rebote.forward(from: 0).ignore();
    }
  }

  void _esperarVuelo(ValueListenable<int> enCamino) {
    _dejarDeEsperar();
    _vuelosVistos = enCamino.value;
    _enCamino = enCamino..addListener(_alCambiarVuelos);
  }

  void _alCambiarVuelos() {
    final enCamino = _enCamino;
    if (enCamino == null) return;
    final aterrizo = enCamino.value < _vuelosVistos;
    _vuelosVistos = enCamino.value;
    if (!aterrizo) return;
    _dejarDeEsperar();
    _presencia.forward().ignore();
  }

  void _dejarDeEsperar() {
    _enCamino?.removeListener(_alCambiarVuelos);
    _enCamino = null;
  }

  void _alCambiarPresencia(AnimationStatus estado) {
    // Al terminar de encogerse sale del árbol.
    if (estado == AnimationStatus.dismissed) setState(() {});
  }

  @override
  void dispose() {
    _dejarDeEsperar();
    _escalaPresencia.dispose();
    _presencia.dispose();
    _rebote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Esperando a la miniatura ya está en el árbol (las pruebas encuentran
    // el número), pero a escala 0.
    if (_presencia.isDismissed && _enCamino == null) {
      return const SizedBox.shrink();
    }
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
