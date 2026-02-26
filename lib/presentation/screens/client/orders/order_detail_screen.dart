import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/order_model.dart';
import '../../../../data/providers/order_provider.dart';

class OrderDetailScreen extends StatelessWidget {
  final Order order;

  const OrderDetailScreen({
    Key? key,
    required this.order,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy - HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(order.id),
        actions: [
          if (order.status == OrderStatus.pending)
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              onPressed: () => _showCancelDialog(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado del pedido
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: order.statusColor.withOpacity(0.1),
              child: Column(
                children: [
                  Icon(
                    _getStatusIcon(order.status),
                    size: 60,
                    color: order.statusColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    order.statusText,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: order.statusColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getStatusMessage(order.status),
                    style: TextStyle(
                      fontSize: 14,
                      color: order.statusColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Timeline de estados
            _buildTimeline(),

            const Divider(height: 1),

            // Información de entrega
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Información de Entrega',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.calendar_today,
                    'Fecha de Entrega',
                    DateFormat('EEEE, dd MMMM yyyy', 'es').format(order.deliveryDate),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.access_time,
                    'Hora',
                    order.deliveryTime,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.store,
                    'Sucursal',
                    'Sucursal ${order.sucursal}',
                  ),
                  if (order.notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.note,
                      'Notas',
                      order.notes,
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1),

            // Productos
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Productos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...order.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item.product.imageUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.cake),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Cantidad: ${item.quantity}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '\$${item.subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),

            const Divider(height: 1),

            // Resumen de pago
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumen de Pago',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentRow('Subtotal', order.subtotal),
                  const SizedBox(height: 8),
                  _buildPaymentRow('IVA (16%)', order.tax),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '\$${order.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.pierVerde,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Información adicional
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pedido realizado el ${dateFormat.format(order.createdAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Botones de acción
      bottomNavigationBar: _buildBottomActions(context),
    );
  }

  Widget _buildTimeline() {
    final statuses = [
      OrderStatus.pending,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.completed,
    ];

    final currentIndex = statuses.indexOf(order.status);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(statuses.length, (index) {
          final isCompleted = index <= currentIndex;
          final isCurrent = index == currentIndex;
          
          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (index > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index <= currentIndex
                              ? AppColors.pierVerde
                              : Colors.grey[300],
                        ),
                      ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.pierVerde
                            : Colors.grey[300],
                        shape: BoxShape.circle,
                        border: isCurrent
                            ? Border.all(color: AppColors.pierVerde, width: 3)
                            : null,
                      ),
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    if (index < statuses.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index < currentIndex
                              ? AppColors.pierVerde
                              : Colors.grey[300],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _getShortStatusText(statuses[index]),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCompleted
                        ? AppColors.pierVerde
                        : AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.pierVerde),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget? _buildBottomActions(BuildContext context) {
    if (order.status == OrderStatus.completed ||
        order.status == OrderStatus.cancelled) {
      return null;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (order.status == OrderStatus.ready)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _markAsCompleted(context),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Marcar como Recogido'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.pierVerde,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            if (order.status == OrderStatus.pending) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showCancelDialog(context),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancelar Pedido'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.pending_outlined;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.ready:
        return Icons.check_circle_outline;
      case OrderStatus.completed:
        return Icons.done_all;
      case OrderStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  String _getStatusMessage(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Tu pedido ha sido recibido';
      case OrderStatus.preparing:
        return 'Estamos preparando tu pedido';
      case OrderStatus.ready:
        return '¡Tu pedido está listo! Puedes recogerlo';
      case OrderStatus.completed:
        return 'Pedido entregado. ¡Gracias!';
      case OrderStatus.cancelled:
        return 'Este pedido fue cancelado';
    }
  }

  String _getShortStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Recibido';
      case OrderStatus.preparing:
        return 'Preparando';
      case OrderStatus.ready:
        return 'Listo';
      case OrderStatus.completed:
        return 'Entregado';
      case OrderStatus.cancelled:
        return 'Cancelado';
    }
  }

  void _markAsCompleted(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    orderProvider.updateOrderStatus(order.id, OrderStatus.completed);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Gracias por tu compra!'),
        backgroundColor: AppColors.pierVerde,
      ),
    );
    
    Navigator.pop(context);
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Pedido'),
        content: const Text(
          '¿Estás seguro de que quieres cancelar este pedido?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              final orderProvider =
                  Provider.of<OrderProvider>(context, listen: false);
              orderProvider.updateOrderStatus(order.id, OrderStatus.cancelled);
              
              Navigator.pop(context); // Cerrar diálogo
              Navigator.pop(context); // Volver a lista
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pedido cancelado'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text(
              'Sí, Cancelar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}