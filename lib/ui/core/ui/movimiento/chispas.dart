// lib/ui/core/ui/movimiento/chispas.dart
//
// Chispas de repostería: una sola ráfaga de chispitas (rectángulos
// redondeados, como las de chocolate) y unos cuantos chochitos que salen
// hacia arriba en abanico, caen con gravedad y se desvanecen. Los colores
// salen de la paleta de temporada ACTIVA. Pintadas con un CustomPainter
// (nunca widgets Icon ni Text), tras un IgnorePointer y un RepaintBoundary.
// Nunca se repite: para otra ráfaga, se monta otra (Key nueva). Con
// movimiento reducido no aparece.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/themes/app_movimiento.dart';

/// Ráfaga de chispas. Va encima del contenido, normalmente como
/// `Positioned.fill(child: Chispas())` dentro de un Stack: ocupa todo el
/// espacio que le den y nunca recibe toques.
class Chispas extends StatefulWidget {
  const Chispas({
    this.cantidad = 40,
    this.origen = const Alignment(0, -0.3),
    this.retraso = Duration.zero,
    this.duracion = AppMovimiento.celebracion,
    this.semilla = 7,
    super.key,
  });

  final int cantidad;

  /// De dónde salen, dentro del espacio que ocupa.
  final Alignment origen;

  /// Espera antes de la ráfaga, contada DENTRO de [duracion].
  final Duration retraso;

  /// Duración total (máximo AppMovimiento.celebracion).
  final Duration duracion;

  /// Misma semilla, misma ráfaga (útil en pruebas y para no variar entre
  /// reconstrucciones).
  final int semilla;

  @override
  State<Chispas> createState() => _ChispasState();
}

class _ChispasState extends State<Chispas> with SingleTickerProviderStateMixin {
  late final AnimationController _control;
  late final List<_Chispa> _chispas;
  bool _iniciada = false;

  @override
  void initState() {
    super.initState();
    _control = AnimationController(vsync: this, duration: widget.duracion);
    _chispas = _generar(widget.cantidad, math.Random(widget.semilla));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciada) return;
    _iniciada = true;
    if (AppMovimiento.reducido(context)) return;
    // Desde un post-frame: en una ruta aún tapada espera a verse.
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
    final total = widget.duracion.inMicroseconds;
    final inicio = total == 0
        ? 0.0
        : (widget.retraso.inMicroseconds / total).clamp(0.0, 0.9);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _PintorChispas(
              avance: _control,
              chispas: _chispas,
              inicio: inicio,
              vida:
                  widget.duracion.inMicroseconds /
                  Duration.microsecondsPerSecond,
              origen: widget.origen,
              // Paleta de temporada leída en cada build: sigue al tema.
              colores: <Color>[
                AppColors.pierVerde,
                AppColors.pierVerdeClaro,
                AppColors.pierDorado,
                AppColors.pierDoradoClaro,
                AppColors.pierDoradoOscuro,
                AppColors.pierArenaOscuro,
              ],
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// Una chispa: hacia dónde sale, qué tan rápido, cómo gira y cómo se ve.
class _Chispa {
  const _Chispa({
    required this.angulo,
    required this.rapidez,
    required this.giro,
    required this.desfase,
    required this.color,
    required this.punto,
  });

  final double angulo;
  final double rapidez;
  final double giro;

  /// Fracción de la vida en que sale (las chispas no salen todas juntas).
  final double desfase;
  final int color;

  /// true: chochito (círculo); false: chispita (rectángulo redondeado).
  final bool punto;
}

List<_Chispa> _generar(int cantidad, math.Random azar) {
  return List<_Chispa>.generate(cantidad, (i) {
    // Abanico hacia arriba: −90° ± 70°.
    final angulo = -math.pi / 2 + (azar.nextDouble() * 2 - 1) * 1.22;
    return _Chispa(
      angulo: angulo,
      rapidez: 260 + azar.nextDouble() * 300,
      giro: (azar.nextDouble() * 2 - 1) * 12,
      desfase: azar.nextDouble() * 0.08,
      color: azar.nextInt(6),
      punto: i % 4 == 0,
    );
  });
}

class _PintorChispas extends CustomPainter {
  _PintorChispas({
    required this.avance,
    required this.chispas,
    required this.inicio,
    required this.vida,
    required this.origen,
    required this.colores,
  }) : super(repaint: avance);

  static const double _gravedad = 600;
  static const double _arrastre = 1.6;

  final Animation<double> avance;
  final List<_Chispa> chispas;

  /// Fracción del total en que sale la ráfaga.
  final double inicio;

  /// Duración total en segundos.
  final double vida;
  final Alignment origen;
  final List<Color> colores;

  @override
  void paint(Canvas canvas, Size size) {
    final t = avance.value;
    if (t <= inicio || t >= 1) return;
    final centro = origen.alongSize(size);
    final pincel = Paint();
    for (final chispa in chispas) {
      final salida = inicio + chispa.desfase * (1 - inicio);
      if (t <= salida) continue;
      // Avance propio de la chispa (0..1) y segundos desde que salió.
      final propio = (t - salida) / (1 - salida);
      final segundos = (t - salida) * vida;
      // Velocidad amortiguada (arrastre) más gravedad.
      final freno = (1 - math.exp(-_arrastre * segundos)) / _arrastre;
      final x = math.cos(chispa.angulo) * chispa.rapidez * freno;
      final y =
          math.sin(chispa.angulo) * chispa.rapidez * freno +
          0.5 * _gravedad * segundos * segundos;
      // Se desvanece en el último 30 % de su vida.
      final alfa = propio < 0.7 ? 1.0 : (1 - propio) / 0.3;
      pincel.color = colores[chispa.color % colores.length].withValues(
        alpha: alfa,
      );
      canvas
        ..save()
        ..translate(centro.dx + x, centro.dy + y)
        ..rotate(chispa.angulo + chispa.giro * segundos);
      if (chispa.punto) {
        canvas.drawCircle(Offset.zero, 2.4, pincel);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-1.4, -4.6, 2.8, 9.2),
            const Radius.circular(1.4),
          ),
          pincel,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PintorChispas oldDelegate) =>
      oldDelegate.chispas != chispas ||
      oldDelegate.inicio != inicio ||
      oldDelegate.origen != origen ||
      !_mismosColores(oldDelegate.colores, colores);

  static bool _mismosColores(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
