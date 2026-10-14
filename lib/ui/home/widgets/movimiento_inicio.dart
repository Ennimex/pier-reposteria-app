// lib/ui/home/widgets/movimiento_inicio.dart
//
// Piezas de movimiento propias del inicio. Las generales (pulsación, cambios
// en sitio, apariciones…) viven en lib/ui/core/ui/movimiento; aquí solo lo
// que comparten las secciones de esta carpeta:
//
// - VistaInicio y EntradaInicio: cada sección entra una sola vez, en cascada
//   con las que llegan en el mismo cuadro. La que está más abajo de lo que se
//   ve espera a que el scroll la traiga (no gasta su entrada fuera de la
//   pantalla) y lo de adentro (tarjetas, íconos) entra al compás de ella. Es
//   propia y no EntradaSuave porque la espera se decide al empezar: depende
//   de si la sección ya se ve.
// - RanuraInicio: el lugar fijo de una sección que llega tarde o se va.
// - GestoIcono y BarridoDeLuz: gestos de una sola vez de títulos y ofertas.
// - FotoConFundido: las fotos de red aparecen con un fundido.
//
// Todas respetan «reducir movimiento», terminan solas y no usan Timers.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';

// ── Fotos de red ─────────────────────────────────────────────────────────

/// Lo que devuelve el `frameBuilder` de una foto de red del inicio: la que
/// llega de internet aparece con un fundido corto (al recargar, el inicio
/// vacía la caché de imágenes); la que ya estaba en caché se pinta tal cual
/// desde el primer cuadro.
///
/// ```dart
/// frameBuilder: (_, foto, cuadro, sincrona) =>
///     FotoConFundido(foto: foto, cuadro: cuadro, sincrona: sincrona),
/// ```
class FotoConFundido extends StatelessWidget {
  const FotoConFundido({
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

// ── Entradas de las secciones ────────────────────────────────────────────

/// Alrededor de la lista del inicio. Lleva la cuenta de qué secciones ya
/// entraron (cada `id` entra una vez: recargar, o una sección que se va y
/// vuelve, no la repiten), arma una cascada con las que llegan en un mismo
/// cuadro y suelta a las que esperan a verse cuando la lista se desplaza o
/// cambia de tamaño.
class VistaInicio extends StatefulWidget {
  const VistaInicio({
    required this.child,
    this.retrasoLlegada = Duration.zero,
    super.key,
  });

  final Widget child;

  /// Espera de las secciones que ya están cuando la pantalla llega (después
  /// de context.go, AppMovimiento.trasRaiz). Las que llegan después solo
  /// esperan lo que falte de ella.
  final Duration retrasoLlegada;

  @override
  State<VistaInicio> createState() => _VistaInicioState();
}

class _VistaInicioState extends State<VistaInicio> {
  final Set<Object> _vistas = <Object>{};
  // Las montadas en este cuadro, en el orden en que se construyeron: de
  // arriba abajo.
  final List<_EntradaInicioState> _tanda = <_EntradaInicioState>[];
  // Las que esperan a verse. Vienen de tandas distintas: al revisarlas se
  // ordenan por su lugar en la pantalla.
  final Set<_EntradaInicioState> _esperando = <_EntradaInicioState>{};
  Duration? _primerCuadro;
  bool _revisionPendiente = false;

  /// Anota la sección `id`: false si ya había entrado.
  bool _registrar(_EntradaInicioState entrada, Object id) {
    if (!_vistas.add(id)) return false;
    if (_tanda.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(_soltarTanda);
    }
    _tanda.add(entrada);
    return true;
  }

  void _olvidar(_EntradaInicioState entrada) {
    _tanda.remove(entrada);
    _esperando.remove(entrada);
  }

  // Lo que se montó en un mismo cuadro: lo que ya se ve entra en cascada y
  // lo demás espera a que el scroll lo traiga.
  void _soltarTanda(Duration cuadro) {
    final tanda = List<_EntradaInicioState>.of(_tanda);
    _tanda.clear();
    if (!mounted) return;
    final primero = _primerCuadro ??= cuadro;
    final pasado = cuadro - primero;
    final llegada = widget.retrasoLlegada > pasado
        ? widget.retrasoLlegada - pasado
        : Duration.zero;
    final area = _area();
    var turno = 0;
    for (final entrada in tanda) {
      if (!entrada.mounted) continue;
      if (entrada._seVe(area)) {
        entrada._empezar(llegada + AppMovimiento.retrasoCascada(turno++));
      } else {
        _esperando.add(entrada);
      }
    }
  }

  void _programarRevision() {
    if (_revisionPendiente || _esperando.isEmpty) return;
    _revisionPendiente = true;
    WidgetsBinding.instance
      ..addPostFrameCallback(_revisar)
      ..ensureVisualUpdate();
  }

  // Después del layout: las que ya se ven entran, en cascada entre ellas y
  // de arriba abajo (las que esperan pueden venir de tandas distintas, y un
  // deslizamiento rápido destapa varias a la vez).
  void _revisar(Duration _) {
    _revisionPendiente = false;
    if (!mounted) return;
    final area = _area();
    final visibles = [
      for (final entrada in _esperando)
        if (entrada._seVe(area)) entrada,
    ]..sort((a, b) => a._arriba().compareTo(b._arriba()));
    var turno = 0;
    for (final entrada in visibles) {
      _esperando.remove(entrada);
      entrada._empezar(AppMovimiento.retrasoCascada(turno++));
    }
  }

  /// La parte de la pantalla donde se ve la lista.
  Rect? _area() {
    final caja = context.findRenderObject();
    if (caja is! RenderBox || !caja.hasSize) return null;
    return caja.localToGlobal(Offset.zero) & caja.size;
  }

  bool _alAvisar(Notification aviso) {
    // Solo la lista del inicio (profundidad 0), no los carruseles de adentro.
    final propio =
        (aviso is ScrollNotification && aviso.depth == 0) ||
        (aviso is ScrollMetricsNotification && aviso.depth == 0);
    if (propio) _programarRevision();
    return false;
  }

  @override
  void didUpdateWidget(VistaInicio oldWidget) {
    super.didUpdateWidget(oldWidget);
    // La pantalla se volvió a armar (llegaron datos, cambió la sesión): algo
    // pudo moverse sin scroll.
    _programarRevision();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<Notification>(
      onNotification: _alAvisar,
      child: _AlcanceVista(estado: this, child: widget.child),
    );
  }
}

class _AlcanceVista extends InheritedWidget {
  const _AlcanceVista({required this.estado, required super.child});

  final _VistaInicioState estado;

  @override
  bool updateShouldNotify(_AlcanceVista oldWidget) => false;
}

/// Entrada de un bloque del inicio: fundido más una subida corta en dp y, si
/// se pide, una escala inicial. Se reproduce una sola vez y nunca fuera de la
/// vista; nunca bloquea toques.
///
/// - Con `id`, dentro de una VistaInicio, es una sección: entra en cascada con
///   las que llegan en el mismo cuadro y, si está más abajo de lo que se ve,
///   espera a que el scroll la traiga.
/// - Sin `id`, dentro de otra EntradaInicio (una tarjeta, una reseña): entra
///   al compás de su sección, `orden` escalones después. Si su sección ya
///   había entrado (una tarjeta que aparece al desplazar un carrusel), llega
///   quieta.
/// - Sola: entra en cuanto se monta, en el escalón `orden`.
class EntradaInicio extends StatefulWidget {
  const EntradaInicio({
    required this.child,
    this.id,
    this.orden = 0,
    this.duracion = AppMovimiento.entrada,
    this.desplazamiento = const Offset(0, AppMovimiento.distancia),
    this.escalaInicial = 1,
    super.key,
  });

  final Widget child;

  /// Identidad de la sección dentro de la VistaInicio.
  final Object? id;

  /// Escalón dentro de su sección (0 = junto con ella).
  final int orden;

  final Duration duracion;

  /// Desde dónde llega, en dp (máximo 24): `Offset(0, 16)` sube 16 dp y
  /// `Offset(24, 0)` llega desde la derecha.
  final Offset desplazamiento;

  /// Escala con la que empieza (0.85 o más; 1 = sin escala).
  final double escalaInicial;

  @override
  State<EntradaInicio> createState() => _EntradaInicioState();
}

/// Lo que se mueve al compás de la entrada de su sección.
abstract class _Seguidor {
  /// La sección empieza a entrar; [espera] es lo que falta para que se vea.
  void _seguir(Duration espera);

  /// La sección ya está en su lugar (o no anima): sin movimiento.
  void _quedarse();
}

enum _Fase { espera, entra, quieta }

class _EntradaInicioState extends State<EntradaInicio>
    with SingleTickerProviderStateMixin
    implements _Seguidor {
  late final AnimationController _control;
  // Los tramos se fijan al empezar (la espera se decide en ese momento); las
  // animaciones son siempre las mismas, así que no hace falta reconstruir.
  final CurveTween _tramoOpacidad = CurveTween(curve: Curves.linear);
  final CurveTween _tramoAvance = CurveTween(curve: Curves.linear);
  late final Animation<double> _opacidad;
  late final Animation<double> _avance;

  _Fase _fase = _Fase.quieta;
  Duration _espera = Duration.zero;
  final List<_Seguidor> _seguidores = <_Seguidor>[];
  _VistaInicioState? _vista;
  _EntradaInicioState? _guia;
  bool _preparada = false;

  @override
  void initState() {
    super.initState();
    _control = AnimationController(vsync: this, value: 1);
    _opacidad = _control.drive(_tramoOpacidad);
    _avance = _control.drive(_tramoAvance);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparada) return;
    _preparada = true;
    _preparar();
  }

  // Se decide una sola vez, al montarse: reconstruir la sección (provider,
  // recarga, sondeo) nunca repite la entrada.
  void _preparar() {
    if (widget.duracion <= Duration.zero || AppMovimiento.reducido(context)) {
      return; // Quieta en su lugar.
    }
    _fase = _Fase.espera;
    _control.value = 0;
    final id = widget.id;
    if (id != null) {
      final vista = context
          .getInheritedWidgetOfExactType<_AlcanceVista>()
          ?.estado;
      if (vista != null) {
        if (vista._registrar(this, id)) {
          _vista = vista;
        } else {
          _quedarse(); // Ya había entrado.
        }
        return;
      }
    }
    final guia = context
        .getInheritedWidgetOfExactType<_AlcanceEntrada>()
        ?.estado;
    if (guia != null) {
      _guia = guia;
      guia._sumar(this);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _seguir(Duration.zero),
    );
  }

  void _empezar(Duration espera) {
    if (!mounted || _fase != _Fase.espera) return;
    final total = espera + widget.duracion;
    final inicio = espera.inMicroseconds / total.inMicroseconds;
    _fase = _Fase.entra;
    _espera = espera;
    // El fundido termina antes que el movimiento: el bloque ya se lee
    // mientras se asienta.
    _tramoOpacidad.curve = Interval(
      inicio,
      inicio + (1 - inicio) * 0.6,
      curve: Curves.easeOut,
    );
    _tramoAvance.curve = Interval(
      inicio,
      1,
      curve: AppMovimiento.curvaEntrada,
    );
    _control
      ..duration = total
      ..forward(from: 0).ignore();
    final seguidores = List<_Seguidor>.of(_seguidores);
    _seguidores.clear();
    for (final seguidor in seguidores) {
      seguidor._seguir(espera);
    }
  }

  @override
  void _seguir(Duration espera) =>
      _empezar(espera + AppMovimiento.retrasoCascada(widget.orden));

  @override
  void _quedarse() {
    _fase = _Fase.quieta;
    _control.value = 1;
    final seguidores = List<_Seguidor>.of(_seguidores);
    _seguidores.clear();
    for (final seguidor in seguidores) {
      seguidor._quedarse();
    }
  }

  /// Pone a [seguidor] al compás de esta entrada.
  void _sumar(_Seguidor seguidor) {
    switch (_fase) {
      case _Fase.espera:
        _seguidores.add(seguidor);
      case _Fase.entra:
        if (_control.isCompleted) {
          seguidor._quedarse();
        } else {
          // Llegó cuando la sección ya entraba: lo que falte de su espera.
          final transcurrido =
              (_control.duration ?? Duration.zero) * _control.value;
          final falta = _espera - transcurrido;
          seguidor._seguir(falta > Duration.zero ? falta : Duration.zero);
        }
      case _Fase.quieta:
        seguidor._quedarse();
    }
  }

  void _restar(_Seguidor seguidor) => _seguidores.remove(seguidor);

  /// Si ya se ve en [area] (la parte de la pantalla con la lista): su borde
  /// de arriba pasó del 90 % de la vista.
  bool _seVe(Rect? area) {
    final caja = context.findRenderObject();
    // Sin medidas no se sabe: mejor que entre a que se quede invisible.
    if (area == null || caja is! RenderBox || !caja.hasSize) return true;
    final arriba = caja.localToGlobal(Offset.zero).dy;
    return arriba < area.top + area.height * 0.9 &&
        arriba + caja.size.height > area.top;
  }

  /// Su borde de arriba en la pantalla (0 mientras no tiene medidas).
  double _arriba() {
    final caja = context.findRenderObject();
    if (caja is! RenderBox || !caja.hasSize) return 0;
    return caja.localToGlobal(Offset.zero).dy;
  }

  @override
  void dispose() {
    _vista?._olvidar(this);
    _guia?._restar(this);
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AlcanceEntrada(
      estado: this,
      child: FadeTransition(
        opacity: _opacidad,
        // Los lectores de pantalla ven la sección aunque espere su entrada.
        alwaysIncludeSemantics: true,
        child: _Llegada(
          avance: _avance,
          desplazamiento: widget.desplazamiento,
          escalaInicial: widget.escalaInicial,
          child: widget.child,
        ),
      ),
    );
  }
}

class _AlcanceEntrada extends InheritedWidget {
  const _AlcanceEntrada({required this.estado, required super.child});

  final _EntradaInicioState estado;

  @override
  bool updateShouldNotify(_AlcanceEntrada oldWidget) => false;
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

// ── Secciones que llegan tarde ───────────────────────────────────────────

/// El lugar fijo de una sección que puede no estar (llega del backend un
/// momento después, o se va): al llegar, el espacio se abre con suavidad y el
/// contenido aparece con un fundido; al irse, se apaga y el espacio se
/// cierra, sin que lo de abajo salte. Mientras se va conserva lo último que
/// mostró. Sin `child`, vacía.
class RanuraInicio extends StatefulWidget {
  const RanuraInicio({this.child, super.key});

  final Widget? child;

  @override
  State<RanuraInicio> createState() => _RanuraInicioState();
}

class _RanuraInicioState extends State<RanuraInicio> {
  Widget? _ultimo;

  @override
  void initState() {
    super.initState();
    _ultimo = widget.child;
  }

  @override
  void didUpdateWidget(RanuraInicio oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ultimo = widget.child ?? _ultimo;
  }

  @override
  Widget build(BuildContext context) {
    return Aparicion(
      visible: widget.child != null,
      duracion: AppMovimiento.media,
      child: _ultimo ?? const SizedBox.shrink(),
    );
  }
}

// ── Gestos de una sola vez ───────────────────────────────────────────────

/// Gestos de los íconos de títulos y ofertas.
enum TipoGesto {
  /// Crece desde 0.6 enderezándose (estrellas, palomita).
  brinco,

  /// Una vuelta al revés de las manecillas («Pide de nuevo»).
  vuelta,

  /// Sacudida eléctrica corta (el rayo de las ofertas relámpago).
  chispazo,

  /// Se encoge, crece de más y asienta (los brillos).
  destello,

  /// Dos parpadeos de flama.
  flama,

  /// Dos empujones hacia adelante (la flecha de un botón).
  empujon,
}

/// Un ícono que hace su gesto una sola vez, al compás de la entrada de su
/// sección (`retraso` después de que la sección empieza a verse); sin
/// sección, en cuanto se monta. Si la sección ya había entrado, o con
/// movimiento reducido, se queda quieto. Siempre termina en reposo.
class GestoIcono extends StatefulWidget {
  const GestoIcono({
    required this.tipo,
    required this.child,
    this.retraso = AppMovimiento.rapida,
    super.key,
  });

  final TipoGesto tipo;
  final Widget child;

  /// Espera después de que la sección empieza a verse.
  final Duration retraso;

  /// Cuánto dura cada gesto, con el ritmo de la casa: los de un golpe
  /// (brinco, chispazo, destello) son pops de ícono; la vuelta completa y
  /// los de dos tiempos (flama, empujón) duran lo de un relleno.
  static Duration duracionDe(TipoGesto tipo) => switch (tipo) {
    TipoGesto.brinco ||
    TipoGesto.chispazo ||
    TipoGesto.destello => AppMovimiento.enfasis,
    TipoGesto.vuelta ||
    TipoGesto.flama ||
    TipoGesto.empujon => AppMovimiento.relleno,
  };

  @override
  State<GestoIcono> createState() => _GestoIconoState();
}

/// Se encoge a 0.7, crece a 1.15 y asienta en 1.
final Animatable<double> _escalaDestello = TweenSequence<double>(
  <TweenSequenceItem<double>>[
    TweenSequenceItem<double>(
      tween: Tween<double>(
        begin: 0.7,
        end: 1.15,
      ).chain(CurveTween(curve: AppMovimiento.curvaEntrada)),
      weight: 55,
    ),
    TweenSequenceItem<double>(
      tween: Tween<double>(
        begin: 1.15,
        end: 1,
      ).chain(CurveTween(curve: AppMovimiento.curvaEstandar)),
      weight: 45,
    ),
  ],
);

/// Pose del gesto en el avance [t] (0 = empieza, 1 = reposo): escala, giro
/// en radianes y desplazamiento horizontal en dp.
({double escala, double giro, double dx}) _pose(TipoGesto tipo, double t) {
  if (t >= 1) return (escala: 1, giro: 0, dx: 0);
  switch (tipo) {
    case TipoGesto.brinco:
      return (
        escala: 0.6 + 0.4 * AppMovimiento.curvaRebote.transform(t),
        giro: -0.35 * (1 - AppMovimiento.curvaEntrada.transform(t)),
        dx: 0,
      );
    case TipoGesto.vuelta:
      return (
        escala: 1,
        giro: -2 * math.pi * AppMovimiento.curvaEstandar.transform(t),
        dx: 0,
      );
    case TipoGesto.chispazo:
      return (
        escala: 1 + 0.15 * math.sin(t * math.pi),
        giro: math.sin(t * math.pi * 6) * (1 - t) * 0.2,
        dx: 0,
      );
    case TipoGesto.destello:
      return (
        escala: _escalaDestello.transform(t),
        giro: 0.26 * (1 - AppMovimiento.curvaEntrada.transform(t)),
        dx: 0,
      );
    case TipoGesto.flama:
      return (
        escala: 1 + 0.12 * math.sin(t * math.pi * 2).abs() * (1 - 0.4 * t),
        giro: math.sin(t * math.pi * 4) * (1 - t) * 0.08,
        dx: 0,
      );
    case TipoGesto.empujon:
      final onda = math.sin(t * math.pi * 2);
      return (
        escala: 1,
        giro: 0,
        dx: AppMovimiento.distanciaCorta / 2 * onda * onda,
      );
  }
}

class _GestoIconoState extends State<GestoIcono>
    with SingleTickerProviderStateMixin
    implements _Seguidor {
  late final AnimationController _control;
  _EntradaInicioState? _guia;
  bool _preparado = false;
  bool _armado = false;
  double _inicio = 0;

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
    final guia = context
        .getInheritedWidgetOfExactType<_AlcanceEntrada>()
        ?.estado;
    if (guia != null) {
      _guia = guia;
      guia._sumar(this);
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _seguir(Duration.zero),
      );
    }
  }

  @override
  void _seguir(Duration espera) {
    if (!mounted || _armado) return;
    _armado = true;
    final retraso = espera + widget.retraso;
    final total = retraso + GestoIcono.duracionDe(widget.tipo);
    _inicio = retraso.inMicroseconds / total.inMicroseconds;
    _control
      ..duration = total
      ..forward(from: 0).ignore();
  }

  @override
  void _quedarse() {
    // Ya está en reposo.
  }

  // Avance del gesto: 1 (reposo) mientras no se arma y al terminar; 0
  // durante la espera.
  double get _avance {
    if (!_armado) return 1;
    final valor = _control.value;
    if (valor >= 1) return 1;
    if (valor <= _inicio) return 0;
    return (valor - _inicio) / (1 - _inicio);
  }

  @override
  void dispose() {
    _guia?._restar(this);
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _control,
      child: widget.child,
      builder: (context, hijo) {
        final pose = _pose(widget.tipo, _avance);
        return Transform.translate(
          offset: Offset(pose.dx, 0),
          child: Transform.rotate(
            angle: pose.giro,
            child: Transform.scale(scale: pose.escala, child: hijo),
          ),
        );
      },
    );
  }
}

/// Un solo barrido de luz que cruza una pieza (el código de descuento del
/// banner de promoción) poco después de que su sección empieza a verse:
/// llama la atención sin quedarse en bucle. Pinta encima del hijo, recortado
/// a sus esquinas. Con movimiento reducido, o si la sección ya había
/// entrado, no hay barrido.
class BarridoDeLuz extends StatefulWidget {
  const BarridoDeLuz({
    required this.child,
    required this.radio,
    this.retraso = AppMovimiento.enfasis,
    super.key,
  });

  final Widget child;

  /// Esquinas de la pieza (la luz no se sale de ellas).
  final BorderRadius radio;

  /// Espera después de que la sección empieza a verse.
  final Duration retraso;

  /// Lo que tarda la luz en cruzar: una línea que recorre la pieza, como
  /// las que se llenan.
  static const Duration duracion = AppMovimiento.relleno;

  @override
  State<BarridoDeLuz> createState() => _BarridoDeLuzState();
}

class _BarridoDeLuzState extends State<BarridoDeLuz>
    with SingleTickerProviderStateMixin
    implements _Seguidor {
  late final AnimationController _control;
  final CurveTween _tramo = CurveTween(curve: Curves.linear);
  late final Animation<double> _avance;
  _EntradaInicioState? _guia;
  bool _preparado = false;
  bool _armado = false;

  @override
  void initState() {
    super.initState();
    _control = AnimationController(vsync: this);
    _avance = _control.drive(_tramo);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparado) return;
    _preparado = true;
    if (AppMovimiento.reducido(context)) return;
    final guia = context
        .getInheritedWidgetOfExactType<_AlcanceEntrada>()
        ?.estado;
    if (guia != null) {
      _guia = guia;
      guia._sumar(this);
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _seguir(Duration.zero),
      );
    }
  }

  @override
  void _seguir(Duration espera) {
    if (!mounted || _armado) return;
    _armado = true;
    final retraso = espera + widget.retraso;
    final total = retraso + BarridoDeLuz.duracion;
    _tramo.curve = Interval(
      retraso.inMicroseconds / total.inMicroseconds,
      1,
      curve: AppMovimiento.curvaEstandar,
    );
    _control
      ..duration = total
      ..forward(from: 0).ignore();
  }

  @override
  void _quedarse() {
    // Sin barrido.
  }

  @override
  void dispose() {
    _guia?._restar(this);
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Aísla el repintado de cada cuadro del barrido.
    return RepaintBoundary(
      child: CustomPaint(
        foregroundPainter: _PintorBarrido(avance: _avance, radio: widget.radio),
        child: widget.child,
      ),
    );
  }
}

class _PintorBarrido extends CustomPainter {
  _PintorBarrido({required this.avance, required this.radio})
    : super(repaint: avance);

  final Animation<double> avance;
  final BorderRadius radio;

  @override
  void paint(Canvas canvas, Size size) {
    final t = avance.value;
    if (t <= 0 || t >= 1 || size.isEmpty) return;
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
              Colors.white.withValues(alpha: 0.5),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(franja),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_PintorBarrido oldDelegate) =>
      oldDelegate.avance != avance || oldDelegate.radio != radio;
}
