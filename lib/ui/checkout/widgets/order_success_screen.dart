// lib/ui/checkout/widgets/order_success_screen.dart
//
// «¡Pedido Confirmado!»: el check animado y el ticket del pedido. Llega con
// RutaCelebracion (florece sobre blanco) y aquí se coreografía el momento:
// el título, el mensaje y el ticket suben en cascada mientras el círculo
// verde crece; las líneas del ticket se trazan de izquierda a derecha y,
// cuando el check termina de dibujarse, salen las chispas de repostería
// (no si el pedido está por confirmar) y el «Total pagado» da un pop. Un
// solo reloj mueve el check, las líneas, el pop y el momento de las chispas,
// así que todo cae junto. Sin Timers: el reloj arranca en el primer cuadro
// en que la pantalla se ve.
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/config/business_info.dart';
import 'package:pier_reposteria/ui/core/state/navigation_provider.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:provider/provider.dart';

class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({
    required this.orderId,
    required this.pickupDate,
    required this.pickupTime,
    required this.total,
    this.esDomicilio = false,
    this.direccionResumen,
    this.porConfirmar = false,
    super.key,
  });

  final String orderId;
  final String pickupDate;
  final String pickupTime;
  final double total;
  final bool esDomicilio;
  final String? direccionResumen;
  // Pedido programado con productos sin stock hoy: el personal confirmará
  // la disponibilidad para la fecha elegida.
  final bool porConfirmar;

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with SingleTickerProviderStateMixin {
  // El reloj del momento es el del propio check: success_check.json dura 130
  // cuadros a 60 fps.
  static const int _msCheck = 2167;

  // El anillo del check se abre en el cuadro 76 (≈1.27 s) y el trazo termina
  // en el 85 (≈1.42 s): ahí salen las chispas y el total da su pop.
  static const double _momentoChispas = 1250 / _msCheck;

  static Animatable<double> _trazo(int desdeMs) => CurveTween(
        curve: Interval(
          desdeMs / _msCheck,
          (desdeMs + 260) / _msCheck,
          curve: AppMovimiento.curvaEntrada,
        ),
      );

  // «Total pagado»: 1 → 1.08 → 1 cuando el check se cierra.
  static final Animatable<double> _pop = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.08,
          end: 1,
        ).chain(CurveTween(curve: AppMovimiento.curvaRebote)),
        weight: 60,
      ),
    ],
  ).chain(CurveTween(curve: const Interval(1300 / _msCheck, 1700 / _msCheck)));

  late final AnimationController _reloj = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _msCheck),
  );
  late final List<Animation<double>> _trazos = [
    _reloj.drive(_trazo(600)),
    _reloj.drive(_trazo(680)),
    _reloj.drive(_trazo(760)),
  ];
  late final Animation<double> _escalaTotal = _reloj.drive(_pop);

  bool _iniciado = false;
  bool _reducido = false;
  bool _chispas = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    _reducido = AppMovimiento.reducido(context);
    if (_reducido) {
      // Sin movimiento: el check ya cerrado y el ticket completo.
      _reloj.value = 1;
      return;
    }
    if (!widget.porConfirmar) _reloj.addListener(_vigilarChispas);
    // Desde un post-frame: si la ruta aún no se ve, el reloj espera.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reloj.forward().ignore();
    });
  }

  void _vigilarChispas() {
    if (_reloj.value < _momentoChispas) return;
    _reloj.removeListener(_vigilarChispas);
    setState(() => _chispas = true);
  }

  @override
  void dispose() {
    _reloj
      ..removeListener(_vigilarChispas)
      ..dispose();
    super.dispose();
  }

  void _goHome(BuildContext context) {
    // Esta pantalla vive apilada en el navigator interno del tab Carrito:
    // hay que vaciar esa pila (si no, el tab se queda mostrando el éxito y
    // habría que dar doble tap al tab para limpiarlo) y luego cambiar a Inicio.
    final nav = Navigator.of(context);
    context.read<NavigationProvider>().setSelectedIndex(0);
    nav.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final porConfirmar = widget.porConfirmar;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome(context);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── ÍCONO ──────────────────────────────────────────────
                    // Celebración: check Lottie (una sola reproducción, al
                    // ritmo del reloj de la pantalla) y el resto la sigue en
                    // cascada.
                    Lottie.asset(
                      'assets/lottie/success_check.json',
                      width: _tamanoCheck,
                      height: _tamanoCheck,
                      fit: BoxFit.contain,
                      controller: _reducido
                          ? const AlwaysStoppedAnimation<double>(1)
                          : _reloj,
                    ),
                    const SizedBox(height: 24),
                    EntradaSuave(
                      retraso: const Duration(milliseconds: 200),
                      desplazamiento:
                          const Offset(0, AppMovimiento.distanciaCorta),
                      child: Text('¡Pedido Confirmado!',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.pierVerdeOscuro)),
                    ),
                    const SizedBox(height: 8),
                    EntradaSuave(
                      retraso: const Duration(milliseconds: 330),
                      desplazamiento: Offset.zero,
                      child: Text(
                        porConfirmar
                            ? 'Tu pedido #${widget.orderId} ha sido registrado.\nEstamos confirmando la disponibilidad para tu fecha.'
                            : 'Tu pedido #${widget.orderId} ha sido registrado.\nTe notificaremos cuando esté listo.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.textSecondary),
                      ),
                    ),
                    if (porConfirmar) ...[
                      const SizedBox(height: 16),
                      EntradaSuave(
                        retraso: const Duration(milliseconds: 400),
                        desplazamiento: Offset.zero,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.pierDorado.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.pierDorado
                                    .withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(LucideIcons.clock,
                                  size: 18, color: AppColors.pierDoradoOscuro),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Como tu pedido es para otra fecha, te avisaremos '
                                  'muy pronto si podemos prepararlo. Si no fuera '
                                  'posible, tu pago se reembolsa completo.',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.35,
                                      color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),

                    // ── TICKET ─────────────────────────────────────────────
                    EntradaSuave(
                      retraso: const Duration(milliseconds: 450),
                      duracion: const Duration(milliseconds: 400),
                      desplazamiento: const Offset(0, 12),
                      child: _ticket(),
                    ),

                    const Spacer(),

                    // ── BOTÓN ──────────────────────────────────────────────
                    EntradaSuave(
                      retraso: const Duration(milliseconds: 650),
                      duracion: const Duration(milliseconds: 400),
                      desplazamiento: Offset.zero,
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _goHome(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.pierVerde,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Volver al Inicio',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Chispas de repostería desde el centro del check, encima del
              // resto de la pantalla (nunca reciben toques; una sola ráfaga).
              if (_chispas)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, area) => Chispas(
                      cantidad: 44,
                      origen: Alignment(0, _origenChispas(area.maxHeight)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static const double _tamanoCheck = 170;

  /// Alto del centro del check (padding de 30 + medio Lottie) como
  /// alineación vertical dentro de un área de [alto].
  static double _origenChispas(double alto) {
    if (!alto.isFinite || alto <= 0) return -0.6;
    return (2 * (30 + _tamanoCheck / 2) / alto - 1).clamp(-1, 1);
  }

  Widget _ticket() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pierArena.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.pierVerde.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          if (widget.esDomicilio)
            _buildRow(LucideIcons.bike, 'Entrega a domicilio',
                widget.direccionResumen ?? 'A tu domicilio')
          else
            _buildRow(LucideIcons.store, 'Sucursal',
                '${BusinessInfo.sucursal} — ${BusinessInfo.ciudad}'),
          _LineaTrazada(avance: _trazos[0]),
          _buildRow(
              LucideIcons.calendar,
              widget.esDomicilio ? 'Fecha de entrega' : 'Fecha de recogida',
              widget.pickupDate),
          _LineaTrazada(avance: _trazos[1]),
          _buildRow(LucideIcons.clock, 'Horario', widget.pickupTime),
          _LineaTrazada(avance: _trazos[2]),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total pagado',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary)),
              ScaleTransition(
                scale: _escalaTotal,
                alignment: Alignment.centerRight,
                child: Text(
                  '\$${widget.total.toStringAsFixed(0)} MXN',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: AppColors.pierVerde),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.pierVerde),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary)),
        ),
      ],
    );
  }
}

/// Divisor del ticket que se traza de izquierda a derecha (solo pinta: el
/// alto de 24 es el del Divider de siempre).
class _LineaTrazada extends StatelessWidget {
  const _LineaTrazada({required this.avance});

  final Animation<double> avance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: avance,
      builder: (context, hijo) => Transform.scale(
        scaleX: avance.value,
        alignment: AlignmentDirectional.centerStart,
        child: hijo,
      ),
      child: const Divider(height: 24),
    );
  }
}
