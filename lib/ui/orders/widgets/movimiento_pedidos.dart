// lib/ui/orders/widgets/movimiento_pedidos.dart
//
// Piezas de movimiento que comparten «Mis Pedidos», el detalle de un pedido,
// «Notificaciones» y «Mis Favoritos». Las generales (entradas, cambios en
// sitio, Hero de la foto, vuelo al carrito…) viven en
// lib/ui/core/ui/movimiento; aquí solo lo que estas pantallas repiten. Todas
// respetan «reducir movimiento», terminan solas y no usan Timers.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';

/// Cuánto debe esperar la entrada de un bloque que se monta en este momento
/// (el `retraso` de EntradaSuave), según dónde está su pantalla:
///
/// * en una pestaña oculta o bajo otra ruta (sus tickers están apagados): a
///   que se vea, AppMovimiento.trasPestana;
/// * en una página que todavía está llegando (un push en curso): a que
///   aterrice, AppMovimiento.trasEmpuje;
/// * en una pantalla que ya está a la vista (datos que llegan después): nada.
///
/// EntradaSuave lee su retraso una sola vez, al montarse, así que basta con
/// pasarle lo que esto devuelve en cada build.
Duration esperaDeLlegada(BuildContext context) {
  // Se lee el TickerMode sin depender de él: con valuesOf, cada cambio de
  // pestaña (o cada ruta que tapa la pantalla) reconstruiría entera a la
  // pantalla que preguntó, y el valor solo importa al montar.
  if (!TickerMode.getValuesNotifier(context).value.enabled) {
    return AppMovimiento.trasPestana;
  }
  final ruta = ModalRoute.of(context);
  // Recién empujada, en su primer cuadro el HeroController la mide fuera de
  // escena (offstage) y mientras tanto su animación se ve completa; en los
  // cuadros siguientes avanza.
  if (ruta != null &&
      (ruta.offstage || ruta.animation?.status == AnimationStatus.forward)) {
    return AppMovimiento.trasEmpuje;
  }
  return Duration.zero;
}

/// AnimatedSize con el ritmo de la casa: lo que crece o se encoge empuja a lo
/// de alrededor con suavidad en vez de saltar. Con movimiento reducido el
/// cambio es inmediato (un milisegundo: AnimatedSize no acepta duración
/// cero).
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
      curve: AppMovimiento.curvaEnfasis,
      alignment: alineacion,
      child: child,
    );
  }
}

/// Texto que rueda como odómetro al cambiar, dentro de su propia ventanita:
/// con [direccion] 1 el nuevo entra desde abajo y el anterior se va hacia
/// arriba; con -1, al revés. Al montarse no anima y el texto final es
/// exactamente [texto].
class TextoRodante extends StatelessWidget {
  const TextoRodante(
    this.texto, {
    this.estilo,
    this.direccion = 1,
    this.alineacion = AlignmentDirectional.centerStart,
    super.key,
  });

  final String texto;
  final TextStyle? estilo;
  final int direccion;
  final AlignmentGeometry alineacion;

  @override
  Widget build(BuildContext context) {
    // El recorte es la ventanita: lo que entra y lo que sale no se pintan
    // fuera de la línea del texto.
    return ClipRect(
      child: CambioAnimado(
        tipo: TipoCambio.subir,
        direccion: direccion,
        alineacion: alineacion,
        child: Text(texto, key: ValueKey<String>(texto), style: estilo),
      ),
    );
  }
}

/// Un contador que rueda hacia arriba cuando [valor] sube y hacia abajo
/// cuando baja («2 activos» → «1 activo»). [texto] es cómo se muestra.
class ContadorRodante extends StatefulWidget {
  const ContadorRodante({
    required this.valor,
    required this.texto,
    this.estilo,
    this.alineacion = AlignmentDirectional.centerStart,
    super.key,
  });

  final num valor;
  final String texto;
  final TextStyle? estilo;
  final AlignmentGeometry alineacion;

  @override
  State<ContadorRodante> createState() => _ContadorRodanteState();
}

class _ContadorRodanteState extends State<ContadorRodante> {
  int _direccion = 1;

  @override
  void didUpdateWidget(ContadorRodante oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.valor != oldWidget.valor) {
      _direccion = widget.valor > oldWidget.valor ? 1 : -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextoRodante(
      widget.texto,
      estilo: widget.estilo,
      direccion: _direccion,
      alineacion: widget.alineacion,
    );
  }
}

/// Vaivén de campana, en vueltas (para un RotationTransition): [ciclos]
/// oscilaciones que se apagan; empieza y termina en 0.
class Balanceo extends Animatable<double> {
  const Balanceo({this.amplitud = 0.04, this.ciclos = 3});

  /// Giro máximo en vueltas (0.04 ≈ 14°).
  final double amplitud;
  final int ciclos;

  @override
  double transform(double t) =>
      math.sin(t * math.pi * 2 * ciclos) * (1 - t) * amplitud;
}

/// Un gesto decorativo que se reproduce UNA vez al montarse (un latido, un
/// vaivén, una inclinación que se endereza): espera [retraso] desde el primer
/// cuadro en que se ve (en una pestaña oculta o bajo otra ruta no empieza a
/// contar) y entrega a [builder] su avance de 0 a 1. Reconstruir no lo
/// repite. Con movimiento reducido el avance vale 1 desde el principio: el
/// builder debe dejar en 1 el estado de reposo.
class MovimientoUnaVez extends StatefulWidget {
  const MovimientoUnaVez({
    required this.duracion,
    required this.builder,
    this.retraso = Duration.zero,
    this.child,
    super.key,
  });

  final Duration duracion;
  final Widget Function(
    BuildContext context,
    Animation<double> avance,
    Widget? child,
  )
  builder;
  final Duration retraso;

  /// Parte fija que el builder recibe sin reconstruirse.
  final Widget? child;

  @override
  State<MovimientoUnaVez> createState() => _MovimientoUnaVezState();
}

class _MovimientoUnaVezState extends State<MovimientoUnaVez>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control;
  Animation<double> _avance = kAlwaysCompleteAnimation;
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
    if (AppMovimiento.reducido(context) || widget.duracion <= Duration.zero) {
      return;
    }
    final total = widget.retraso + widget.duracion;
    _control.duration = total;
    _avance = _control.drive(
      CurveTween(
        curve: Interval(
          widget.retraso.inMicroseconds / total.inMicroseconds,
          1,
        ),
      ),
    );
    // Desde un post-frame: oculto, espera a mostrarse.
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
      widget.builder(context, _avance, widget.child);
}

/// Lo que devuelve el `frameBuilder` de una foto de red: la que llega de
/// internet aparece con un fundido corto en vez de saltar; la que ya estaba
/// en caché (volver del detalle, scroll de regreso) se pinta tal cual desde
/// el primer cuadro.
///
/// ```dart
/// frameBuilder: (_, foto, cuadro, sincrona) =>
///     FotoQueAparece(foto: foto, cuadro: cuadro, sincrona: sincrona),
/// ```
class FotoQueAparece extends StatelessWidget {
  const FotoQueAparece({
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
