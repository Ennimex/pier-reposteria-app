// lib/ui/core/ui/movimiento/entrada_suave.dart
//
// Entrada de un bloque: fundido más una subida corta en dp y, si se pide,
// una escala inicial. Se reproduce UNA vez y en el primer cuadro en que el
// bloque se ve: arranca desde un post-frame callback, así que un Ticker
// silenciado (pestaña oculta, ruta tapada) no empieza a contar hasta que se
// muestra. Nunca usa Timers (las pruebas que terminan en un pump() quedan
// limpias), nunca bloquea toques y no se repite al reconstruir.
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/ui/core/themes/app_movimiento.dart';

/// Entrada de un bloque. Para una cascada se da `orden` 0, 1, 2… (cada
/// escalón espera AppMovimiento.paso; del séptimo en adelante entran juntos).
class EntradaSuave extends StatefulWidget {
  const EntradaSuave({
    required this.child,
    this.orden = 0,
    this.retraso = Duration.zero,
    this.duracion = AppMovimiento.entrada,
    this.desplazamiento = const Offset(0, AppMovimiento.distancia),
    this.escalaInicial = 1,
    this.id,
    this.animar = true,
    super.key,
  });

  final Widget child;

  /// Escalón de la cascada (0 = primero).
  final int orden;

  /// Espera antes del primer escalón, p. ej. AppMovimiento.trasEmpuje en una
  /// página recién empujada.
  final Duration retraso;

  final Duration duracion;

  /// Desde dónde llega, en dp (máximo 24): `Offset(0, 16)` sube 16 dp y
  /// `Offset(24, 0)` llega desde la derecha.
  final Offset desplazamiento;

  /// Escala con la que empieza (0.85 o más; 1 = sin escala).
  final double escalaInicial;

  /// Dentro de un AmbitoEntradas: la identidad del elemento. Solo anima la
  /// primera vez que el ámbito ve este id y el escalón lo pone el ámbito.
  final Object? id;

  /// En falso aparece ya en su lugar.
  final bool animar;

  @override
  State<EntradaSuave> createState() => _EntradaSuaveState();
}

class _EntradaSuaveState extends State<EntradaSuave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control;
  Animation<double> _opacidad = kAlwaysCompleteAnimation;
  Animation<double> _avance = kAlwaysCompleteAnimation;
  bool _preparada = false;

  @override
  void initState() {
    super.initState();
    _control = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparada) return;
    _preparada = true;
    _preparar();
  }

  // Los parámetros se leen una sola vez, al montar: reconstruir el bloque
  // (provider, recarga, sondeo) nunca repite la entrada.
  void _preparar() {
    var orden = widget.orden;
    var animar = widget.animar && widget.duracion > Duration.zero;
    final id = widget.id;
    if (id != null) {
      final ambito = context
          .getInheritedWidgetOfExactType<_AlcanceEntradas>()
          ?.estado;
      if (ambito != null) {
        final turno = ambito._registrar(id);
        if (turno == null) {
          animar = false;
        } else {
          orden = turno;
        }
      }
    }
    if (!animar || AppMovimiento.reducido(context)) {
      _control.value = 1;
      return;
    }
    final espera = widget.retraso + AppMovimiento.retrasoCascada(orden);
    final total = espera + widget.duracion;
    final inicio = espera.inMicroseconds / total.inMicroseconds;
    _control.duration = total;
    // El fundido termina antes que el movimiento: el bloque ya se lee
    // mientras se asienta.
    _opacidad = _control.drive(
      CurveTween(
        curve: Interval(
          inicio,
          inicio + (1 - inicio) * 0.6,
          curve: Curves.easeOut,
        ),
      ),
    );
    _avance = _control.drive(
      CurveTween(
        curve: Interval(inicio, 1, curve: AppMovimiento.curvaEntrada),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _control.forward().ignore();
    });
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacidad,
      // Los lectores de pantalla ven el bloque desde el primer cuadro.
      alwaysIncludeSemantics: true,
      child: _Llegada(
        avance: _avance,
        desplazamiento: widget.desplazamiento,
        escalaInicial: widget.escalaInicial,
        child: widget.child,
      ),
    );
  }
}

/// Mueve y escala al hijo según el avance (0 = recién llegado, 1 = en su
/// lugar). Solo pinta: no cambia el layout de nadie.
class _Llegada extends AnimatedWidget {
  const _Llegada({
    required Animation<double> avance,
    required this.desplazamiento,
    required this.escalaInicial,
    required this.child,
  }) : super(listenable: avance);

  final Offset desplazamiento;
  final double escalaInicial;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    return Transform.translate(
      offset: desplazamiento * (1 - t),
      child: Transform.scale(
        scale: escalaInicial + (1 - escalaInicial) * t,
        child: child,
      ),
    );
  }
}

/// Lleva la cuenta de qué elementos de una lista ya entraron: cada id anima
/// una sola vez (volver con scroll, recargar o un sondeo no lo repiten) y
/// los que se construyen en un mismo cuadro forman una cascada.
///
/// Los elementos llevan `EntradaSuave(id: ...)` y una Key estable.
class AmbitoEntradas extends StatefulWidget {
  const AmbitoEntradas({
    required this.child,
    this.generacion,
    this.soloPrimeraTanda = true,
    super.key,
  });

  final Widget child;

  /// Cambiarla olvida lo visto (p. ej. un filtro nuevo): los elementos que
  /// se construyan después entran otra vez en cascada. Para que TODO vuelva
  /// a entrar, además se cambia la Key de la lista.
  final Object? generacion;

  /// true: solo anima la primera tanda (lo que aparece al hacer scroll
  /// llega quieto). false: cada cuadro con ids nuevos es otra tanda, útil
  /// para listas que reciben elementos por sondeo.
  final bool soloPrimeraTanda;

  @override
  State<AmbitoEntradas> createState() => _AmbitoEntradasState();
}

class _AmbitoEntradasState extends State<AmbitoEntradas> {
  final Set<Object> _vistos = <Object>{};
  int _turnos = 0;
  bool _tandaAbierta = false;
  bool _huboTanda = false;

  /// Escalón para [id] o null si ya entró (o si ya pasó su tanda).
  int? _registrar(Object id) {
    if (!_vistos.add(id)) return null;
    if (widget.soloPrimeraTanda && _huboTanda && !_tandaAbierta) return null;
    if (!_tandaAbierta) {
      _tandaAbierta = true;
      _turnos = 0;
      // La tanda son los elementos construidos en este cuadro.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tandaAbierta = false;
        _huboTanda = true;
      });
    }
    return _turnos++;
  }

  @override
  void didUpdateWidget(AmbitoEntradas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generacion != widget.generacion) {
      _vistos.clear();
      _huboTanda = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      _AlcanceEntradas(estado: this, child: widget.child);
}

class _AlcanceEntradas extends InheritedWidget {
  const _AlcanceEntradas({required this.estado, required super.child});

  final _AmbitoEntradasState estado;

  @override
  bool updateShouldNotify(_AlcanceEntradas oldWidget) => false;
}
