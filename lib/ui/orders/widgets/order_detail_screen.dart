// lib/ui/orders/widgets/order_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:pier_pasteleria/domain/models/order_model.dart';
import 'package:pier_pasteleria/ui/core/state/order_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

class OrderDetailScreen extends StatefulWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Order _order;
  bool _refreshing = false;
  bool _cancelando = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order; // snapshot inmediato: sin pantalla en blanco
    PierLog.nav('→ OrderDetailScreen: ${_order.numero}');
    _loadDetail(); // refresco silencioso al abrir
  }

  Future<void> _loadDetail() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final fresh =
        await context.read<OrderProvider>().fetchOrderDetail(_order.id);
    if (!mounted) return;
    setState(() {
      if (fresh != null) _order = fresh;
      _refreshing = false;
    });
  }

  // ── CANCELAR PEDIDO ──────────────────────────────────────────────
  Future<void> _confirmarCancelacion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Cancelar pedido?',
            style: TextStyle(
                fontFamily: 'Playfair Display',
                fontWeight: FontWeight.bold)),
        content: const Text(
            'Se cancelará tu pedido y generaremos tu solicitud de '
            'reembolso; te avisaremos cuando se procese.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Conservar pedido',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sí, cancelar',
                style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    await _cancelarPedido();
  }

  Future<void> _cancelarPedido() async {
    setState(() => _cancelando = true);
    final res =
        await context.read<OrderProvider>().cancelarPedido(_order.id);
    if (!mounted) return;
    setState(() {
      final fresh = res['order'];
      if (fresh is Order) _order = fresh;
      _cancelando = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] as String),
      backgroundColor:
          res['ok'] == true ? AppColors.pierVerde : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: const Icon(LucideIcons.chevronLeft,
                          size: 16, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_order.numero,
                            style: const TextStyle(
                                fontFamily: 'Playfair Display',
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(_formatDate(_order.createdAt),
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  _buildStatusChip(_order.status),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── CONTENIDO ────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadDetail,
                color: AppColors.pierVerde,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                    // ── ESTADO VISUAL ─────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 20),
                      decoration: BoxDecoration(
                        color: _order.statusColor
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _order.statusColor
                                .withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        children: [
                          Icon(_statusIcon(_order.status),
                              size: 52,
                              color: _order.statusColor),
                          const SizedBox(height: 10),
                          Text(_order.statusText,
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _order.statusColor)),
                          const SizedBox(height: 6),
                          Text(_statusMessage(_order.status),
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600]),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── TIMELINE ──────────────────────────────────
                    _buildTimeline(),

                    // Repartidor en camino (solo domicilio + en_camino)
                    if (_order.esDomicilio &&
                        _order.status == OrderStatus.onTheWay) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ],
                        ),
                        child: Row(children: [
                          Lottie.asset(
                            'assets/lottie/delivery.json',
                            width: 90,
                            height: 90,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                                '¡Tu pedido va en camino!\nEl repartidor está por llegar.',
                                style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                          ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // ── INFO DEL PEDIDO ───────────────────────────
                    _buildCard(
                      title: 'Información del pedido',
                      child: Column(children: [
                        _infoRow(LucideIcons.tag, 'Número',
                            _order.numero),
                        _divider(),
                        _infoRow(LucideIcons.calendar,
                            'Fecha',
                            _formatDateFull(_order.createdAt)),
                        if (_order.horarioRecogida != null) ...[
                          _divider(),
                          _infoRow(LucideIcons.clock,
                              'Horario de recogida',
                              _order.horarioRecogida!),
                        ],
                        _divider(),
                        _infoRow(LucideIcons.store, 'Sucursal',
                            'Principal — Huejutla de Reyes'),
                        if (_order.notas != null &&
                            _order.notas!.isNotEmpty) ...[
                          _divider(),
                          _infoRow(LucideIcons.stickyNote, 'Notas',
                              _order.notas!),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 12),

                    // ── PRODUCTOS ─────────────────────────────────
                    _buildCard(
                      title:
                          'Productos (${_order.items.length})',
                      child: Column(
                        children: _order.items
                            .asMap()
                            .entries
                            .map((e) {
                          final i = e.key;
                          final item = e.value;
                          return Column(children: [
                            if (i > 0) _divider(),
                            Row(children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.pierVerde
                                      .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: Icon(LucideIcons.cake,
                                    color: AppColors.pierVerde,
                                    size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(item.nombre,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color:
                                                AppColors.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.cantidad}× '
                                      '\$${item.precioUnitario.toStringAsFixed(0)} c/u'
                                      '${item.tamano != null ? ' · ${item.tamano}' : ''}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '\$${item.subtotal.toStringAsFixed(0)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color:
                                        AppColors.pierDoradoOscuro),
                              ),
                            ]),
                          ]);
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── RESUMEN DE PAGO ───────────────────────────
                    _buildCard(
                      title: 'Resumen de pago',
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          Text(
                            '\$${_order.total.toStringAsFixed(0)} MXN',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.pierVerde),
                          ),
                        ],
                      ),
                    ),

                    // ── CANCELAR PEDIDO ───────────────────────────
                    // Solo mientras nadie haya tomado el pedido
                    // (pendiente/listo, regla del backend).
                    if (_order.esCancelablePorCliente) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              _cancelando ? null : _confirmarCancelacion,
                          icon: _cancelando
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.error))
                              : const Icon(LucideIcons.circleX,
                                  size: 18, color: AppColors.error),
                          label: Text(
                              _cancelando
                                  ? 'Cancelando…'
                                  : 'Cancelar pedido',
                              style: const TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: AppColors.error
                                    .withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                            'Disponible mientras tu pedido no haya sido tomado',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500])),
                      ),
                    ],
                  ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TIMELINE ─────────────────────────────────────────────────────
  Widget _buildTimeline() {
    if (_order.status == OrderStatus.cancelled ||
        _order.status == OrderStatus.deliveryFailed) {
      final esFallo = _order.status == OrderStatus.deliveryFailed;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(esFallo ? LucideIcons.circleAlert : LucideIcons.circleX,
                color: AppColors.error, size: 18),
            const SizedBox(width: 8),
            Text(esFallo ? 'No pudimos entregar el pedido' : 'Pedido cancelado',
                style: const TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    // Todo pedido pagado nace "Listo" (la repostería ya está hecha); ya no
    // existe "en preparación". "Pendiente" quedó solo para los programados
    // por confirmar, así que el primer paso del pickup refleja eso.
    final steps = _order.esDomicilio
        ? [
            (OrderStatus.ready,     'Listo',      Icons.check_circle_outline),
            (OrderStatus.assigned,  'Asignado',   LucideIcons.userRound),
            (OrderStatus.onTheWay,  'En camino',  LucideIcons.truck),
            (OrderStatus.delivered, 'Entregado',  LucideIcons.checkCheck),
          ]
        : [
            (
              OrderStatus.pending,
              _order.porConfirmar ? 'Por confirmar' : 'Recibido',
              LucideIcons.inbox
            ),
            (OrderStatus.ready,     'Listo',      Icons.check_circle_outline),
            (OrderStatus.completed, 'Entregado',  LucideIcons.checkCheck),
          ];

    // Compat: un pedido viejo aún "en preparación" se ubica tras Recibido.
    var currentIdx = steps.indexWhere((s) => s.$1 == _order.status);
    if (currentIdx == -1 && _order.status == OrderStatus.preparing) {
      currentIdx = 0;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: steps.asMap().entries.map((e) {
          final idx = e.key;
          final step = e.value;
          final done = idx <= currentIdx;
          final current = idx == currentIdx;

          // Secuencia: círculo idx entra a idx*300ms; la línea hacia el
          // siguiente crece a idx*300+150ms. Solo se anima lo completado
          // (verde); lo pendiente queda estático.
          Widget circulo = Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: done
                  ? AppColors.pierVerde
                  : Colors.grey[200],
              shape: BoxShape.circle,
              border: current
                  ? Border.all(
                      color: AppColors.pierVerde, width: 2.5)
                  : null,
            ),
            child: done
                ? Icon(step.$3, size: 14, color: Colors.white)
                : null,
          );
          if (done) {
            circulo = circulo.animate().scale(
                begin: Offset.zero,
                end: const Offset(1, 1),
                delay: (idx * 300).ms,
                duration: 300.ms,
                curve: Curves.easeOutBack);
          }

          Widget segmento(bool verde, {required int delayMs}) {
            Widget linea = Container(
              height: 2,
              color: verde ? AppColors.pierVerde : Colors.grey[200],
            );
            if (verde) {
              linea = linea.animate().scaleX(
                  begin: 0,
                  end: 1,
                  alignment: Alignment.centerLeft,
                  delay: delayMs.ms,
                  duration: 200.ms,
                  curve: Curves.easeOut);
            }
            return linea;
          }

          Widget etiqueta = Text(step.$2,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: current
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: done
                      ? AppColors.pierVerde
                      : Colors.grey[400]),
              textAlign: TextAlign.center);
          if (done) {
            etiqueta = etiqueta
                .animate()
                .fadeIn(delay: (idx * 300 + 120).ms, duration: 250.ms);
          }

          return Expanded(
            child: Column(children: [
              Row(children: [
                if (idx > 0)
                  Expanded(
                    child: segmento(idx <= currentIdx,
                        delayMs: (idx - 1) * 300 + 150),
                  ),
                circulo,
                if (idx < steps.length - 1)
                  Expanded(
                    child: segmento(idx < currentIdx,
                        delayMs: idx * 300 + 150),
                  ),
              ]),
              const SizedBox(height: 6),
              etiqueta,
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────
  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: AppColors.pierVerde.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.pierVerde),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[500])),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Divider(
            height: 1,
            color: Colors.grey.withValues(alpha: 0.12)),
      );

  Widget _buildStatusChip(OrderStatus status) {
    final color = _order.statusColor;
    String label;
    switch (status) {
      case OrderStatus.pending:
        label = _order.porConfirmar ? 'Por confirmar' : 'Pendiente';
        break;
      case OrderStatus.preparing:  label = 'Preparando'; break;
      case OrderStatus.ready:      label = 'Listo'; break;
      case OrderStatus.completed:  label = 'Completado'; break;
      case OrderStatus.cancelled:  label = 'Cancelado'; break;
      case OrderStatus.assigned:       label = 'Asignado'; break;
      case OrderStatus.onTheWay:       label = 'En camino'; break;
      case OrderStatus.delivered:      label = 'Entregado'; break;
      case OrderStatus.deliveryFailed: label = 'Entrega fallida'; break;
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold)),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Ene','Feb','Mar','Abr','May','Jun',
                    'Jul','Ago','Sep','Oct','Nov','Dic'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatDateFull(DateTime dt) {
    const months = ['Ene','Feb','Mar','Abr','May','Jun',
                    'Jul','Ago','Sep','Oct','Nov','Dic'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} · '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')} hrs';
  }

  IconData _statusIcon(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:   return LucideIcons.inbox;
      case OrderStatus.preparing: return LucideIcons.cookingPot;
      case OrderStatus.ready:     return Icons.check_circle_outline;
      case OrderStatus.completed: return LucideIcons.checkCheck;
      case OrderStatus.cancelled: return LucideIcons.circleX;
      case OrderStatus.assigned:       return LucideIcons.userRound;
      case OrderStatus.onTheWay:       return LucideIcons.truck;
      case OrderStatus.delivered:      return LucideIcons.checkCheck;
      case OrderStatus.deliveryFailed: return LucideIcons.circleAlert;
    }
  }

  String _statusMessage(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return _order.porConfirmar
            ? 'Tu pedido es para otra fecha: estamos confirmando la '
                'disponibilidad de tus productos. Te avisamos muy pronto'
            : 'Tu pedido fue recibido y está en cola';
      case OrderStatus.preparing:
        // ✅ FIX: sin emoji — texto limpio
        return 'Estamos preparando tu pedido con mucho cariño';
      case OrderStatus.ready:
        // ✅ FIX: sin emoji
        return _order.esDomicilio
            ? 'Tu pedido está listo y en espera de un repartidor'
            : 'Tu pedido está listo. Pasa a recogerlo';
      case OrderStatus.completed:
        // ✅ FIX: sin emoji
        return 'Pedido entregado. Gracias por tu compra';
      case OrderStatus.cancelled:
        return 'Este pedido fue cancelado';
      case OrderStatus.assigned:
        return 'Un repartidor tomó tu pedido y saldrá pronto';
      case OrderStatus.onTheWay:
        return 'Tu pedido va en camino a tu domicilio';
      case OrderStatus.delivered:
        return 'Pedido entregado. Gracias por tu compra';
      case OrderStatus.deliveryFailed:
        return 'No pudimos entregar tu pedido. Nos pondremos en contacto contigo';
    }
  }
}