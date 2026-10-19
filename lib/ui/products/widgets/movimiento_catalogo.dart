// lib/ui/products/widgets/movimiento_catalogo.dart
//
// Piezas de movimiento propias del catálogo y del detalle de producto. Las
// generales (entradas, Hero de la foto, vuelo al carrito, destellos…) viven
// en lib/ui/core/ui/movimiento; aquí solo lo que comparten las pantallas de
// esta carpeta. Todas respetan «reducir movimiento», terminan solas y no usan
// Timers.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';

/// Texto cuyo estilo (color, grosor) pasa al nuevo con un fundido corto en
/// lugar de saltar: en un chip o una tarjeta que cambia de fondo, el texto
/// cambia junto con el fondo (antes el texto blanco aparecía sobre la tarjeta
/// todavía blanca). Lo demás lo hereda del DefaultTextStyle, igual que un
/// Text con `style`.
class TextoEstiloAnimado extends StatelessWidget {
  const TextoEstiloAnimado(this.texto, {required this.estilo, super.key});

  final String texto;
  final TextStyle estilo;

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      style: DefaultTextStyle.of(context).style.merge(estilo),
      duration: AppMovimiento.duracion(context, AppMovimiento.corta),
      curve: AppMovimiento.curvaEstandar,
      child: Text(texto),
    );
  }
}

/// Ícono cuyo color pasa al nuevo con un fundido corto, junto con el fondo
/// del chip o del botón donde está.
class IconoColorAnimado extends StatelessWidget {
  const IconoColorAnimado(
    this.icono, {
    required this.color,
    required this.tamano,
    super.key,
  });

  final IconData icono;
  final Color color;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: color),
      duration: AppMovimiento.duracion(context, AppMovimiento.corta),
      curve: AppMovimiento.curvaEstandar,
      builder: (_, actual, _) => Icon(icono, color: actual, size: tamano),
    );
  }
}

/// Lo que devuelve el `frameBuilder` de una foto de red: la que llega de
/// internet aparece con un fundido corto en vez de saltar; la que ya estaba
/// en caché (volver con scroll, regresar del detalle) se pinta tal cual desde
/// el primer cuadro.
///
/// ```dart
/// frameBuilder: (_, foto, cuadro, sincrona) =>
///     AparicionFoto(foto: foto, cuadro: cuadro, sincrona: sincrona),
/// ```
class AparicionFoto extends StatelessWidget {
  const AparicionFoto({
    required this.foto,
    required this.cuadro,
    required this.sincrona,
    super.key,
  });

  final Widget foto;

  /// Cuadro ya decodificado (null mientras la foto no llega).
  final int? cuadro;

  /// Si la foto salió de la caché en el mismo cuadro.
  final bool sincrona;

  @override
  Widget build(BuildContext context) {
    if (sincrona) return foto;
    return AnimatedOpacity(
      opacity: cuadro == null ? 0 : 1,
      duration: AppMovimiento.duracion(context, AppMovimiento.corta),
      curve: AppMovimiento.curvaEntrada,
      child: foto,
    );
  }
}

/// Un número que rueda como contador al cambiar, dentro de su propia
/// ventanita: si sube, el nuevo entra desde abajo y el anterior se va hacia
/// arriba; si baja, al revés. Nunca anima al montarse y el texto final es
/// exactamente [texto].
class CifraRodante extends StatefulWidget {
  const CifraRodante({
    required this.valor,
    required this.texto,
    this.estilo,
    super.key,
  });

  /// El número que se muestra (decide si rueda hacia arriba o hacia abajo).
  final num valor;

  /// Cómo se muestra, p. ej. r'$270.00'.
  final String texto;

  final TextStyle? estilo;

  @override
  State<CifraRodante> createState() => _CifraRodanteState();
}

class _CifraRodanteState extends State<CifraRodante> {
  int _direccion = 1;

  @override
  void didUpdateWidget(CifraRodante oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.valor != oldWidget.valor) {
      _direccion = widget.valor > oldWidget.valor ? 1 : -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    // El recorte hace de ventanita del contador: el dígito que entra y el
    // que sale no se pintan fuera de la línea del texto.
    return ClipRect(
      child: CambioAnimado(
        tipo: TipoCambio.subir,
        direccion: _direccion,
        child: Text(
          widget.texto,
          key: ValueKey<String>(widget.texto),
          style: widget.estilo,
        ),
      ),
    );
  }
}

/// AnimatedSize con el ritmo de la casa: lo que crece o se encoge empuja a lo
/// de alrededor con suavidad en vez de saltar. Con movimiento reducido el
/// cambio es inmediato (un milisegundo: AnimatedSize no acepta duración cero).
class TamanoAnimado extends StatelessWidget {
  const TamanoAnimado({
    required this.child,
    this.alineacion = AlignmentDirectional.topStart,
    this.duracion = AppMovimiento.corta,
    super.key,
  });

  final Widget child;
  final AlignmentGeometry alineacion;
  final Duration duracion;

  static const Duration _instante = Duration(milliseconds: 1);

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMovimiento.reducido(context) ? _instante : duracion,
      curve: AppMovimiento.curvaEstandar,
      alignment: alineacion,
      child: child,
    );
  }
}

/// Vaivén de campana (en vueltas, para un RotationTransition): tres
/// oscilaciones que se apagan; empieza y termina en 0.
class Vaiven extends Animatable<double> {
  const Vaiven({this.amplitud = 0.04});

  /// Giro máximo en vueltas (0.04 ≈ 14°).
  final double amplitud;

  @override
  double transform(double t) => math.sin(t * math.pi * 6) * (1 - t) * amplitud;
}

/// Un solo destello de luz que cruza una insignia (la de las ofertas
/// relámpago): llama la atención sobre una oferta con tiempo sin quedarse en
/// bucle. Pinta encima del hijo, recortado a sus esquinas, y espera [retraso]
/// desde el primer cuadro en que la insignia se ve (en una pestaña oculta no
/// empieza a contar). Con movimiento reducido no hay destello.
class BrilloUnaVez extends StatefulWidget {
  const BrilloUnaVez({
    required this.child,
    required this.radio,
    this.retraso = Duration.zero,
    super.key,
  });

  final Widget child;

  /// Esquinas de la insignia (el destello no se sale de ellas).
  final BorderRadius radio;

  final Duration retraso;

  @override
  State<BrilloUnaVez> createState() => _BrilloUnaVezState();
}

class _BrilloUnaVezState extends State<BrilloUnaVez>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control;
  double _inicio = 0;
  bool _preparado = false;

  @override
  void initState() {
    super.initState();
    _control = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparado) return;
    _preparado = true;
    if (AppMovimiento.reducido(context)) return;
    final total = widget.retraso + AppMovimiento.relleno;
    _inicio = widget.retraso.inMicroseconds / total.inMicroseconds;
    _control.duration = total;
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
    return RepaintBoundary(
      child: CustomPaint(
        foregroundPainter: _PintorBrillo(
          avance: _control,
          inicio: _inicio,
          radio: widget.radio,
        ),
        child: widget.child,
      ),
    );
  }
}

class _PintorBrillo extends CustomPainter {
  _PintorBrillo({
    required this.avance,
    required this.inicio,
    required this.radio,
  }) : super(repaint: avance);

  final Animation<double> avance;
  final double inicio;
  final BorderRadius radio;

  @override
  void paint(Canvas canvas, Size size) {
    final valor = avance.value;
    if (valor <= inicio || valor >= 1 || size.isEmpty) return;
    final t = Curves.easeInOut.transform((valor - inicio) / (1 - inicio));
    // Una franja inclinada que cruza de izquierda a derecha.
    final ancho = math.max(size.height * 1.6, 14).toDouble();
    final x = -ancho + (size.width + ancho * 2) * t;
    final franja = Rect.fromLTWH(x - ancho, 0, ancho * 2, size.height);
    canvas
      ..save()
      ..clipRRect(radio.toRRect(Offset.zero & size))
      ..drawRect(
        franja,
        Paint()
          ..shader = LinearGradient(
            begin: const Alignment(-1, -0.4),
            end: const Alignment(1, 0.4),
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.55),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(franja),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_PintorBrillo oldDelegate) =>
      oldDelegate.inicio != inicio || oldDelegate.radio != radio;
}
