// lib/ui/core/ui/movimiento/vuelo_al_carrito.dart
//
// «Vuelo al carrito»: al agregar un producto, una miniatura redonda de su
// foto sale del botón (o de la foto) y vuela en arco hasta el ícono del
// carrito de la barra inferior, encogiéndose y desvaneciéndose al final; al
// llegar, el ícono da un pequeño trago.
//
// MainScreen instala el ámbito (VueloAlCarrito) alrededor de su Scaffold y
// marca el ícono con DestinoVuelo. El vuelo va en el Overlay RAÍZ: el de la
// pestaña se recorta arriba de la barra. Sin ámbito (pruebas sueltas), sin
// destino visible o con movimiento reducido, lanzar no hace nada. Nunca toca
// la lógica del carrito ni sus mensajes: es solo decoración.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/themes/app_movimiento.dart';

class VueloAlCarrito extends StatefulWidget {
  const VueloAlCarrito({required this.child, super.key});

  final Widget child;

  /// Lanza la miniatura de [imagenUrl] hacia el carrito.
  ///
  /// Sale de [desde] (en coordenadas globales) si se da; si no, del widget
  /// con la Key [origen]; si no, del rectángulo de `context`. Lo normal es
  /// el botón que se tocó: su `context`, u [origen] si el manejador solo
  /// tiene el de la pantalla. Una pantalla que se cierra al agregar (el
  /// detalle) la lanza desde el botón, nunca desde la foto: la foto ya
  /// regresa a su tarjeta con su Hero. La foto sirve de [origen] solo si la
  /// pantalla se queda y la foto está a la vista.
  ///
  /// Se llama desde el manejador del toque, en el mismo bloque que el alta
  /// del producto (si el alta espera al backend, justo después del await):
  /// así la insignia del carrito no se adelanta a la miniatura. No espera
  /// ni devuelve nada; con `context` ya desmontado no hace nada.
  static void lanzar(
    BuildContext context, {
    required String imagenUrl,
    GlobalKey? origen,
    Rect? desde,
  }) {
    if (!context.mounted) return;
    final ambito = context.findAncestorStateOfType<_VueloAlCarritoState>();
    if (ambito == null || AppMovimiento.reducido(ambito.context)) return;
    final inicio = desde ?? _rectGlobal(origen?.currentContext ?? context);
    if (inicio == null) return;
    ambito._lanzar(inicio, imagenUrl);
  }

  @override
  State<VueloAlCarrito> createState() => _VueloAlCarritoState();
}

Rect? _rectGlobal(BuildContext contexto) {
  final caja = contexto.findRenderObject();
  if (caja is! RenderBox || !caja.attached || !caja.hasSize) return null;
  return caja.localToGlobal(Offset.zero) & caja.size;
}

class _VueloAlCarritoState extends State<VueloAlCarrito> {
  static const int _vuelosMaximos = 3;

  final List<_DestinoVueloState> _destinos = <_DestinoVueloState>[];
  final List<OverlayEntry> _vuelos = <OverlayEntry>[];
  final ValueNotifier<int> _llegadas = ValueNotifier<int>(0);

  // Miniaturas en el aire (lo que ve DestinoVuelo.enCamino).
  final ValueNotifier<int> _enCamino = ValueNotifier<int>(0);

  void _registrar(_DestinoVueloState destino) => _destinos.add(destino);

  void _quitar(_DestinoVueloState destino) => _destinos.remove(destino);

  void _lanzar(Rect desde, String imagenUrl) {
    if (_vuelos.length >= _vuelosMaximos) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final cajaOverlay = overlay?.context.findRenderObject();
    if (overlay == null || cajaOverlay is! RenderBox || !cajaOverlay.hasSize) {
      return;
    }
    // El destino es el ícono del carrito que esté montado (el normal o el
    // activo: la barra solo construye uno a la vez).
    Rect? hasta;
    for (final destino in _destinos.reversed) {
      hasta = _rectGlobal(destino.context);
      if (hasta != null) break;
    }
    if (hasta == null) return;

    final inicio = cajaOverlay.globalToLocal(desde.center);
    final fin = cajaOverlay.globalToLocal(hasta.center);
    // Punto de control del arco: 120 dp arriba del extremo más alto, sin
    // salirse por la barra de estado.
    final techo = MediaQuery.paddingOf(context).top + 24;
    final control = Offset(
      (inicio.dx + fin.dx) / 2,
      math.max(math.min(inicio.dy, fin.dy) - 120, techo),
    );

    late final OverlayEntry entrada;
    entrada = OverlayEntry(
      builder: (_) => _Vuelo(
        inicio: inicio,
        control: control,
        fin: fin,
        imagenUrl: imagenUrl,
        alAterrizar: () => _aterrizar(entrada),
      ),
    );
    _vuelos.add(entrada);
    _enCamino.value = _vuelos.length;
    overlay.insert(entrada);
  }

  void _aterrizar(OverlayEntry entrada) {
    if (!_vuelos.remove(entrada)) return;
    entrada
      ..remove()
      ..dispose();
    // En el mismo cuadro: la insignia que esperaba aparece y el destino da
    // el trago.
    _enCamino.value = _vuelos.length;
    _llegadas.value++;
  }

  @override
  void dispose() {
    // Cerrar sesión o un context.go a media animación: se quitan los vuelos.
    for (final entrada in _vuelos) {
      entrada
        ..remove()
        ..dispose();
    }
    _vuelos.clear();
    _llegadas.dispose();
    _enCamino.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Marca el ícono del carrito como destino del vuelo y le da el trago al
/// llegar cada miniatura. Sin VueloAlCarrito arriba solo pinta a su hijo.
class DestinoVuelo extends StatefulWidget {
  const DestinoVuelo({required this.child, super.key});

  final Widget child;

  /// Cuántas miniaturas van en el aire en el ámbito del DestinoVuelo que
  /// rodea a [context] (todas van al carrito); baja en uno en el cuadro en
  /// que cada una aterriza y el destino da el trago. Null fuera de un
  /// DestinoVuelo con ámbito. InsigniaCarrito lo usa para reaccionar cuando
  /// llega la miniatura y no antes.
  static ValueListenable<int>? enCamino(BuildContext context) =>
      context.findAncestorStateOfType<_DestinoVueloState>()?._ambito?._enCamino;

  @override
  State<DestinoVuelo> createState() => _DestinoVueloState();
}

class _DestinoVueloState extends State<DestinoVuelo>
    with SingleTickerProviderStateMixin {
  static final Animatable<double> _trago = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 1.18,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.18,
          end: 1,
        ).chain(CurveTween(curve: AppMovimiento.curvaRebote)),
        weight: 60,
      ),
    ],
  );

  late final AnimationController _control;
  _VueloAlCarritoState? _ambito;

  @override
  void initState() {
    super.initState();
    _control = AnimationController(vsync: this, duration: AppMovimiento.media);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ambito = context.findAncestorStateOfType<_VueloAlCarritoState>();
    if (ambito == _ambito) return;
    _soltarAmbito();
    if (ambito == null) return;
    ambito
      .._registrar(this)
      .._llegadas.addListener(_alLlegar);
    _ambito = ambito;
  }

  void _soltarAmbito() {
    _ambito?._llegadas.removeListener(_alLlegar);
    _ambito?._quitar(this);
    _ambito = null;
  }

  void _alLlegar() => _control.forward(from: 0);

  @override
  void dispose() {
    _soltarAmbito();
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _control.drive(_trago), child: widget.child);
}

/// La miniatura en vuelo: un arco cuadrático de [inicio] a [fin] que pasa
/// cerca de [control]. Se encoge al final y se desvanece en el último 20 %.
class _Vuelo extends StatefulWidget {
  const _Vuelo({
    required this.inicio,
    required this.control,
    required this.fin,
    required this.imagenUrl,
    required this.alAterrizar,
  });

  final Offset inicio;
  final Offset control;
  final Offset fin;
  final String imagenUrl;
  final VoidCallback alAterrizar;

  @override
  State<_Vuelo> createState() => _VueloState();
}

class _VueloState extends State<_Vuelo> with SingleTickerProviderStateMixin {
  static const double _lado = 44;

  late final AnimationController _control;

  @override
  void initState() {
    super.initState();
    _control = AnimationController(vsync: this, duration: AppMovimiento.vuelo)
      ..addStatusListener(_alCambiarEstado);
    _control.forward().ignore();
  }

  void _alCambiarEstado(AnimationStatus estado) {
    if (estado == AnimationStatus.completed) widget.alAterrizar();
  }

  Offset _enArco(double p) {
    final q = 1 - p;
    return widget.inicio * (q * q) +
        widget.control * (2 * q * p) +
        widget.fin * (p * p);
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _control,
            child: RepaintBoundary(
              child: _Miniatura(imagenUrl: widget.imagenUrl, lado: _lado),
            ),
            builder: (context, miniatura) {
              final t = _control.value;
              final punto = _enArco(Curves.easeInOutCubic.transform(t));
              final escala = 1 - 0.65 * Curves.easeInCubic.transform(t);
              final opacidad = t < 0.8 ? 1.0 : (1 - t) / 0.2;
              return Align(
                alignment: Alignment.topLeft,
                child: Transform.translate(
                  offset: punto - const Offset(_lado / 2, _lado / 2),
                  child: Opacity(
                    opacity: opacidad,
                    child: Transform.scale(scale: escala, child: miniatura),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.imagenUrl, required this.lado});

  final String imagenUrl;
  final double lado;

  @override
  Widget build(BuildContext context) {
    final relleno = ColoredBox(color: AppColors.pierDorado);
    return SizedBox.square(
      dimension: lado,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          // Sin cacheWidth: es la misma entrada de ImageCache que la foto que
          // ya pintan la tarjeta y la galería, así que sale con la foto desde
          // el primer cuadro (sin descargarla otra vez). Si aún no está, el
          // disco dorado ocupa su lugar mientras llega.
          child: ClipOval(
            child: imagenUrl.isEmpty
                ? relleno
                : Image.network(
                    imagenUrl,
                    fit: BoxFit.cover,
                    frameBuilder: (_, foto, cuadro, sincrona) =>
                        sincrona || cuadro != null ? foto : relleno,
                    errorBuilder: (_, _, _) => relleno,
                  ),
          ),
        ),
      ),
    );
  }
}
