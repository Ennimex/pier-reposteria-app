// lib/ui/core/ui/movimiento/cambio_animado.dart
//
// Cambio de contenido en sitio (un texto, un ícono, un estado): el anterior
// sale y el nuevo entra con la variante elegida. Es un AnimatedSwitcher con
// dos trampas resueltas: el transitionBuilder propaga la Key del hijo (sin
// eso, A → B → A duplica hijos) y el layout alinea al inicio (el de fábrica
// centra y hace saltar los textos).
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/ui/core/themes/app_movimiento.dart';

/// Variantes de CambioAnimado.
enum TipoCambio {
  /// Fundido cruzado.
  fundido,

  /// El nuevo sube 8 dp mientras aparece (odómetro). Con `direccion: -1`
  /// baja.
  subir,

  /// El nuevo crece desde 0.6 con un rebote: cambios de ícono.
  escalar,

  /// Eje compartido X: el nuevo llega 24 dp desde el lado de `direccion` y
  /// el anterior se va hacia el otro.
  ejeX,

  /// Fundido a través: el anterior se apaga rápido y luego aparece el nuevo
  /// con una escala corta.
  atravesar,
}

class CambioAnimado extends StatelessWidget {
  const CambioAnimado({
    required this.child,
    this.tipo = TipoCambio.fundido,
    this.duracion = AppMovimiento.corta,
    this.alineacion = AlignmentDirectional.centerStart,
    this.direccion = 1,
    this.soloEntrada = false,
    super.key,
  });

  /// El contenido. Debe llevar una Key que cambie con él, p. ej.
  /// `Text(total, key: ValueKey(total))`.
  final Widget child;

  final TipoCambio tipo;
  final Duration duracion;
  final AlignmentGeometry alineacion;

  /// 1 = adelante (o hacia arriba), -1 = atrás (o hacia abajo).
  final int direccion;

  /// true: el anterior sale del árbol en el mismo cuadro y solo se anima la
  /// entrada (para cuando una prueba espera que el viejo ya no exista).
  final bool soloEntrada;

  static final Animatable<double> _entradaTardia = CurveTween(
    curve: const Interval(0.3, 1, curve: Curves.easeOut),
  );
  static final Animatable<double> _escalaRebote = Tween<double>(
    begin: 0.6,
    end: 1,
  ).chain(CurveTween(curve: AppMovimiento.curvaRebote));
  static final Animatable<double> _escalaSalida = Tween<double>(
    begin: 0.8,
    end: 1,
  );
  static final Animatable<double> _escalaAtravesar = Tween<double>(
    begin: 0.96,
    end: 1,
  ).chain(CurveTween(curve: AppMovimiento.curvaEnfasis));

  @override
  Widget build(BuildContext context) {
    // Con movimiento reducido toda variante es un fundido (mismo árbol).
    final variante = AppMovimiento.reducido(context)
        ? TipoCambio.fundido
        : tipo;
    final salida = variante == TipoCambio.atravesar
        ? duracion * 0.35
        : duracion * 0.6;
    final actual = child.key;
    return AnimatedSwitcher(
      duration: duracion,
      reverseDuration: salida,
      layoutBuilder: (hijoActual, anteriores) => Stack(
        alignment: alineacion,
        children: [
          if (!soloEntrada) ...anteriores,
          ?hijoActual,
        ],
      ),
      transitionBuilder: (hijo, animacion) => KeyedSubtree(
        key: ValueKey<Key?>(hijo.key),
        child: _transicion(
          variante,
          hijo,
          animacion,
          entra: hijo.key == actual,
        ),
      ),
      child: child,
    );
  }

  // `animacion` va de 0 a 1 al entrar y de 1 a 0 al salir: cada variante
  // describe su estado inicial (entra) o final (sale) y llega a reposo en 1.
  Widget _transicion(
    TipoCambio variante,
    Widget hijo,
    Animation<double> animacion, {
    required bool entra,
  }) {
    switch (variante) {
      case TipoCambio.fundido:
        return FadeTransition(opacity: animacion, child: hijo);
      case TipoCambio.subir:
        final dy = AppMovimiento.distanciaCorta * direccion;
        return FadeTransition(
          opacity: animacion,
          child: _Desplazado(
            animacion: animacion,
            desde: Offset(0, entra ? dy : -dy),
            child: hijo,
          ),
        );
      case TipoCambio.escalar:
        return FadeTransition(
          opacity: animacion,
          child: ScaleTransition(
            scale: animacion.drive(entra ? _escalaRebote : _escalaSalida),
            child: hijo,
          ),
        );
      case TipoCambio.ejeX:
        final dx = AppMovimiento.distanciaLarga * direccion;
        return FadeTransition(
          opacity: entra ? animacion.drive(_entradaTardia) : animacion,
          child: _Desplazado(
            animacion: animacion,
            desde: Offset(entra ? dx : -dx, 0),
            child: hijo,
          ),
        );
      case TipoCambio.atravesar:
        return FadeTransition(
          opacity: entra ? animacion.drive(_entradaTardia) : animacion,
          child: ScaleTransition(
            scale: entra
                ? animacion.drive(_escalaAtravesar)
                : kAlwaysCompleteAnimation,
            child: hijo,
          ),
        );
    }
  }
}

/// Desplaza al hijo desde [desde] (en dp) hasta su lugar según la animación.
class _Desplazado extends AnimatedWidget {
  const _Desplazado({
    required Animation<double> animacion,
    required this.desde,
    required this.child,
  }) : super(listenable: animacion);

  final Offset desde;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = AppMovimiento.curvaEnfasis.transform(
      (listenable as Animation<double>).value,
    );
    return Transform.translate(offset: desde * (1 - t), child: child);
  }
}
