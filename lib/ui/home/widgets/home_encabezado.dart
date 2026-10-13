// lib/ui/home/widgets/home_encabezado.dart
//
// Parte de arriba del inicio: saludo con campana de notificaciones, banner
// del pedido activo, buscador (lleva al catálogo) y chips de categoría.
//
// Movimiento: el saludo cambia rodando al entrar o salir de la sesión; la
// campana se mece cuando llegan avisos y su insignia aparece creciendo; el
// aviso del pedido pasa de un estado a otro sin saltos (tinte, ícono y
// mensaje) y celebra una vez cuando el pedido queda listo; las categorías del
// backend reemplazan a las de respaldo con un fundido. Todo lo que se toca se
// hunde un poco (PresionEscala).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/order_model.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/state/notification_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_pasteleria/ui/notifications/widgets/notifications_screen.dart';
import 'package:pier_pasteleria/ui/orders/widgets/order_detail_screen.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:provider/provider.dart';

IconData _iconoDeCategoria(String nombre) {
  switch (nombre.toLowerCase()) {
    case 'pasteles':  return LucideIcons.cake;
    case 'roscas':    return LucideIcons.donut;
    case 'pays':      return LucideIcons.chartPie;
    case 'postres':   return LucideIcons.cookie;
    case 'cafetería':
    case 'cafeteria': return LucideIcons.coffee;
    case 'bebidas':   return LucideIcons.cupSoda;
    case 'panes':     return LucideIcons.croissant;
    default:          return LucideIcons.sandwich;
  }
}

/// "Hola, Ana" (o "Bienvenido") y, con sesión, la campana con no leídas.
class HomeEncabezado extends StatelessWidget {
  const HomeEncabezado({
    required this.auth,
    required this.onVolverDeNotificaciones,
    super.key,
  });

  final AuthProvider auth;

  /// Al regresar de notificaciones (pudo cambiar el estado de un pedido).
  final VoidCallback onVolverDeNotificaciones;

  @override
  Widget build(BuildContext context) {
    final nombre =
        auth.currentUser?['nombre']?.toString().split(' ').first ?? '';
    final saludo = auth.isAuthenticated && nombre.isNotEmpty
        ? 'Hola, $nombre'
        : 'Bienvenido';
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20, right: 20, bottom: 16,
      ),
      color: AppColors.pierArena,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Al entrar o salir de la sesión el saludo rueda al nuevo.
                CambioAnimado(
                  tipo: TipoCambio.subir,
                  child: Text(
                    saludo,
                    key: ValueKey(saludo),
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                const Text('Descubre algo dulce hoy',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (auth.isAuthenticated)
            PresionEscala(
              escala: AppMovimiento.escalaPresionChica,
              child: GestureDetector(
                onTap: () async {
                  PierLog.nav('→ NotificationsScreen');
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const NotificationsScreen()),
                  );
                  onVolverDeNotificaciones();
                },
                child: Builder(builder: (context) {
                  final count = context.watch<NotificationProvider>().noLeidas;
                  return CampanaNotificaciones(cantidad: count);
                }),
              ),
            ),
        ],
      ),
    );
  }
}

/// Vaivén de campana (en vueltas): tres oscilaciones que se apagan; empieza
/// y termina en 0.
class _Vaiven extends Animatable<double> {
  const _Vaiven();

  @override
  double transform(double t) => math.sin(t * math.pi * 6) * (1 - t) * 0.035;
}

/// La campana del encabezado con su insignia de no leídas. Cuando llegan
/// avisos nuevos (la cantidad sube) la campana se mece una vez y la insignia
/// aparece creciendo, o da un salto si ya estaba; al leerlos se encoge y se
/// va. Al montarse no anima. Con movimiento reducido, sin vaivén ni saltos.
class CampanaNotificaciones extends StatefulWidget {
  const CampanaNotificaciones({required this.cantidad, super.key});

  /// Notificaciones no leídas.
  final int cantidad;

  @override
  State<CampanaNotificaciones> createState() => _CampanaNotificacionesState();
}

class _CampanaNotificacionesState extends State<CampanaNotificaciones>
    with TickerProviderStateMixin {
  static const Animatable<double> _vaiven = _Vaiven();
  static final Animatable<double> _salto = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.35, end: 1)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 70,
      ),
    ],
  );

  late final AnimationController _meneo;
  late final AnimationController _presencia;
  late final CurvedAnimation _escalaPresencia;
  late final AnimationController _rebote;

  // La insignia que se va conserva su último número (no muestra «0»).
  late int _numero;

  @override
  void initState() {
    super.initState();
    _numero = widget.cantidad;
    _meneo = AnimationController(vsync: this, duration: AppMovimiento.relleno);
    // La insignia sigue la misma receta que InsigniaCarrito (crecer, saltar
    // y encogerse igual que la del carrito); no se usa esa porque esta
    // muestra «9+» y mide 16 × 16.
    _presencia = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      reverseDuration: AppMovimiento.rapida,
      value: widget.cantidad > 0 ? 1 : 0,
    )..addStatusListener(_alCambiarPresencia);
    _escalaPresencia = CurvedAnimation(
      parent: _presencia,
      curve: AppMovimiento.curvaRebote,
      reverseCurve: Curves.easeIn,
    );
    _rebote = AnimationController(vsync: this, duration: AppMovimiento.enfasis);
  }

  @override
  void didUpdateWidget(CampanaNotificaciones oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nueva = widget.cantidad;
    final vieja = oldWidget.cantidad;
    if (nueva == vieja) return;
    if (nueva > 0) _numero = nueva;
    final reducido = AppMovimiento.reducido(context);
    if (nueva > 0 && vieja <= 0) {
      if (reducido) {
        _presencia.value = 1;
      } else {
        _presencia.forward().ignore();
      }
    } else if (nueva <= 0 && vieja > 0) {
      if (reducido) {
        _presencia.value = 0;
      } else {
        _presencia.reverse().ignore();
      }
    } else if (nueva > vieja && !reducido) {
      _rebote.forward(from: 0).ignore();
    }
    // Avisos nuevos: la campana se mece una vez.
    if (nueva > vieja && !reducido) _meneo.forward(from: 0).ignore();
  }

  void _alCambiarPresencia(AnimationStatus estado) {
    // Al terminar de encogerse, la insignia sale del árbol.
    if (estado == AnimationStatus.dismissed) setState(() {});
  }

  @override
  void dispose() {
    _escalaPresencia.dispose();
    _presencia.dispose();
    _rebote.dispose();
    _meneo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2))],
          ),
          // Se mece desde arriba, como una campana colgada.
          child: RotationTransition(
            turns: _meneo.drive(_vaiven),
            alignment: Alignment.topCenter,
            child: const Icon(LucideIcons.bell,
                color: AppColors.textPrimary, size: 20),
          ),
        ),
        if (!_presencia.isDismissed)
          Positioned(
            right: -2, top: -2,
            child: ScaleTransition(
              scale: _escalaPresencia,
              child: ScaleTransition(
                scale: _rebote.drive(_salto),
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      _numero > 9 ? '9+' : '$_numero',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Aviso del pedido en curso; tocarlo abre su detalle. Al cambiar de estado
/// el tinte pasa al nuevo color, el ícono cambia con un rebote y el mensaje
/// rueda al nuevo; cuando el pedido queda listo, su ícono celebra una vez.
class PedidoActivoBanner extends StatelessWidget {
  const PedidoActivoBanner({
    required this.pedido,
    required this.alCambiar,
    super.key,
  });

  final Order pedido;

  /// El pedido cambió de estado en su detalle (p. ej. se canceló).
  final ValueChanged<Order> alCambiar;

  @override
  Widget build(BuildContext context) {
    final numero = pedido.numero;
    final (IconData icon, String mensaje, Color color) = switch (pedido.status) {
      OrderStatus.preparing => (
          LucideIcons.cookingPot,
          'Pedido #$numero en preparación',
          AppColors.estadoPreparacion,
        ),
      OrderStatus.ready => (
          Icons.check_circle_outline_rounded,
          pedido.esDomicilio
              ? 'Pedido #$numero listo, buscando repartidor'
              : 'Pedido #$numero listo para recoger',
          AppColors.pierVerde,
        ),
      // 'pendiente' es exclusivo de los pedidos programados que el personal
      // debe confirmar (backend: por_confirmar).
      _ => (
          LucideIcons.hourglass,
          pedido.porConfirmar
              ? 'Pedido #$numero: confirmando disponibilidad'
              : 'Pedido #$numero recibido, en cola',
          AppColors.estadoPendiente,
        ),
    };
    // El tinte pasa al color del nuevo estado en vez de saltar.
    final cambio = AppMovimiento.duracion(context, AppMovimiento.media);
    return PresionEscala(
      child: GestureDetector(
        onTap: () {
          PierLog.nav('→ OrderDetailScreen');
          Navigator.push(context,
              MaterialPageRoute<void>(
                  builder: (_) =>
                      OrderDetailScreen(order: pedido, alCambiar: alCambiar))).ignore();
        },
        child: AnimatedContainer(
          duration: cambio,
          curve: AppMovimiento.curvaEstandar,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            _HaloListo(
              listo: pedido.status == OrderStatus.ready,
              color: color,
              child: AnimatedContainer(
                duration: cambio,
                curve: AppMovimiento.curvaEstandar,
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: CambioAnimado(
                  tipo: TipoCambio.escalar,
                  duracion: AppMovimiento.media,
                  alineacion: Alignment.center,
                  child: Icon(icon, key: ValueKey(icon), color: color, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CambioAnimado(
                tipo: TipoCambio.subir,
                child: Text(mensaje,
                    key: ValueKey(mensaje),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                        height: 1.3)),
              ),
            ),
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: color),
              duration: cambio,
              curve: AppMovimiento.curvaEstandar,
              builder: (_, tono, _) =>
                  Icon(LucideIcons.chevronRight, color: tono, size: 20),
            ),
          ]),
        ),
      ),
    );
  }
}

/// El momento que más importa: el pedido quedó listo. El cuadro del ícono
/// late dos veces y un anillo se abre y se apaga detrás de él. Una sola vez,
/// al aparecer el aviso ya listo (después de que abre su espacio) o al
/// cambiar a listo; con movimiento reducido, nada.
class _HaloListo extends StatefulWidget {
  const _HaloListo({
    required this.listo,
    required this.color,
    required this.child,
  });

  final bool listo;
  final Color color;
  final Widget child;

  @override
  State<_HaloListo> createState() => _HaloListoState();
}

class _HaloListoState extends State<_HaloListo>
    with SingleTickerProviderStateMixin {
  // Dos latidos, cada uno del largo de un pop de ícono.
  static final Duration _duracion = AppMovimiento.enfasis * 2;

  late final AnimationController _control;
  double _inicio = 0;
  bool _reducido = false;

  @override
  void initState() {
    super.initState();
    _control = AnimationController(vsync: this);
    if (widget.listo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _latir(AppMovimiento.media);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducido = AppMovimiento.reducido(context);
  }

  @override
  void didUpdateWidget(_HaloListo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listo && !oldWidget.listo) _latir(Duration.zero);
  }

  void _latir(Duration retraso) {
    if (_reducido) return;
    final total = retraso + _duracion;
    _inicio = retraso.inMicroseconds / total.inMicroseconds;
    _control
      ..duration = total
      ..forward(from: 0).ignore();
  }

  // Avance del latido: 0 en reposo y durante la espera.
  double get _avance {
    if (!_control.isAnimating) return 0;
    final valor = _control.value;
    return valor <= _inicio ? 0 : (valor - _inicio) / (1 - _inicio);
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
      builder: (context, cuadro) {
        final t = _avance;
        final latido = math.sin(t * math.pi * 2);
        final anillo =
            AppMovimiento.curvaEntrada.transform(math.min(t / 0.75, 1));
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: 1 + 0.7 * anillo,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.color
                        .withValues(alpha: t > 0 ? 0.35 * (1 - anillo) : 0),
                    width: 2,
                  ),
                ),
              ),
            ),
            Transform.scale(scale: 1 + 0.12 * latido * latido, child: cuadro),
          ],
        );
      },
    );
  }
}

/// Buscador de adorno: lleva al catálogo.
class HomeBuscador extends StatelessWidget {
  const HomeBuscador({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: PresionEscala(
        child: GestureDetector(
          onTap: () => context.read<NavigationProvider>().goCatalogo(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.2)),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3))],
            ),
            child: Row(
              children: [
                Icon(LucideIcons.search, color: AppColors.textSecondary.withValues(alpha: 0.5), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Busca tu pastel favorit...',
                      style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 14)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.pierVerde,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Text('Buscar',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hasta 5 categorías; tocar una abre el catálogo ya filtrado.
class HomeCategorias extends StatelessWidget {
  const HomeCategorias({required this.nombres, super.key});

  final List<String> nombres;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Categorías',
              style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          // Cuando llegan las del backend reemplazan a las de respaldo con
          // un fundido, sin que los círculos brinquen a su nuevo lugar.
          CambioAnimado(
            duracion: AppMovimiento.media,
            child: Row(
              key: ValueKey(nombres.take(5).join('|')),
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: nombres.take(5).map((nombre) {
                return PresionEscala(
                  escala: AppMovimiento.escalaPresionChica,
                  child: GestureDetector(
                    // Abre el catálogo YA filtrado por la categoría tocada
                    onTap: () => context
                        .read<NavigationProvider>()
                        .goCatalogo(categoria: nombre),
                    child: Column(
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(
                                color: Colors.black.withValues(alpha: 0.07),
                                blurRadius: 10,
                                offset: const Offset(0, 4))],
                          ),
                          child: Icon(_iconoDeCategoria(nombre),
                              color: AppColors.pierVerde, size: 26),
                        ),
                        const SizedBox(height: 6),
                        Text(nombre,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
