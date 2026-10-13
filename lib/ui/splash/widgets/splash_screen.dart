// lib/ui/splash/widgets/splash_screen.dart
//
// Splash con coreografía de marca dentro de la misma espera de siempre
// (mínimo 1800 ms + checkSession, luego context.go):
//
//   0–1350 ms  la foto de fondo aparece al decodificarse y se asienta
//              (1.06 → 1); debajo hay un color que, con el velo, es el del
//              arranque nativo (#36402B), así que no hay destello.
//   75–700     el plato del logo crece con un rebote.
//   450–1000   «Pier Repostería» sube y aparece (un solo Text).
//   675–1150   «Dulces momentos» sube y aparece.
//   1500       si la sesión ya está lista: «el plato se abre». El contenido
//              se apaga y el plato crece hasta cubrir la pantalla mientras
//              se vuelve arena; a los 1800 ms context.go entra por el mismo
//              color arena de paginaRaiz, así que el corte no se ve.
//
// Si la sesión tarda, el indicador aparece al final de la entrada y la
// salida espera a la sesión; nunca se retrasa la navegación.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // La entrada dura lo que falta para la salida: 1500 + 300 = 1800 ms, la
  // espera mínima de siempre.
  static const Duration _duracionEntrada = Duration(milliseconds: 1500);
  static const Duration _duracionSalida = AppMovimiento.media;

  // Promedio de la foto de fondo: bajo el velo negro del 40 % da #36402B,
  // el color del arranque nativo (Android e iOS).
  static const Color _colorFoto = Color(0xFF5B6B49);

  // Radio del plato del logo (160 px de diámetro).
  static const double _radioPlato = 80;

  // ── Entrada ──────────────────────────────────────────────────────────
  static final Animatable<double> _escalaFondo = Tween<double>(
    begin: 1.06,
    end: 1,
  ).chain(CurveTween(
      curve: const Interval(0, 0.9, curve: AppMovimiento.curvaEntrada)));
  static final Animatable<double> _opacidadPlato = CurveTween(
    curve: const Interval(0.05, 0.25, curve: Curves.easeOut),
  );
  static final Animatable<double> _escalaPlato = Tween<double>(
    begin: 0.7,
    end: 1,
  ).chain(CurveTween(
      curve: const Interval(0.05, 0.47, curve: AppMovimiento.curvaRebote)));
  static final Animatable<double> _opacidadTitulo = CurveTween(
    curve: const Interval(0.3, 0.55, curve: Curves.easeOut),
  );
  static final Animatable<double> _subidaTitulo = CurveTween(
    curve: const Interval(0.3, 0.67, curve: AppMovimiento.curvaEnfasis),
  );
  static final Animatable<double> _opacidadLema = CurveTween(
    curve: const Interval(0.45, 0.68, curve: Curves.easeOut),
  );
  static final Animatable<double> _subidaLema = CurveTween(
    curve: const Interval(0.45, 0.77, curve: AppMovimiento.curvaEnfasis),
  );
  static final Animatable<double> _opacidadEspera = CurveTween(
    curve: const Interval(0.85, 1, curve: Curves.easeOut),
  );

  // ── Salida («el plato se abre») ──────────────────────────────────────
  static final Animatable<double> _opacidadSalida = Tween<double>(
    begin: 1,
    end: 0,
  ).chain(CurveTween(
      curve: const Interval(0, 0.6, curve: AppMovimiento.curvaSalida)));
  static final Animatable<double> _escalaSalida = Tween<double>(
    begin: 1,
    end: 1.05,
  ).chain(CurveTween(
      curve: const Interval(0, 0.6, curve: AppMovimiento.curvaSalida)));

  late final AnimationController _entrada;
  late final AnimationController _salida;

  // El plato del logo: de su centro sale el círculo de la salida.
  final GlobalKey _llavePlato = GlobalKey();
  final GlobalKey _llaveLienzo = GlobalKey();
  Offset? _centroPlato;

  bool _preparada = false;
  bool _sesionLista = false;

  @override
  void initState() {
    super.initState();
    _entrada = AnimationController(vsync: this, duration: _duracionEntrada)
      ..addStatusListener(_alCambiarEntrada);
    _salida = AnimationController(vsync: this, duration: _duracionSalida);
    unawaited(_checkSession());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparada) return;
    _preparada = true;
    // Con movimiento reducido todo aparece ya en su lugar y no hay salida.
    if (AppMovimiento.reducido(context)) {
      _entrada.value = 1;
    } else {
      _entrada.forward().ignore();
    }
  }

  Future<void> _checkSession() async {
    final minWait =
        Future.delayed(const Duration(milliseconds: 1800));
    final authProvider =
        Provider.of<AuthProvider>(context, listen: false);
    await authProvider.checkSession();
    if (mounted) {
      setState(() => _sesionLista = true);
      _intentarSalida();
    }
    await minWait;
    if (!mounted) return;
    context.go(
      authProvider.isAuthenticated
          ? AppRoutes.homeForRole(authProvider.rol)
          : AppRoutes.main,
    );
  }

  void _alCambiarEntrada(AnimationStatus estado) {
    if (estado == AnimationStatus.completed) _intentarSalida();
  }

  // La salida empieza cuando terminó la entrada y la sesión está lista
  // (lo que pase después). Solo es movimiento: context.go sigue en su
  // momento de siempre.
  void _intentarSalida() {
    if (!mounted ||
        !_sesionLista ||
        !_entrada.isCompleted ||
        _salida.isAnimating ||
        _salida.isCompleted ||
        AppMovimiento.reducido(context)) {
      return;
    }
    setState(() => _centroPlato = _medirCentroPlato());
    _salida.forward().ignore();
  }

  Offset? _medirCentroPlato() {
    final plato = _llavePlato.currentContext?.findRenderObject();
    final lienzo = _llaveLienzo.currentContext?.findRenderObject();
    if (plato is! RenderBox || lienzo is! RenderBox) return null;
    if (!plato.hasSize || !lienzo.hasSize) return null;
    return lienzo.globalToLocal(
      plato.localToGlobal(plato.size.center(Offset.zero)),
    );
  }

  @override
  void dispose() {
    _entrada.dispose();
    _salida.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    // El logo se dibuja a 100 px: se decodifica a ese tamaño.
    final anchoLogo = (100 * MediaQuery.devicePixelRatioOf(context)).round();
    return Scaffold(
      body: Stack(
        key: _llaveLienzo,
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: _colorFoto),
          ScaleTransition(
            scale: _entrada.drive(_escalaFondo),
            child: RepaintBoundary(
              child: Image.asset(
                'assets/images/fondo_splash_verde_pier.png',
                fit: BoxFit.cover,
                // La foto (2.7 MB) aparece al decodificarse: ya no «salta».
                frameBuilder: (context, foto, cuadro, sincrona) => sincrona
                    ? foto
                    : AnimatedOpacity(
                        opacity: cuadro == null ? 0 : 1,
                        duration: AppMovimiento.duracion(
                            context, AppMovimiento.media),
                        curve: AppMovimiento.curvaEntrada,
                        child: foto,
                      ),
                errorBuilder: (_, _, _) =>
                    Container(color: AppColors.pierVerde),
              ),
            ),
          ),
          Container(
            color: Colors.black.withValues(alpha: 0.4),
          ),
          // El plato que se abre: solo pinta durante la salida, debajo del
          // contenido (que se apaga encima de él), en su propia capa.
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _PlatoQueSeAbre(
                  salida: _salida,
                  centro: _centroPlato,
                  radioInicial: _radioPlato,
                  arena: AppColors.pierArena,
                ),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _salida.drive(_opacidadSalida),
              child: ScaleTransition(
                scale: _salida.drive(_escalaSalida),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeTransition(
                      opacity: _entrada.drive(_opacidadPlato),
                      child: ScaleTransition(
                        scale: _entrada.drive(_escalaPlato),
                        child: Container(
                          key: _llavePlato,
                          width: 160, height: 160,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: 0.25),
                                blurRadius: 30,
                                spreadRadius: 5,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Padding(
                              padding: const EdgeInsets.all(30),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                                cacheWidth: anchoLogo,
                                errorBuilder: (_, _, _) => Icon(
                                    LucideIcons.cake,
                                    size: 60,
                                    color: AppColors.pierVerde),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 35),
                    FadeTransition(
                      opacity: _entrada.drive(_opacidadTitulo),
                      child: _Subida(
                        avance: _entrada.drive(_subidaTitulo),
                        distancia: 14,
                        child: const Text(
                          'Pier Repostería',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Playfair Display',
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black45,
                                offset: Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeTransition(
                      opacity: _entrada.drive(_opacidadLema),
                      child: _Subida(
                        avance: _entrada.drive(_subidaLema),
                        distancia: AppMovimiento.distanciaCorta,
                        child: Text(
                          'Dulces momentos',
                          style: TextStyle(
                            fontSize: 20,
                            color: AppColors.pierDorado,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            shadows: const [
                              Shadow(
                                color: Colors.black45,
                                offset: Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 60),
                    // El indicador solo se asoma si la sesión tarda más que
                    // la entrada; si ya está lista, nunca destella. Gira sin
                    // fin: en su propia capa para no repintar el logo y los
                    // textos (con sombras) en cada cuadro.
                    AnimatedOpacity(
                      opacity: _sesionLista ? 0 : 1,
                      duration: AppMovimiento.duracion(
                          context, AppMovimiento.rapida),
                      child: FadeTransition(
                        opacity: _entrada.drive(_opacidadEspera),
                        child: const RepaintBoundary(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sube al hijo [distancia] dp hasta su lugar según el avance (0 → 1).
class _Subida extends AnimatedWidget {
  const _Subida({
    required Animation<double> avance,
    required this.distancia,
    required this.child,
  }) : super(listenable: avance);

  final double distancia;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    return Transform.translate(
      offset: Offset(0, distancia * (1 - t)),
      child: child,
    );
  }
}

/// «El plato se abre»: un círculo blanco del tamaño del plato del logo que
/// crece hasta cubrir la pantalla mientras se vuelve arena. Solo pinta con
/// la salida en marcha.
class _PlatoQueSeAbre extends CustomPainter {
  _PlatoQueSeAbre({
    required this.salida,
    required this.centro,
    required this.radioInicial,
    required this.arena,
  }) : super(repaint: salida);

  final Animation<double> salida;
  final Offset? centro;
  final double radioInicial;
  final Color arena;

  // Crece acelerando (al final cubre la pantalla de golpe) y se vuelve
  // arena mientras crece.
  static const Curve _crecer =
      Interval(0.25, 1, curve: AppMovimiento.curvaSalida);
  static const Curve _aArena = Interval(0.25, 0.9, curve: Curves.easeIn);

  @override
  void paint(Canvas canvas, Size size) {
    final t = salida.value;
    if (t == 0) return;
    final c = centro ?? size.center(Offset.zero);
    final esquinas = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    final lejano = esquinas.map((e) => (e - c).distance).reduce(math.max);
    final radio = lerpDouble(radioInicial, lejano, _crecer.transform(t))!;
    final color = Color.lerp(Colors.white, arena, _aArena.transform(t))!;
    canvas.drawCircle(c, radio, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PlatoQueSeAbre oldDelegate) =>
      oldDelegate.salida != salida ||
      oldDelegate.centro != centro ||
      oldDelegate.radioInicial != radioInicial ||
      oldDelegate.arena != arena;
}
