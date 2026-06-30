// lib/presentation/screens/client/orders/order_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/logger.dart';
import '../../../../data/models/order_model.dart';
import '../../../../data/providers/order_provider.dart';

class OrderDetailScreen extends StatefulWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Order _order;
  bool _refreshing = false;

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

  @override
  Widget build(BuildContext context) {
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
                      child: const Icon(Icons.arrow_back_ios_new,
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
                    const SizedBox(height: 16),

                    // ── INFO DEL PEDIDO ───────────────────────────
                    _buildCard(
                      title: 'Información del pedido',
                      child: Column(children: [
                        _infoRow(Icons.tag_rounded, 'Número',
                            _order.numero),
                        _divider(),
                        _infoRow(Icons.calendar_today_rounded,
                            'Fecha',
                            _formatDateFull(_order.createdAt)),
                        if (_order.horarioRecogida != null) ...[
                          _divider(),
                          _infoRow(Icons.access_time_rounded,
                              'Horario de recogida',
                              _order.horarioRecogida!),
                        ],
                        _divider(),
                        _infoRow(Icons.storefront_rounded, 'Sucursal',
                            'Principal — Huejutla de Reyes'),
                        if (_order.notas != null &&
                            _order.notas!.isNotEmpty) ...[
                          _divider(),
                          _infoRow(Icons.note_outlined, 'Notas',
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
                                child: const Icon(Icons.cake_outlined,
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
                                style: const TextStyle(
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
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.pierVerde),
                          ),
                        ],
                      ),
                    ),
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
    if (_order.status == OrderStatus.cancelled) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.red.withValues(alpha: 0.2)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
            SizedBox(width: 8),
            Text('Pedido cancelado',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    final steps = [
      (OrderStatus.pending,   'Recibido',   Icons.inbox_rounded),
      (OrderStatus.preparing, 'Preparando', Icons.blender_outlined),
      (OrderStatus.ready,     'Listo',      Icons.check_circle_outline),
      (OrderStatus.completed, 'Entregado',  Icons.done_all_rounded),
    ];

    final currentIdx =
        steps.indexWhere((s) => s.$1 == _order.status);

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

          return Expanded(
            child: Column(children: [
              Row(children: [
                if (idx > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: idx <= currentIdx
                          ? AppColors.pierVerde
                          : Colors.grey[200],
                    ),
                  ),
                Container(
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
                ),
                if (idx < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: idx < currentIdx
                          ? AppColors.pierVerde
                          : Colors.grey[200],
                    ),
                  ),
              ]),
              const SizedBox(height: 6),
              Text(step.$2,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: current
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: done
                          ? AppColors.pierVerde
                          : Colors.grey[400]),
                  textAlign: TextAlign.center),
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
      case OrderStatus.pending:    label = 'Pendiente'; break;
      case OrderStatus.preparing:  label = 'Preparando'; break;
      case OrderStatus.ready:      label = 'Listo'; break;
      case OrderStatus.completed:  label = 'Completado'; break;
      case OrderStatus.cancelled:  label = 'Cancelado'; break;
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
      case OrderStatus.pending:   return Icons.inbox_rounded;
      case OrderStatus.preparing: return Icons.blender_outlined;
      case OrderStatus.ready:     return Icons.check_circle_outline;
      case OrderStatus.completed: return Icons.done_all_rounded;
      case OrderStatus.cancelled: return Icons.cancel_outlined;
    }
  }

  String _statusMessage(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return 'Tu pedido fue recibido y está en cola';
      case OrderStatus.preparing:
        // ✅ FIX: sin emoji — texto limpio
        return 'Estamos preparando tu pedido con mucho cariño';
      case OrderStatus.ready:
        // ✅ FIX: sin emoji
        return 'Tu pedido está listo. Pasa a recogerlo';
      case OrderStatus.completed:
        // ✅ FIX: sin emoji
        return 'Pedido entregado. Gracias por tu compra';
      case OrderStatus.cancelled:
        return 'Este pedido fue cancelado';
    }
  }
}