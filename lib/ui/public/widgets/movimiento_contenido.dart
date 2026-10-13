// lib/ui/public/widgets/movimiento_contenido.dart
//
// Piezas de movimiento propias de las pantallas de contenido: Nosotros,
// Contacto, Preguntas frecuentes, Marco legal, Reembolsos y Reseñas. Las
// generales (entradas, cambios en sitio, sacudidas, chispas…) viven en
// lib/ui/core/ui/movimiento; aquí solo lo que comparten estas pantallas.
// Todas respetan «reducir movimiento», terminan solas y no usan Timers.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';

// ── Ritmo de la página ───────────────────────────────────────────────────

/// Espera del contenido que se arma mientras su página (o su hoja, o su
/// diálogo) todavía llega: AppMovimiento.trasEmpuje, para que primero llegue
/// la superficie y después lo de adentro. Con la superficie ya quieta (datos
/// que llegaron después, un filtro nuevo) el contenido entra sin esperar.
Duration esperaDePagina(BuildContext context) {
  final ruta = ModalRoute.of(context);
  if (ruta == null) return Duration.zero;
  // En el primer cuadro de un push, el HeroController arma la página fuera
  // de escena para medir sus Heroes y mientras tanto su animación se ve
  // completa: también es una página que apenas llega.
  final llegada = ruta.animation;
  final llegando = ruta.offstage || (llegada != null && !llegada.isCompleted);
  return llegando ? AppMovimiento.trasEmpuje : Duration.zero;
}

/// Centra en su fila (un scroll horizontal de chips) el elemento de
/// [contexto], p. ej. el chip que se acaba de tocar. Solo se desplaza esa
/// fila, nunca la página que la contiene; con movimiento reducido salta.
void centrarEnSuFila(BuildContext contexto) {
  final caja = contexto.findRenderObject();
  final fila = Scrollable.maybeOf(contexto);
  if (caja == null || fila == null) return;
  fila.position
      .ensureVisible(
        caja,
        alignment: 0.5,
        duration: AppMovimiento.duracion(contexto, AppMovimiento.media),
        curve: AppMovimiento.curvaEstandar,
      )
      .ignore();
}

// ── Fotos ────────────────────────────────────────────────────────────────

/// Lo que devuelve el `frameBuilder` de una foto de red: la que llega de
/// internet aparece con un fundido corto (y, con [asentar], se acomoda de
/// 1.06 a 1, como una portada que se asienta); la que ya estaba en caché se
/// pinta tal cual desde el primer cuadro. El `errorBuilder` no pasa por
/// aquí: el respaldo sale sin fundido.
///
/// ```dart
/// frameBuilder: (_, foto, cuadro, sincrona) =>
///     FotoAlLlegar(foto: foto, cuadro: cuadro, sincrona: sincrona),
/// ```
class FotoAlLlegar extends StatelessWidget {
  const FotoAlLlegar({
    required this.foto,
    required this.cuadro,
    required this.sincrona,
    this.asentar = false,
    super.key,
  });

  final Widget foto;

  /// Cuadro ya decodificado (null mientras la foto no llega).
  final int? cuadro;

  /// Si la foto salió de la caché en el mismo cuadro.
  final bool sincrona;

  /// Además del fundido, un asentado lento de 1.06 a 1.
  final bool asentar;

  static const double _escalaInicial = 1.06;

  @override
  Widget build(BuildContext context) {
    if (sincrona) return foto;
    final llego = cuadro != null;
    final reducido = AppMovimiento.reducido(context);
    final asentada = asentar && !reducido
        ? AnimatedScale(
            scale: llego ? 1 : _escalaInicial,
            // Dos rellenos: lento, como una cámara que termina de detenerse.
            duration: AppMovimiento.relleno * 2,
            curve: AppMovimiento.curvaEntrada,
            child: foto,
          )
        : foto;
    return AnimatedOpacity(
      opacity: llego ? 1 : 0,
      duration: AppMovimiento.duracion(context, AppMovimiento.corta),
      curve: AppMovimiento.curvaEntrada,
      child: asentada,
    );
  }
}

// ── Tamaño ───────────────────────────────────────────────────────────────

/// AnimatedSize con el ritmo de la casa: lo que crece o se encoge empuja a
/// lo de alrededor con suavidad en vez de saltar. Con movimiento reducido el
/// cambio es inmediato (un milisegundo: AnimatedSize no acepta cero).
class TamanoSuave extends StatelessWidget {
  const TamanoSuave({
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

// ── Pop de entrada ───────────────────────────────────────────────────────

/// Pop de entrada de una pieza chica (una insignia, una burbuja, una
/// estrella): crece desde [escalaInicial] con un rebote corto mientras
/// aparece. Una sola vez, al montarse, desde un post-frame (en una ruta
/// tapada espera a verse); reconstruir nunca la repite. Con [animar] en
/// falso o movimiento reducido aparece ya en su lugar.
class PopAlEntrar extends StatefulWidget {
  const PopAlEntrar({
    required this.child,
    this.retraso = Duration.zero,
    this.escalaInicial = 0.6,
    this.animar = true,
    super.key,
  });

  final Widget child;

  /// Espera antes del pop (se lee al montarse).
  final Duration retraso;

  /// Escala con la que empieza (no recibe toques: es una pieza decorativa).
  final double escalaInicial;

  final bool animar;

  @override
  State<PopAlEntrar> createState() => _PopAlEntrarState();
}

class _PopAlEntrarState extends State<PopAlEntrar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control;
  Animation<double> _escala = kAlwaysCompleteAnimation;
  Animation<double> _opacidad = kAlwaysCompleteAnimation;
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
    if (!widget.animar || AppMovimiento.reducido(context)) {
      _control.value = 1;
      return;
    }
    final total = widget.retraso + AppMovimiento.enfasis;
    final inicio = widget.retraso.inMicroseconds / total.inMicroseconds;
    _control.duration = total;
    _escala = _control.drive(
      Tween<double>(begin: widget.escalaInicial, end: 1).chain(
        CurveTween(
          curve: Interval(inicio, 1, curve: AppMovimiento.curvaRebote),
        ),
      ),
    );
    // Se ve desde el principio del pop: el rebote ya ocurre a la vista.
    _opacidad = _control.drive(
      CurveTween(
        curve: Interval(
          inicio,
          inicio + (1 - inicio) * 0.4,
          curve: Curves.easeOut,
        ),
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
      alwaysIncludeSemantics: true,
      child: ScaleTransition(scale: _escala, child: widget.child),
    );
  }
}

// ── Estrellas de calificación ────────────────────────────────────────────

/// Una estrella de calificación (escribir y editar reseña). El ícono lo
/// cambia la pantalla al instante (las pruebas cuentan estrellas llenas);
/// esta pieza solo lo mueve: al subir la calificación, las estrellas que se
/// encienden dan un pop una tras otra (un escalón de cascada entre cada una)
/// y la tocada se endereza desde un giro corto; al bajarla, las que se apagan
/// se encogen apenas y regresan. Solo pinta: el área del toque no cambia.
class EstrellaAnimada extends StatefulWidget {
  const EstrellaAnimada({
    required this.indice,
    required this.calificacion,
    required this.child,
    super.key,
  });

  /// Lugar de la estrella (0 = la primera).
  final int indice;

  /// Estrellas llenas ahora (0 a 5).
  final int calificacion;

  /// El ícono de la estrella tal cual.
  final Widget child;

  @override
  State<EstrellaAnimada> createState() => _EstrellaAnimadaState();
}

enum _GestoEstrella { encender, apagar }

class _EstrellaAnimadaState extends State<EstrellaAnimada>
    with SingleTickerProviderStateMixin {
  // El ritmo de la casa: un escalón de cascada entre estrellas y la
  // duración de los pops de íconos.
  static const Duration _separacion = AppMovimiento.paso;
  static const Duration _pop = AppMovimiento.enfasis;

  // Crece de más, se pasa un poco hacia abajo y asienta en 1.
  static final Animatable<double> _escalaEncender = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 1.28,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.28,
          end: 0.96,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0.96,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ],
  );

  // Se encoge apenas y regresa.
  static final Animatable<double> _escalaApagar = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 0.86,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0.86,
          end: 1,
        ).chain(CurveTween(curve: AppMovimiento.curvaRebote)),
        weight: 60,
      ),
    ],
  );

  // −8° (en radianes) que se enderezan con un rebote.
  static const double _giroInicial = -8 * math.pi / 180;

  late final AnimationController _control;
  _GestoEstrella _gesto = _GestoEstrella.encender;
  double _inicio = 0;
  bool _gira = false;

  @override
  void initState() {
    super.initState();
    _control = AnimationController(vsync: this, value: 1);
  }

  @override
  void didUpdateWidget(EstrellaAnimada oldWidget) {
    super.didUpdateWidget(oldWidget);
    final antes = oldWidget.calificacion;
    final ahora = widget.calificacion;
    final i = widget.indice;
    if (antes == ahora || AppMovimiento.reducido(context)) return;
    if (ahora > antes && i >= antes && i < ahora) {
      // Se enciende: en fila, de la primera nueva a la tocada.
      final espera = _separacion * (i - antes);
      final total = espera + _pop;
      _gesto = _GestoEstrella.encender;
      _inicio = espera.inMicroseconds / total.inMicroseconds;
      _gira = i == ahora - 1;
      _control
        ..duration = total
        ..forward(from: 0).ignore();
    } else if (ahora < antes && i >= ahora && i < antes) {
      _gesto = _GestoEstrella.apagar;
      _inicio = 0;
      _gira = false;
      _control
        ..duration = AppMovimiento.corta
        ..forward(from: 0).ignore();
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
      builder: (context, estrella) {
        final t = _control.value;
        if (t >= 1 || t <= _inicio) return estrella!;
        final local = (t - _inicio) / (1 - _inicio);
        final escala = _gesto == _GestoEstrella.encender
            ? _escalaEncender.transform(local)
            : _escalaApagar.transform(local);
        final giro = _gira
            ? _giroInicial * (1 - AppMovimiento.curvaRebote.transform(local))
            : 0.0;
        return Transform.rotate(
          angle: giro,
          child: Transform.scale(scale: escala, child: estrella),
        );
      },
    );
  }
}

// ── Insignia de éxito ────────────────────────────────────────────────────

/// La insignia de los diálogos de éxito (mensaje enviado, reseña
/// publicada): el halo se abre, el disco verde cae con un rebote y la
/// palomita llega al último enderezándose. Con [conChispas] (una reseña
/// publicada) sale además una ráfaga chica de chispas cuando el disco ya
/// cayó. Una sola vez; con movimiento reducido aparece ya completa y sin
/// chispas.
class InsigniaExito extends StatefulWidget {
  const InsigniaExito({
    this.opacidadHalo = 0.12,
    this.conChispas = false,
    super.key,
  });

  /// Opacidad del gris del halo (cada diálogo conserva la suya).
  final double opacidadHalo;

  final bool conChispas;

  @override
  State<InsigniaExito> createState() => _InsigniaExitoState();
}

class _InsigniaExitoState extends State<InsigniaExito>
    with SingleTickerProviderStateMixin {
  static final Animatable<double> _escalaHalo =
      Tween<double>(
        begin: 0.5,
        end: 1,
      ).chain(
        CurveTween(
          curve: const Interval(0, 0.55, curve: AppMovimiento.curvaEntrada),
        ),
      );
  static final Animatable<double> _opacidadHaloTramo = CurveTween(
    curve: const Interval(0, 0.35, curve: Curves.easeOut),
  );
  static final Animatable<double> _escalaDisco =
      Tween<double>(
        begin: 0.4,
        end: 1,
      ).chain(
        CurveTween(
          curve: const Interval(0.1, 0.7, curve: AppMovimiento.curvaRebote),
        ),
      );
  static final Animatable<double> _opacidadDisco = CurveTween(
    curve: const Interval(0.1, 0.3, curve: Curves.easeOut),
  );
  static final Animatable<double> _escalaPalomita =
      Tween<double>(
        begin: 0.3,
        end: 1,
      ).chain(
        CurveTween(
          curve: const Interval(0.45, 1, curve: AppMovimiento.curvaRebote),
        ),
      );
  // −20° en vueltas (RotationTransition) que se enderezan.
  static final Animatable<double> _giroPalomita =
      Tween<double>(
        begin: -20 / 360,
        end: 0,
      ).chain(
        CurveTween(
          curve: const Interval(0.45, 1, curve: AppMovimiento.curvaRebote),
        ),
      );
  static final Animatable<double> _opacidadPalomita = CurveTween(
    curve: const Interval(0.45, 0.6, curve: Curves.easeOut),
  );

  // Las chispas salen cuando el disco ya cayó (cerca del 60 % del pop).
  static final Duration _retrasoChispas = AppMovimiento.enfasis * 0.6;

  late final AnimationController _control;
  bool _preparada = false;
  bool _chispas = false;

  @override
  void initState() {
    super.initState();
    _control = AnimationController(
      vsync: this,
      duration: AppMovimiento.enfasis,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparada) return;
    _preparada = true;
    if (AppMovimiento.reducido(context)) {
      _control.value = 1;
      return;
    }
    _chispas = widget.conChispas;
    // Desde un post-frame, como las entradas: arranca con el diálogo ya
    // montado.
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
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        FadeTransition(
          opacity: _control.drive(_opacidadHaloTramo),
          child: ScaleTransition(
            scale: _control.drive(_escalaHalo),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(
                  alpha: widget.opacidadHalo,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        FadeTransition(
          opacity: _control.drive(_opacidadDisco),
          child: ScaleTransition(
            scale: _control.drive(_escalaDisco),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.pierVerde,
                shape: BoxShape.circle,
              ),
              child: FadeTransition(
                opacity: _control.drive(_opacidadPalomita),
                child: RotationTransition(
                  turns: _control.drive(_giroPalomita),
                  child: ScaleTransition(
                    scale: _control.drive(_escalaPalomita),
                    child: const Icon(
                      LucideIcons.check,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_chispas)
          Positioned.fill(
            child: Chispas(cantidad: 16, retraso: _retrasoChispas),
          ),
      ],
    );
  }
}

// ── Sacudidas de validación ──────────────────────────────────────────────

/// Sacude a [child] cada vez que [aviso] cambia: un contador que la
/// pantalla sube cuando ese campo no pasó la validación. Solo se reconstruye
/// la sacudida, no la pantalla; el mensaje de error es el de siempre.
class SacudidaConAviso extends StatelessWidget {
  const SacudidaConAviso({
    required this.aviso,
    required this.child,
    super.key,
  });

  final ValueListenable<int> aviso;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: aviso,
      child: child,
      builder: (context, veces, campo) => Sacudida(
        disparo: veces == 0 ? null : veces,
        child: campo ?? const SizedBox.shrink(),
      ),
    );
  }
}

// ── Cifras y colores que cambian en sitio ────────────────────────────────

/// Un conteo que rueda como odómetro dentro de su propia ventanita: si
/// sube, el nuevo entra desde abajo; si baja, desde arriba. Nunca anima al
/// montarse y el texto final es exactamente '$valor'.
class CuentaRodante extends StatefulWidget {
  const CuentaRodante({required this.valor, this.estilo, super.key});

  final int valor;
  final TextStyle? estilo;

  @override
  State<CuentaRodante> createState() => _CuentaRodanteState();
}

class _CuentaRodanteState extends State<CuentaRodante> {
  int _direccion = 1;

  @override
  void didUpdateWidget(CuentaRodante oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.valor != oldWidget.valor) {
      _direccion = widget.valor > oldWidget.valor ? 1 : -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = '${widget.valor}';
    // El recorte hace de ventanita: el número que entra y el que sale no
    // se pintan fuera de la línea del texto.
    return ClipRect(
      child: CambioAnimado(
        tipo: TipoCambio.subir,
        direccion: _direccion,
        child: Text(
          texto,
          key: ValueKey<String>(texto),
          style: widget.estilo,
        ),
      ),
    );
  }
}

/// El estilo de texto (color, grosor) de lo de adentro pasa al nuevo junto
/// con el fondo de su chip o píldora, en vez de saltar antes que él. Se
/// mezcla con el DefaultTextStyle de su lugar, igual que un Text con
/// `style`.
class EstiloTextoSuave extends StatelessWidget {
  const EstiloTextoSuave({
    required this.estilo,
    required this.child,
    super.key,
  });

  final TextStyle estilo;

  /// Textos sin estilo propio (lo heredan de aquí).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      style: DefaultTextStyle.of(context).style.merge(estilo),
      duration: AppMovimiento.duracion(context, AppMovimiento.corta),
      curve: AppMovimiento.curvaEstandar,
      child: child,
    );
  }
}

/// Un texto con [EstiloTextoSuave]: su color cambia junto con el fondo.
class TextoColorSuave extends StatelessWidget {
  const TextoColorSuave(this.texto, {required this.estilo, super.key});

  final String texto;
  final TextStyle estilo;

  @override
  Widget build(BuildContext context) {
    return EstiloTextoSuave(estilo: estilo, child: Text(texto));
  }
}

/// Un ícono que da un pop y se endereza desde un giro corto cuando [activo]
/// pasa de falso a verdadero (el pulgar de «útil» al marcarlo). Montarse ya
/// activo no anima y desmarcar tampoco. Con movimiento reducido, quieto. El
/// hijo conserva su estado durante el pop (p. ej. un IconoColorSuave sigue
/// fundiendo su color).
class PopAlActivar extends StatefulWidget {
  const PopAlActivar({required this.activo, required this.child, super.key});

  final bool activo;
  final Widget child;

  @override
  State<PopAlActivar> createState() => _PopAlActivarState();
}

class _PopAlActivarState extends State<PopAlActivar>
    with SingleTickerProviderStateMixin {
  // Crece, se recoge un poco y asienta en 1.
  static final Animatable<double> _pop = TweenSequence<double>(
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
          end: 0.9,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0.9,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
    ],
  );

  // −14° (en radianes): el pulgar se inclina hacia atrás y se endereza.
  static const double _giroInicial = -14 * math.pi / 180;

  late final AnimationController _control;

  @override
  void initState() {
    super.initState();
    _control = AnimationController(
      vsync: this,
      duration: AppMovimiento.enfasis,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(PopAlActivar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.activo &&
        widget.activo &&
        !AppMovimiento.reducido(context)) {
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
      builder: (context, icono) {
        // Siempre el mismo árbol (en reposo, sin giro y a escala 1): si los
        // Transform aparecieran solo durante el pop, el ícono se montaría de
        // nuevo y perdería su propio estado (el fundido de su color).
        final t = _control.value;
        final quieto = t >= 1;
        return Transform.rotate(
          angle: quieto
              ? 0
              : _giroInicial * (1 - AppMovimiento.curvaRebote.transform(t)),
          child: Transform.scale(
            scale: quieto ? 1 : _pop.transform(t),
            child: icono,
          ),
        );
      },
    );
  }
}

/// Ícono cuyo color pasa al nuevo con un fundido corto, junto con el fondo
/// del chip o de la píldora donde está.
class IconoColorSuave extends StatelessWidget {
  const IconoColorSuave(
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

// ── Lo que acaba de llegar ───────────────────────────────────────────────

/// Un aro dorado que sale del borde de una tarjeta recién llegada (una
/// solicitud nueva al recargar, la reseña que el cliente acaba de publicar)
/// y se apaga mientras se abre: «aquí está lo tuyo». Una sola vez, después
/// de la entrada de la tarjeta; [activo] se lee al montarse. Pinta encima
/// del hijo sin tocar su layout; con movimiento reducido no hay aro.
class ResaltadoUnaVez extends StatefulWidget {
  const ResaltadoUnaVez({
    required this.activo,
    required this.radio,
    required this.child,
    super.key,
  });

  final bool activo;

  /// Esquinas de la tarjeta.
  final BorderRadius radio;

  final Widget child;

  @override
  State<ResaltadoUnaVez> createState() => _ResaltadoUnaVezState();
}

class _ResaltadoUnaVezState extends State<ResaltadoUnaVez>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control;
  bool _preparado = false;
  bool _resalta = false;
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
    if (!widget.activo || AppMovimiento.reducido(context)) return;
    _resalta = true;
    // Primero termina de entrar la tarjeta; luego el aro (dos rellenos).
    const espera = AppMovimiento.entrada;
    final total = espera + AppMovimiento.relleno * 2;
    _inicio = espera.inMicroseconds / total.inMicroseconds;
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
    if (!_resalta) return widget.child;
    return CustomPaint(
      foregroundPainter: _PintorResalte(
        avance: _control,
        inicio: _inicio,
        radio: widget.radio,
        color: AppColors.pierDorado,
      ),
      // La tarjeta en su propia capa: el aro se repinta en cada cuadro sin
      // volver a pintar la tarjeta.
      child: RepaintBoundary(child: widget.child),
    );
  }
}

class _PintorResalte extends CustomPainter {
  _PintorResalte({
    required this.avance,
    required this.inicio,
    required this.radio,
    required this.color,
  }) : super(repaint: avance);

  final Animation<double> avance;
  final double inicio;
  final BorderRadius radio;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final t = avance.value;
    if (t <= inicio || t >= 1 || size.isEmpty) return;
    final local = (t - inicio) / (1 - inicio);
    // El aro nace en el borde, se abre unos dp y se apaga.
    final abre =
        AppMovimiento.distanciaCorta *
        0.75 *
        AppMovimiento.curvaEntrada.transform(local);
    final alfa = (1 - Curves.easeIn.transform(local)) * 0.9;
    canvas.drawRRect(
      radio.toRRect(Offset.zero & size).inflate(abre),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1 - 0.6 * local)
        ..color = color.withValues(alpha: alfa),
    );
  }

  @override
  bool shouldRepaint(_PintorResalte oldDelegate) =>
      oldDelegate.inicio != inicio ||
      oldDelegate.radio != radio ||
      oldDelegate.color != color;
}

// ── Entradas que esperan a verse (pantallas de contenido fijo) ───────────

/// Alrededor de una pantalla con scroll y contenido fijo (Nosotros). Los
/// bloques [EntradaAlVer] de adentro entran una sola vez: los que ya se ven
/// cuando la pantalla llega, en cascada después de [retrasoLlegada]; los
/// demás esperan a que el scroll los traiga y entonces entran, en cascada de
/// arriba abajo, en lugar de gastar su entrada fuera de la pantalla.
class VistaRevelada extends StatefulWidget {
  const VistaRevelada({
    required this.child,
    this.retrasoLlegada = Duration.zero,
    super.key,
  });

  final Widget child;

  /// Espera de la primera tanda (la que ya se ve al llegar), p. ej.
  /// AppMovimiento.trasEmpuje en una página recién empujada.
  final Duration retrasoLlegada;

  @override
  State<VistaRevelada> createState() => _VistaReveladaState();
}

class _VistaReveladaState extends State<VistaRevelada> {
  // Las montadas en este cuadro, en el orden en que se construyeron: de
  // arriba abajo.
  final List<_EntradaAlVerState> _tanda = <_EntradaAlVerState>[];
  final Set<_EntradaAlVerState> _esperando = <_EntradaAlVerState>{};
  bool _llego = false;
  bool _revisionPendiente = false;
  int _turnoDeRegistro = 0;

  /// Anota un bloque recién montado y le da su lugar en el orden.
  int _registrar(_EntradaAlVerState entrada) {
    if (_tanda.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(_soltarTanda);
    }
    _tanda.add(entrada);
    return _turnoDeRegistro++;
  }

  void _olvidar(_EntradaAlVerState entrada) {
    _tanda.remove(entrada);
    _esperando.remove(entrada);
  }

  // Lo que se montó en un mismo cuadro: lo que ya se ve entra en cascada y
  // lo demás espera a que el scroll lo traiga.
  void _soltarTanda(Duration _) {
    final tanda = List<_EntradaAlVerState>.of(_tanda);
    _tanda.clear();
    if (!mounted) return;
    final espera = _llego ? Duration.zero : widget.retrasoLlegada;
    _llego = true;
    final area = _area();
    var turno = 0;
    for (final entrada in tanda) {
      if (!entrada.mounted) continue;
      if (entrada._seVe(area)) {
        entrada._empezar(espera + AppMovimiento.retrasoCascada(turno++));
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

  // Después del layout: las que ya se ven entran en cascada de arriba abajo
  // (un deslizamiento rápido destapa varias a la vez).
  void _revisar(Duration _) {
    _revisionPendiente = false;
    if (!mounted) return;
    final area = _area();
    final visibles =
        [
          for (final entrada in _esperando)
            if (entrada.mounted && entrada._seVe(area)) entrada,
        ]..sort((a, b) {
          final porAltura = a._arriba().compareTo(b._arriba());
          return porAltura != 0 ? porAltura : a._orden.compareTo(b._orden);
        });
    var turno = 0;
    for (final entrada in visibles) {
      _esperando.remove(entrada);
      entrada._empezar(AppMovimiento.retrasoCascada(turno++));
    }
  }

  /// La parte de la pantalla donde se ve el scroll.
  Rect? _area() {
    final caja = context.findRenderObject();
    if (caja is! RenderBox || !caja.hasSize) return null;
    return caja.localToGlobal(Offset.zero) & caja.size;
  }

  bool _alAvisar(Notification aviso) {
    // Solo el scroll de la pantalla (profundidad 0), no uno de adentro.
    final propio =
        (aviso is ScrollNotification && aviso.depth == 0) ||
        (aviso is ScrollMetricsNotification && aviso.depth == 0);
    if (propio) _programarRevision();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<Notification>(
      onNotification: _alAvisar,
      child: _AlcanceRevelado(estado: this, child: widget.child),
    );
  }
}

class _AlcanceRevelado extends InheritedWidget {
  const _AlcanceRevelado({required this.estado, required super.child});

  final _VistaReveladaState estado;

  @override
  bool updateShouldNotify(_AlcanceRevelado oldWidget) => false;
}

/// Entrada de un bloque que espera a verse: fundido más una subida corta en
/// dp (y una escala inicial, si se pide). Dentro de una [VistaRevelada]
/// entra cuando el scroll lo trae; sola, en cuanto se monta. Se reproduce
/// una sola vez, nunca bloquea toques y los lectores de pantalla la ven
/// desde el principio. Lo de adentro puede moverse a su compás con
/// [EntradaAlVer.avanceDe] (un ícono que da un pop, una cifra que cuenta).
class EntradaAlVer extends StatefulWidget {
  const EntradaAlVer({
    required this.child,
    this.desplazamiento = const Offset(0, AppMovimiento.distancia),
    this.escalaInicial = 1,
    super.key,
  });

  final Widget child;

  /// Desde dónde llega, en dp (máximo 24).
  final Offset desplazamiento;

  /// Escala con la que empieza (0.85 o más).
  final double escalaInicial;

  /// El avance (0 a 1) de la entrada del bloque que contiene a [context]:
  /// 0 mientras espera, 1 en su lugar. Null fuera de un EntradaAlVer.
  static Animation<double>? avanceDe(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_CompasEntrada>()?.avance;

  @override
  State<EntradaAlVer> createState() => _EntradaAlVerState();
}

class _EntradaAlVerState extends State<EntradaAlVer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control;
  // Los tramos se fijan al empezar (la espera se decide en ese momento); las
  // animaciones son siempre las mismas, así que no hace falta reconstruir.
  final CurveTween _tramoOpacidad = CurveTween(curve: Curves.linear);
  final CurveTween _tramoAvance = CurveTween(curve: Curves.linear);
  final CurveTween _tramoProgreso = CurveTween(curve: Curves.linear);
  late final Animation<double> _opacidad;
  late final Animation<double> _avance;
  late final Animation<double> _progreso;

  _VistaReveladaState? _vista;
  bool _preparada = false;
  bool _empezada = false;
  int _orden = 0;

  @override
  void initState() {
    super.initState();
    _control = AnimationController(vsync: this, value: 1);
    _opacidad = _control.drive(_tramoOpacidad);
    _avance = _control.drive(_tramoAvance);
    _progreso = _control.drive(_tramoProgreso);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparada) return;
    _preparada = true;
    // Se decide una sola vez, al montarse: reconstruir nunca la repite.
    if (AppMovimiento.reducido(context)) return; // Quieta en su lugar.
    _control.value = 0;
    final vista = context
        .getInheritedWidgetOfExactType<_AlcanceRevelado>()
        ?.estado;
    if (vista != null) {
      _vista = vista;
      _orden = vista._registrar(this);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _empezar(Duration.zero),
    );
  }

  void _empezar(Duration espera) {
    if (!mounted || _empezada) return;
    _empezada = true;
    final total = espera + AppMovimiento.entrada;
    final inicio = espera.inMicroseconds / total.inMicroseconds;
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
    _tramoProgreso.curve = Interval(inicio, 1);
    _control
      ..duration = total
      ..forward(from: 0).ignore();
  }

  /// Si ya se ve en [area]: su borde de arriba pasó del 90 % de la vista, o
  /// cabe completo en ella (lo último de la página puede no subir hasta ese
  /// 90 % ni con el scroll al tope, y aun así se ve entero).
  bool _seVe(Rect? area) {
    final caja = context.findRenderObject();
    // Sin medidas no se sabe: mejor que entre a que se quede invisible.
    if (area == null || caja is! RenderBox || !caja.hasSize) return true;
    final arriba = caja.localToGlobal(Offset.zero).dy;
    final abajo = arriba + caja.size.height;
    return abajo > area.top &&
        (arriba < area.top + area.height * 0.9 || abajo <= area.bottom);
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
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CompasEntrada(
      avance: _progreso,
      child: FadeTransition(
        opacity: _opacidad,
        // Los lectores de pantalla ven el bloque aunque espere su entrada.
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

class _CompasEntrada extends InheritedWidget {
  const _CompasEntrada({required this.avance, required super.child});

  final Animation<double> avance;

  @override
  bool updateShouldNotify(_CompasEntrada oldWidget) =>
      oldWidget.avance != avance;
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

/// Un ícono que da un pop al compás de la entrada de su bloque
/// ([EntradaAlVer]): crece desde 0.6 con rebote mientras el bloque sube.
/// Fuera de un bloque, o con movimiento reducido, se queda quieto.
class PopAlCompas extends StatelessWidget {
  const PopAlCompas({required this.child, super.key});

  final Widget child;

  static final Animatable<double> _escala =
      Tween<double>(
        begin: 0.6,
        end: 1,
      ).chain(
        CurveTween(
          curve: const Interval(0.15, 0.85, curve: AppMovimiento.curvaRebote),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final avance = EntradaAlVer.avanceDe(context);
    if (avance == null || AppMovimiento.reducido(context)) return child;
    return ScaleTransition(scale: avance.drive(_escala), child: child);
  }
}

/// Una cifra que se cuenta al aparecer: «100%» va de 0 % a 100 % y
/// «+ 5 años» de 0 a 5, y termina exactamente en [texto]. Lo que no es un
/// número (❤️) late dos veces. Empieza cuando su bloque [EntradaAlVer]
/// empieza a entrar (sin bloque, en cuanto se monta). Los lectores de
/// pantalla leen siempre [texto]; con movimiento reducido se muestra ya
/// final.
class CifraQueCuenta extends StatefulWidget {
  const CifraQueCuenta({required this.texto, this.estilo, super.key});

  final String texto;
  final TextStyle? estilo;

  @override
  State<CifraQueCuenta> createState() => _CifraQueCuentaState();
}

class _CifraQueCuentaState extends State<CifraQueCuenta>
    with SingleTickerProviderStateMixin {
  // Prefijo, un número entero completo (sin separadores de miles ni
  // decimales) y lo demás.
  static final RegExp _numero = RegExp(r'^(\D*)(\d+)(?!\d)(?![.,]\d)(.*)$');

  // Dos latidos: crece, se recoge, crece menos y asienta.
  static final Animatable<double> _latido = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 1.25,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 18,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.25,
          end: 0.95,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 18,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0.95,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 18,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.15,
          end: 1,
        ).chain(CurveTween(curve: AppMovimiento.curvaRebote)),
        weight: 46,
      ),
    ],
  );

  late final AnimationController _control;
  Animation<double>? _guia;
  bool _preparada = false;

  @override
  void initState() {
    super.initState();
    // Un relleno y medio: la cifra termina de contar después de que su
    // tarjeta ya llegó.
    _control = AnimationController(
      vsync: this,
      duration: AppMovimiento.relleno * 1.5,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparada) return;
    _preparada = true;
    if (AppMovimiento.reducido(context)) {
      _control.value = 1;
      return;
    }
    final guia = EntradaAlVer.avanceDe(context);
    if (guia == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _arrancar());
    } else if (guia.value >= 1) {
      // Su bloque ya estaba en su lugar (o no anima): cifra final.
      _control.value = 1;
    } else {
      _guia = guia..addListener(_alAvanzarGuia);
    }
  }

  void _alAvanzarGuia() {
    final guia = _guia;
    if (guia == null || guia.value <= 0) return;
    guia.removeListener(_alAvanzarGuia);
    _guia = null;
    _arrancar();
  }

  void _arrancar() {
    if (mounted && _control.isDismissed) _control.forward().ignore();
  }

  @override
  void dispose() {
    _guia?.removeListener(_alAvanzarGuia);
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coincide = _numero.firstMatch(widget.texto);
    // Una cifra que no cabe en un entero (algo raro capturado en el panel)
    // tampoco se cuenta: late, como lo que no es número, en vez de romper
    // la pantalla.
    final meta = coincide == null ? null : int.tryParse(coincide.group(2)!);
    final Widget cifra;
    if (coincide == null || meta == null) {
      cifra = ScaleTransition(
        scale: _control.drive(_latido),
        child: Text(widget.texto, style: widget.estilo),
      );
    } else {
      // Cifras tabulares: la cifra no baila de ancho mientras cuenta.
      final base = widget.estilo ?? const TextStyle();
      final estilo = base.copyWith(
        fontFeatures: [
          ...?base.fontFeatures,
          const FontFeature.tabularFigures(),
        ],
      );
      cifra = AnimatedBuilder(
        animation: _control,
        builder: (context, _) {
          final t = _control.value;
          final texto = t >= 1
              ? widget.texto
              : '${coincide.group(1)}'
                    '${(meta * AppMovimiento.curvaEntrada.transform(t)).round()}'
                    '${coincide.group(3)}';
          return Text(texto, style: estilo);
        },
      );
    }
    return Semantics(label: widget.texto, excludeSemantics: true, child: cifra);
  }
}
