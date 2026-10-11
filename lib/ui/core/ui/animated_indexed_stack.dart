// lib/ui/core/ui/animated_indexed_stack.dart
//
// Pila de pestañas con transición de dos capas (eje compartido X): la
// pestaña que sale se desvanece y se corre hacia un lado mientras la que
// entra aparece deslizándose desde el contrario (derecha si vas a un índice
// mayor, izquierda si vas a uno menor). Todo en 300 ms.
//
// A diferencia de AnimatedSwitcher/PageView, todas las pestañas siguen
// montadas en el mismo orden y con los mismos envoltorios, como en un
// IndexedStack: NO se reconstruyen al cambiar (mantienen su estado, sus
// Navigators anidados y no re-disparan fetches). Las que no están en escena
// quedan Offstage (no se pintan, no reciben toques y los finders de las
// pruebas no las ven), con sus tickers pausados (TickerMode: el Lottie del
// carrito o un shimmer oculto no gastan batería y las entradas de una
// pestaña se ven la primera vez que se abre) y sin Hero (HeroMode: nada de
// etiquetas repetidas entre pestañas).
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/ui/core/themes/app_movimiento.dart';

class AnimatedIndexedStack extends StatefulWidget {
  const AnimatedIndexedStack({
    required this.index,
    required this.children,
    super.key,
    this.duration = AppMovimiento.media,
    this.onSwipeToIndex,
  });

  final int index;
  final List<Widget> children;
  final Duration duration;

  /// Si se define, deslizar horizontalmente (fling) pide cambiar de pestaña:
  /// hacia la izquierda = índice siguiente, hacia la derecha = anterior (ya
  /// acotado a los límites; el padre solo actualiza su índice). Los scrolls
  /// horizontales internos (carruseles, listas de productos) ganan el gesto
  /// donde existan, igual que en cualquier app.
  final ValueChanged<int>? onSwipeToIndex;

  @override
  State<AnimatedIndexedStack> createState() => _AnimatedIndexedStackState();
}

class _AnimatedIndexedStackState extends State<AnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  // La que sale se apaga en el primer 35 % (fundido lineal: así se puede
  // retomar exacto si el usuario cambia otra vez a media transición) y la
  // que entra aparece desde el 30 %: nunca hay dos capas a media opacidad.
  static const double _finSalida = 0.35;
  static final Animatable<double> _opacidadSale = Tween<double>(
    begin: 1,
    end: 0,
  ).chain(CurveTween(curve: const Interval(0, _finSalida)));
  static final Animatable<double> _opacidadEntra = CurveTween(
    curve: const Interval(0.3, 1, curve: Curves.easeOut),
  );
  static final Animatable<double> _avanceSale = CurveTween(
    curve: const Interval(0, _finSalida, curve: Easing.emphasizedAccelerate),
  );
  static final Animatable<double> _avanceEntra = CurveTween(
    curve: const Interval(0.3, 1, curve: AppMovimiento.curvaEnfasis),
  );

  late final AnimationController _controller;
  late final Animation<double> _sale;
  late final Animation<double> _entra;
  late final Animation<double> _derivaSale;
  late final Animation<double> _derivaEntra;

  // Pestaña que se está yendo (null fuera de una transición) y sentido del
  // cambio: 1 hacia un índice mayor, -1 hacia uno menor.
  int? _saliente;
  int _direccion = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1, // sin animación en el primer build
    )..addStatusListener(_alCambiarEstado);
    _sale = _controller.drive(_opacidadSale);
    _entra = _controller.drive(_opacidadEntra);
    _derivaSale = _controller.drive(_avanceSale);
    _derivaEntra = _controller.drive(_avanceEntra);
  }

  @override
  void didUpdateWidget(AnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (_saliente != null && _saliente! >= widget.children.length) {
      _saliente = null;
    }
    if (oldWidget.index == widget.index) return;
    if (AppMovimiento.reducido(context)) {
      // Movimiento reducido: cambio instantáneo.
      _saliente = null;
      _controller.value = 1;
      return;
    }
    // Si cambia a media transición, la pestaña que venía entrando sale
    // desde la opacidad que ya tenía (sin parpadeo).
    final opacidadActual = _controller.isAnimating ? _entra.value : 1.0;
    _saliente = oldWidget.index;
    _direccion = widget.index > oldWidget.index ? 1 : -1;
    _controller.forward(from: _finSalida * (1 - opacidadActual)).ignore();
  }

  // La saliente queda fuera de escena en el mismo cuadro en que termina la
  // transición (las pruebas del repartidor revisan a los 400 ms).
  void _alCambiarEstado(AnimationStatus estado) {
    if (estado == AnimationStatus.completed && _saliente != null) {
      setState(() => _saliente = null);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragEnd(DragEndDetails d) {
    final vx = d.primaryVelocity ?? 0;
    if (vx.abs() < 300) return; // umbral: solo flings claros, no roces
    final destino = vx < 0 ? widget.index + 1 : widget.index - 1;
    if (destino < 0 || destino >= widget.children.length) return;
    widget.onSwipeToIndex!(destino);
  }

  @override
  Widget build(BuildContext context) {
    // En dp; con texto de derecha a izquierda el sentido se voltea.
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    final distancia =
        AppMovimiento.distanciaLarga * _direccion * (rtl ? -1 : 1);
    // Mismo layout que IndexedStack: arriba-inicio, tamaño suelto y recorte.
    final contenido = Stack(
      children: [
        for (var i = 0; i < widget.children.length; i++)
          if (i == widget.index)
            _CapaPestana(
              enEscena: true,
              activa: true,
              opacidad: _entra,
              avance: _derivaEntra,
              desde: distancia,
              hasta: 0,
              child: widget.children[i],
            )
          else if (i == _saliente)
            _CapaPestana(
              enEscena: true,
              activa: false,
              opacidad: _sale,
              avance: _derivaSale,
              desde: 0,
              hasta: -distancia,
              child: widget.children[i],
            )
          else
            _CapaPestana(
              enEscena: false,
              activa: false,
              opacidad: kAlwaysCompleteAnimation,
              avance: kAlwaysCompleteAnimation,
              desde: 0,
              hasta: 0,
              child: widget.children[i],
            ),
      ],
    );
    if (widget.onSwipeToIndex == null) return contenido;
    return GestureDetector(
      onHorizontalDragEnd: _onDragEnd,
      child: contenido,
    );
  }
}

/// Envoltorios de una pestaña. Son SIEMPRE los mismos tipos en el mismo
/// orden (sea la actual, la saliente o una oculta): así nada se remonta y
/// los Navigators anidados conservan su estado.
class _CapaPestana extends StatelessWidget {
  const _CapaPestana({
    required this.enEscena,
    required this.activa,
    required this.opacidad,
    required this.avance,
    required this.desde,
    required this.hasta,
    required this.child,
  });

  /// Se pinta: la actual o la que está saliendo.
  final bool enEscena;

  /// La actual: recibe toques y foco, y sus Hero pueden volar.
  final bool activa;

  final Animation<double> opacidad;
  final Animation<double> avance;

  /// Desplazamiento horizontal (dp) al empezar y al terminar.
  final double desde;
  final double hasta;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: !enEscena,
      child: ExcludeFocus(
        // Como en IndexedStack: solo la pestaña actual conserva el foco.
        excluding: !activa,
        child: Visibility(
          // Mismas banderas que IndexedStack (Visibility.of sigue igual);
          // el foco lo decide el ExcludeFocus de arriba.
          visible: enEscena,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          maintainInteractivity: true,
          maintainFocusability: true,
          child: TickerMode(
            enabled: enEscena,
            child: HeroMode(
              enabled: activa,
              // La que sale no recibe toques ni la leen los lectores de
              // pantalla durante su fundido.
              child: IgnorePointer(
                ignoring: !activa,
                child: ExcludeSemantics(
                  excluding: !activa,
                  child: FadeTransition(
                    opacity: opacidad,
                    child: _Deriva(
                      avance: avance,
                      desde: desde,
                      hasta: hasta,
                      child: RepaintBoundary(child: child),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Corre la pestaña en X según el avance: solo pinta, no cambia su layout.
class _Deriva extends AnimatedWidget {
  const _Deriva({
    required Animation<double> avance,
    required this.desde,
    required this.hasta,
    required this.child,
  }) : super(listenable: avance);

  final double desde;
  final double hasta;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    final dx = desde + (hasta - desde) * t;
    return Transform.translate(offset: Offset(dx, 0), child: child);
  }
}
