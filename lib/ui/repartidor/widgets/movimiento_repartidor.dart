// lib/ui/repartidor/widgets/movimiento_repartidor.dart
//
// Piezas de movimiento propias del módulo Repartidor. Las generales
// (entradas, cambios en sitio, presión, sacudidas…) viven en
// lib/ui/core/ui/movimiento; aquí solo lo que comparten las pantallas de esta
// carpeta. Todas respetan «reducir movimiento», terminan solas, no usan
// Timers y no animan lo que no se ve: un cambio que llega con la pestaña
// oculta o con otra pantalla encima ya está resuelto cuando el repartidor
// vuelve (no se reproduce tarde).
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';

/// Si lo que está en [context] se ve: su pestaña es la actual y ninguna
/// pantalla lo tapa (el TickerMode de arriba está encendido). No crea
/// dependencia: se lee en el momento en que algo cambia.
bool seVe(BuildContext context) =>
    TickerMode.getValuesNotifier(context).value.enabled;

/// Si un cambio que ocurre ahora en [context] se anima: se ve y el usuario
/// no pidió menos movimiento.
bool conMovimiento(BuildContext context) =>
    seVe(context) && !AppMovimiento.reducido(context);

/// CambioAnimado que solo anima lo que se ve. Con la pestaña oculta o la
/// ruta tapada, el contenido nuevo toma el lugar del anterior en silencio:
/// no queda una transición pendiente que se reproduzca al volver.
class CambioEnVista extends StatefulWidget {
  const CambioEnVista({
    required this.clave,
    required this.child,
    this.tipo = TipoCambio.fundido,
    this.duracion = AppMovimiento.corta,
    this.alineacion = AlignmentDirectional.centerStart,
    this.direccion = 1,
    this.soloEntrada = false,
    super.key,
  });

  /// Lo que identifica al contenido (un estado, un texto…): cuando cambia,
  /// el contenido cambió.
  final Object clave;

  final Widget child;
  final TipoCambio tipo;
  final Duration duracion;
  final AlignmentGeometry alineacion;
  final int direccion;

  /// true: el anterior sale del árbol en el mismo cuadro (ver CambioAnimado).
  final bool soloEntrada;

  @override
  State<CambioEnVista> createState() => _CambioEnVistaState();
}

class _CambioEnVistaState extends State<CambioEnVista> {
  // La Key que ve el CambioAnimado: solo avanza con los cambios que se ven.
  int _version = 0;

  @override
  void didUpdateWidget(CambioEnVista oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clave != oldWidget.clave && seVe(context)) _version++;
  }

  @override
  Widget build(BuildContext context) {
    return CambioAnimado(
      tipo: widget.tipo,
      duracion: widget.duracion,
      alineacion: widget.alineacion,
      direccion: widget.direccion,
      soloEntrada: widget.soloEntrada,
      child: KeyedSubtree(key: ValueKey<int>(_version), child: widget.child),
    );
  }
}

/// AnimatedSize con el ritmo de la casa: lo que crece o se encoge empuja a
/// lo de alrededor con suavidad en vez de saltar. Es inmediato (un
/// milisegundo: AnimatedSize no acepta cero) con movimiento reducido o si
/// el cambio llega sin que se vea.
class TamanoSuave extends StatelessWidget {
  const TamanoSuave({
    required this.child,
    this.alineacion = AlignmentDirectional.topStart,
    this.duracion = AppMovimiento.corta,
    this.recorte = Clip.hardEdge,
    super.key,
  });

  final Widget child;
  final AlignmentGeometry alineacion;
  final Duration duracion;

  /// Clip.none deja ver sombras y brillos mientras crece (solo donde nada
  /// queda debajo).
  final Clip recorte;

  static const Duration _instante = Duration(milliseconds: 1);

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: conMovimiento(context) ? duracion : _instante,
      curve: AppMovimiento.curvaEstandar,
      alignment: alineacion,
      clipBehavior: recorte,
      child: child,
    );
  }
}

/// Avisa si la pantalla ya se vio alguna vez. Las pestañas del panel se
/// construyen ocultas: lo que [builder] envuelva en entradas solo cuando
/// `vista` es true entra en el primer cuadro en que la pestaña se ve (todo
/// junto, en una sola cascada) y nunca deja entradas pendientes mientras
/// sigue oculta. Escucha el TickerMode sin depender de él: cambiar de
/// pestaña no reconstruye la pantalla.
///
/// ```dart
/// PrimeraVista(builder: (context, vista, _) => vista ? EntradaSuave(...) : contenido)
/// ```
class PrimeraVista extends StatefulWidget {
  const PrimeraVista({required this.builder, super.key});

  /// Recibe `vista`: true desde el primer cuadro en que la pantalla se ve.
  final ValueWidgetBuilder<bool> builder;

  @override
  State<PrimeraVista> createState() => _PrimeraVistaState();
}

class _PrimeraVistaState extends State<PrimeraVista> {
  ValueListenable<TickerModeData>? _modo;
  bool _vista = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _seguir();
  }

  @override
  void activate() {
    super.activate();
    // Movida a otro lugar del árbol: su TickerMode puede ser otro.
    _seguir();
  }

  void _seguir() {
    if (_vista) return;
    final modo = TickerMode.getValuesNotifier(context);
    if (!identical(modo, _modo)) {
      _modo?.removeListener(_alCambiar);
      _modo = modo..addListener(_alCambiar);
    }
    if (modo.value.enabled) _dejarDeSeguir();
  }

  // Llega mientras se construye el TickerMode de arriba: la pantalla se
  // reconstruye en ese mismo cuadro, ya con sus entradas.
  void _alCambiar() {
    if (_vista || !(_modo?.value.enabled ?? false)) return;
    setState(_dejarDeSeguir);
  }

  void _dejarDeSeguir() {
    _vista = true;
    _modo?.removeListener(_alCambiar);
    _modo = null;
  }

  @override
  void dispose() {
    _modo?.removeListener(_alCambiar);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _vista, null);
}

/// Columna de bloques con Key que entran y salen sin saltos: el que llega
/// abre su espacio y aparece; el que se va se apaga, cierra su espacio y
/// sale del árbol (mientras tanto no recibe toques, no lo leen los lectores
/// de pantalla y su Hero no vuela). Lo que ya estaba al montarse, los
/// cambios con movimiento reducido y los que llegan sin que se vean son
/// inmediatos.
class ColumnaAnimada extends StatefulWidget {
  const ColumnaAnimada({required this.children, super.key});

  /// Cada uno con una Key única que lo identifica entre reconstrucciones.
  final List<Widget> children;

  @override
  State<ColumnaAnimada> createState() => _ColumnaAnimadaState();
}

/// Un bloque de la columna y, mientras entra o sale, su animación.
class _Bloque {
  _Bloque(this.widget);

  /// El último widget recibido (el de un bloque que se va queda congelado).
  Widget widget;

  AnimationController? control;
  CurvedAnimation? alto;
  CurvedAnimation? opacidad;
  bool saliendo = false;

  Key get clave => widget.key!;

  void soltar() {
    alto?.dispose();
    opacidad?.dispose();
    control?.dispose();
    alto = null;
    opacidad = null;
    control = null;
  }
}

class _ColumnaAnimadaState extends State<ColumnaAnimada>
    with TickerProviderStateMixin {
  late List<_Bloque> _bloques = <_Bloque>[
    for (final hijo in widget.children) _Bloque(hijo),
  ];

  // Mientras se arma la lista nueva, un bloque que termina de irse al
  // instante lo resuelve didUpdateWidget (no el status listener, que
  // tocaría la lista que se está recorriendo).
  bool _actualizando = false;

  @override
  void didUpdateWidget(ColumnaAnimada oldWidget) {
    super.didUpdateWidget(oldWidget);
    _actualizando = true;
    try {
      _acomodar();
    } finally {
      _actualizando = false;
    }
  }

  void _acomodar() {
    final animar = conMovimiento(context);
    final hijos = widget.children;
    final nuevos = <Key>{for (final hijo in hijos) hijo.key!};
    final previos = <Key, _Bloque>{for (final b in _bloques) b.clave: b};
    final resultado = <_Bloque>[];
    final puestos = <Key>{};
    var siguiente = 0;

    void poner(Widget hijo) {
      final clave = hijo.key!;
      if (!puestos.add(clave)) return;
      final previo = previos[clave];
      if (previo == null) {
        final bloque = _Bloque(hijo);
        if (animar) _entrar(bloque);
        resultado.add(bloque);
        return;
      }
      previo.widget = hijo;
      if (previo.saliendo) {
        // Regresó antes de terminar de irse.
        previo.saliendo = false;
        if (animar) {
          previo.control?.forward().ignore();
        } else {
          previo.control?.value = 1;
        }
      }
      resultado.add(previo);
    }

    // Recorre el orden anterior: los que siguen se acomodan en el orden
    // nuevo y los que se fueron se quedan donde estaban mientras salen.
    for (final previo in _bloques) {
      if (!nuevos.contains(previo.clave)) {
        if (animar && _salir(previo)) {
          resultado.add(previo);
        } else {
          _soltarTrasCuadro(previo);
        }
        continue;
      }
      while (siguiente < hijos.length && !puestos.contains(previo.clave)) {
        poner(hijos[siguiente++]);
      }
    }
    while (siguiente < hijos.length) {
      poner(hijos[siguiente++]);
    }
    _bloques = resultado;
  }

  void _animable(_Bloque bloque, {required double desde}) {
    if (bloque.control != null) return;
    final control = AnimationController(
      vsync: this,
      duration: AppMovimiento.media,
      reverseDuration: AppMovimiento.corta,
      value: desde,
    )..addStatusListener((estado) => _alCambiarEstado(bloque, estado));
    bloque
      ..control = control
      // Al llegar, el espacio se abre y el contenido aparece desde el 30 %;
      // al irse, el contenido se apaga primero (40 %) y luego se cierra el
      // espacio ya vacío (como Aparicion).
      ..alto = CurvedAnimation(
        parent: control,
        curve: AppMovimiento.curvaEnfasis,
        reverseCurve: const Interval(0, 0.6, curve: Curves.easeInOut),
      )
      ..opacidad = CurvedAnimation(
        parent: control,
        curve: const Interval(0.3, 1, curve: Curves.easeOut),
        reverseCurve: const Interval(0.6, 1, curve: Curves.easeIn),
      );
  }

  void _entrar(_Bloque bloque) {
    _animable(bloque, desde: 0);
    bloque.control!.forward().ignore();
  }

  /// Empieza a irse. false si ya no queda nada que animar (se fue antes de
  /// que su espacio empezara a abrirse).
  bool _salir(_Bloque bloque) {
    if (!bloque.saliendo) {
      bloque.saliendo = true;
      _animable(bloque, desde: 1);
      bloque.control!.reverse().ignore();
    }
    return !bloque.control!.isDismissed;
  }

  void _alCambiarEstado(_Bloque bloque, AnimationStatus estado) {
    if (_actualizando || !mounted || !estado.isDismissed || !bloque.saliendo) {
      return;
    }
    setState(() => _bloques.remove(bloque));
    _soltarTrasCuadro(bloque);
  }

  // Se libera tras el cuadro que ya no lo construye (sus transiciones
  // todavía lo escuchan hasta entonces).
  void _soltarTrasCuadro(_Bloque bloque) {
    WidgetsBinding.instance.addPostFrameCallback((_) => bloque.soltar());
  }

  @override
  void dispose() {
    for (final bloque in _bloques) {
      bloque.soltar();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mide lo que miden sus bloques (como los hijos de una lista).
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final bloque in _bloques)
          _Presencia(
            key: bloque.clave,
            alto: bloque.alto ?? kAlwaysCompleteAnimation,
            opacidad: bloque.opacidad ?? kAlwaysCompleteAnimation,
            saliendo: bloque.saliendo,
            child: bloque.widget,
          ),
      ],
    );
  }
}

/// Envoltorio de un bloque de ColumnaAnimada: siempre el mismo tipo (el
/// bloque nunca se vuelve a montar al empezar o terminar de moverse).
class _Presencia extends StatelessWidget {
  const _Presencia({
    required this.alto,
    required this.opacidad,
    required this.saliendo,
    required this.child,
    super.key,
  });

  final Animation<double> alto;
  final Animation<double> opacidad;
  final bool saliendo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _Alto(
      alto: alto,
      child: FadeTransition(
        opacity: opacidad,
        child: IgnorePointer(
          ignoring: saliendo,
          child: ExcludeSemantics(
            excluding: saliendo,
            child: HeroMode(enabled: !saliendo, child: child),
          ),
        ),
      ),
    );
  }
}

/// Muestra la fracción `alto` de la altura del hijo, de arriba hacia abajo.
/// Solo recorta mientras el espacio no está completo.
class _Alto extends AnimatedWidget {
  const _Alto({required Animation<double> alto, required this.child})
    : super(listenable: alto);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fraccion = (listenable as Animation<double>).value;
    return ClipRect(
      clipBehavior: fraccion < 1 ? Clip.hardEdge : Clip.none,
      child: Align(
        alignment: AlignmentDirectional.topStart,
        heightFactor: math.max(fraccion, 0),
        child: child,
      ),
    );
  }
}

/// Un solo contorno dorado que brilla y se apaga alrededor de una tarjeta
/// que acaba de llegar (la entrega recién tomada): «esta ya es tuya».
/// Espera [retraso] desde el primer cuadro en que la tarjeta se ve (oculta
/// no empieza a contar). Se decide al montarse; con movimiento reducido no
/// brilla.
class ContornoDorado extends StatefulWidget {
  const ContornoDorado({
    required this.activo,
    required this.child,
    this.radio = 16,
    this.retraso = AppMovimiento.media,
    super.key,
  });

  final bool activo;
  final Widget child;

  /// Esquinas de la tarjeta.
  final double radio;

  /// Espera antes de brillar (por defecto, lo que tarda en abrirse su
  /// espacio).
  final Duration retraso;

  /// Lo que dura el brillo (900 ms): sube rápido y se apaga despacio.
  static final Duration brillo = AppMovimiento.relleno + AppMovimiento.media;

  @override
  State<ContornoDorado> createState() => _ContornoDoradoState();
}

class _ContornoDoradoState extends State<ContornoDorado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control;
  bool _brilla = false;
  bool _preparado = false;
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
    _brilla = widget.activo && !AppMovimiento.reducido(context);
    if (!_brilla) return;
    final total = widget.retraso + ContornoDorado.brillo;
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
    if (!_brilla) return widget.child;
    return RepaintBoundary(
      child: CustomPaint(
        foregroundPainter: _PintorContorno(
          avance: _control,
          inicio: _inicio,
          color: AppColors.pierDorado,
          radio: widget.radio,
        ),
        child: widget.child,
      ),
    );
  }
}

class _PintorContorno extends CustomPainter {
  _PintorContorno({
    required this.avance,
    required this.inicio,
    required this.color,
    required this.radio,
  }) : super(repaint: avance);

  final Animation<double> avance;
  final double inicio;
  final Color color;
  final double radio;

  @override
  void paint(Canvas canvas, Size size) {
    final valor = avance.value;
    if (valor <= inicio || valor >= 1 || size.isEmpty) return;
    final t = (valor - inicio) / (1 - inicio);
    final intensidad = t < 0.3
        ? Curves.easeOut.transform(t / 0.3)
        : 1 - Curves.easeInOut.transform((t - 0.3) / 0.7);
    final caja = Offset.zero & size;
    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    // El borde por dentro y un halo tenue por fuera (dos trazos, sin blur).
    canvas.drawRRect(
      RRect.fromRectAndRadius(caja.deflate(1), Radius.circular(radio - 1)),
      trazo..color = color.withValues(alpha: 0.9 * intensidad),
    );
    for (var paso = 1; paso <= 2; paso++) {
      final margen = 2.0 * paso;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          caja.inflate(margen - 1),
          Radius.circular(radio + margen - 1),
        ),
        trazo..color = color.withValues(alpha: 0.3 / paso * intensidad),
      );
    }
  }

  @override
  bool shouldRepaint(_PintorContorno oldDelegate) =>
      oldDelegate.inicio != inicio ||
      oldDelegate.color != color ||
      oldDelegate.radio != radio;
}

/// Campana que suena una vez: el hijo se mece tres veces, cada vez menos,
/// cuando [disparo] cambia a un valor no nulo (p. ej. el cliente ya fue
/// avisado). Solo pinta; con movimiento reducido no se mueve.
class Campaneo extends StatefulWidget {
  const Campaneo({required this.disparo, required this.child, super.key});

  final Object? disparo;
  final Widget child;

  @override
  State<Campaneo> createState() => _CampaneoState();
}

class _CampaneoState extends State<Campaneo>
    with SingleTickerProviderStateMixin {
  // Giro máximo en radianes (≈ 15°).
  static const double _amplitud = 0.26;

  late final AnimationController _control;

  @override
  void initState() {
    super.initState();
    _control = AnimationController(
      vsync: this,
      duration: AppMovimiento.relleno,
    );
  }

  @override
  void didUpdateWidget(Campaneo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.disparo != oldWidget.disparo &&
        widget.disparo != null &&
        conMovimiento(context)) {
      _control.forward(from: 0).ignore();
    }
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _control,
      child: widget.child,
      builder: (context, hijo) {
        final t = _control.value;
        // Seno de tres ciclos que se apaga: empieza y termina en 0.
        final giro = math.sin(t * math.pi * 6) * (1 - t) * _amplitud;
        return Transform.rotate(
          angle: giro,
          alignment: Alignment.topCenter,
          child: hijo,
        );
      },
    );
  }
}

/// Un solo latido (1 → 1.12 → 1) para llamar la atención sobre algo que el
/// repartidor no debe pasar por alto (el cobro en efectivo), [retraso]
/// después del primer cuadro en que se ve. Con movimiento reducido no late.
class PulsoAtencion extends StatefulWidget {
  const PulsoAtencion({
    required this.child,
    this.activo = true,
    this.retraso = Duration.zero,
    super.key,
  });

  final Widget child;
  final bool activo;
  final Duration retraso;

  @override
  State<PulsoAtencion> createState() => _PulsoAtencionState();
}

class _PulsoAtencionState extends State<PulsoAtencion>
    with SingleTickerProviderStateMixin {
  static final Animatable<double> _latido = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 1.12,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.12,
          end: 1,
        ).chain(CurveTween(curve: AppMovimiento.curvaRebote)),
        weight: 60,
      ),
    ],
  );

  late final AnimationController _control;
  Animation<double> _escala = kAlwaysCompleteAnimation;
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
    if (!widget.activo || AppMovimiento.reducido(context)) return;
    final total = widget.retraso + AppMovimiento.enfasis;
    _control.duration = total;
    _escala = _control
        .drive(
          CurveTween(
            curve: Interval(
              widget.retraso.inMicroseconds / total.inMicroseconds,
              1,
            ),
          ),
        )
        .drive(_latido);
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
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _escala, child: widget.child);
}

/// El número y el estado de una entrega vuelan de su tarjeta al detalle (y
/// de regreso, también con el gesto de regresar de iOS). El vuelo funde el
/// texto de la tarjeta con el del detalle, que tienen otro tamaño y a veces
/// otra letra, dentro de un Material transparente (sin él, un texto en vuelo
/// se pinta con el subrayado amarillo de los textos sin Material). Las
/// pestañas ocultas del panel no vuelan (HeroMode de AnimatedIndexedStack).
/// Con movimiento reducido no hay vuelo.
class HeroEntrega extends StatelessWidget {
  const HeroEntrega({required this.etiqueta, required this.child, super.key});

  final String etiqueta;

  /// Lo que se ve en reposo: el texto o el chip, ceñido a su tamaño.
  final Widget child;

  /// Etiqueta del número de la entrega [id].
  static String numero(String id) => 'entrega-numero-$id';

  /// Etiqueta del chip de estado de la entrega [id].
  static String estado(String id) => 'entrega-estado-$id';

  static final Animatable<double> _sale = Tween<double>(
    begin: 1,
    end: 0,
  ).chain(CurveTween(curve: const Interval(0.15, 0.85)));
  static final Animatable<double> _entra = CurveTween(
    curve: const Interval(0.15, 0.85),
  );

  @override
  Widget build(BuildContext context) {
    return HeroMode(
      enabled: !AppMovimiento.reducido(context),
      child: Hero(
        tag: etiqueta,
        // La curva de la página: el número llega junto con el detalle.
        curve: AppMovimiento.curvaPagina,
        transitionOnUserGestures: true,
        flightShuttleBuilder: _vuelo,
        child: child,
      ),
    );
  }

  static Widget _vuelo(
    BuildContext contextoVuelo,
    Animation<double> animacion,
    HeroFlightDirection direccion,
    BuildContext desde,
    BuildContext hacia,
  ) {
    // En push y en pop la animación vale 0 en la ruta de abajo (la lista) y
    // 1 en la de arriba (el detalle).
    final empuje = direccion == HeroFlightDirection.push;
    final deDesde = (desde.widget as Hero).child;
    final deHacia = (hacia.widget as Hero).child;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(
            opacity: animacion.drive(_sale),
            child: _Ajustado(child: empuje ? deDesde : deHacia),
          ),
          FadeTransition(
            opacity: animacion.drive(_entra),
            child: _Ajustado(child: empuje ? deHacia : deDesde),
          ),
        ],
      ),
    );
  }
}

/// El hijo a su tamaño natural, escalado para llenar la caja del vuelo.
class _Ajustado extends StatelessWidget {
  const _Ajustado({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => FittedBox(
    alignment: AlignmentDirectional.centerStart,
    child: child,
  );
}
