import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/providers/order_provider.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Generar órdenes de prueba (solo para demo)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      if (orderProvider.orders.isEmpty) {
        orderProvider.generateSampleOrders();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EE), // pierArena de fondo
      appBar: AppBar(
        title: const Text(
          'Mis Pedidos', 
          style: TextStyle(fontFamily: 'Playfair Display', fontWeight: FontWeight.bold)
        ),
        backgroundColor: AppColors.pierVerde,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.pierDorado,
          indicatorWeight: 4,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 15),
          tabs: const [
            Tab(text: 'Activos'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, child) {
          return TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Pedidos Activos
              _buildOrdersList(
                orderProvider.activeOrders,
                'No tienes pedidos activos',
                Icons.receipt_long_rounded,
              ),
              
              // Tab 2: Historial
              _buildOrdersList(
                orderProvider.completedOrders,
                'No tienes pedidos en el historial',
                Icons.history_rounded,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrdersList(List orders, String emptyMessage, IconData emptyIcon) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.pierVerde.withValues(alpha: 0.05 * 255),
                shape: BoxShape.circle,
              ),
              child: Icon(emptyIcon, size: 80, color: AppColors.pierVerde.withValues(alpha: 0.5 * 255)),
            ),
            const SizedBox(height: 24),
            Text(
              emptyMessage,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando realices una compra, aparecerá aquí.',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderCard(context, order);
      },
    );
  }

  // --- DISEÑO ELEGANTE DE LA TARJETA DE PEDIDO ---
  Widget _buildOrderCard(BuildContext context, dynamic order) {
    // 1. Extraemos el ID limpio
    final String orderId = order.id.toString().length > 6 
        ? order.id.toString().substring(0, 6) 
        : order.id.toString();
    
    // 2. CORRECCIÓN APLICADA: Convertimos el Enum a String y sacamos la última parte
    final String statusString = order.status.toString().split('.').last;
    final statusData = _getStatusData(statusString);

    // 3. Protección por si el modelo usa totalAmount o total
    double total = 0.0;
    try {
      total = order.totalAmount ?? order.total ?? 0.0;
    } catch (_) {
      try {
        total = order.total ?? 0.0;
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => OrderDetailScreen(order: order)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04 * 255),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1 * 255)),
        ),
        child: Column(
          children: [
            // CABECERA DE LA TARJETA (ID y Estado)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pedido #$orderId',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusData['bgColor'],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusData['text'],
                      style: TextStyle(color: statusData['textColor'], fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            // CUERPO DE LA TARJETA (Fecha y Total)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.pierArena,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined, color: AppColors.pierVerde, size: 24),
                  ),
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Fecha de compra', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 2),
                        const Text('04 Mar 2026 • 14:30 hrs', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(
                          'Total: \$${total.toStringAsFixed(0)}', 
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.pierDoradoOscuro),
                        ),
                      ],
                    ),
                  ),
                  
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- LÓGICA DE COLORES PARA EL ESTADO ---
  Map<String, dynamic> _getStatusData(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'pendiente':
        return {
          'text': 'Pendiente',
          'bgColor': Colors.orange.withValues(alpha: 0.15 * 255),
          'textColor': Colors.orange[800],
        };
      case 'preparing':
      case 'preparando':
        return {
          'text': 'Preparando',
          'bgColor': Colors.blue.withValues(alpha: 0.15 * 255),
          'textColor': Colors.blue[800],
        };
      case 'ready':
      case 'listo':
      case 'in_transit':
      case 'en_camino':
        return {
          'text': 'En Camino / Listo',
          'bgColor': AppColors.pierDorado.withValues(alpha: 0.15 * 255),
          'textColor': AppColors.pierDoradoOscuro,
        };
      case 'delivered':
      case 'entregado':
        return {
          'text': 'Entregado',
          'bgColor': Colors.green.withValues(alpha: 0.15 * 255),
          'textColor': Colors.green[800],
        };
      case 'cancelled':
      case 'cancelado':
        return {
          'text': 'Cancelado',
          'bgColor': Colors.red.withValues(alpha: 0.15 * 255),
          'textColor': Colors.red[800],
        };
      default:
        return {
          'text': 'Procesando',
          'bgColor': Colors.grey.withValues(alpha: 0.15 * 255),
          'textColor': Colors.grey[800],
        };
    }
  }
}