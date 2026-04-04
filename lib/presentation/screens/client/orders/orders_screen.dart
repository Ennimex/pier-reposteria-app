import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../data/models/order_model.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  List<Order> _activeOrders = [];
  List<Order> _completedOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarPedidos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarPedidos() async {
    setState(() => _isLoading = true);
    final result = await _api.getAuth(ApiConstants.misPedidos);
    if (result['success'] == true) {
      final data = result['data'] ?? result['pedidos'] ?? [];
      final all = (data as List)
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();
      setState(() {
        _activeOrders = all
            .where((o) =>
                o.status != OrderStatus.completed &&
                o.status != OrderStatus.cancelled)
            .toList();
        _completedOrders = all
            .where((o) =>
                o.status == OrderStatus.completed ||
                o.status == OrderStatus.cancelled)
            .toList();
      });
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EE),
      appBar: AppBar(
        title: const Text(
          'Mis Pedidos',
          style: TextStyle(
              fontFamily: 'Playfair Display',
              fontWeight: FontWeight.bold),
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
          labelStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16),
          unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.normal, fontSize: 15),
          tabs: const [
            Tab(text: 'Activos'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.pierVerde))
          : RefreshIndicator(
              onRefresh: _cargarPedidos,
              color: AppColors.pierVerde,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOrdersList(
                    _activeOrders,
                    'No tienes pedidos activos',
                    Icons.receipt_long_rounded,
                  ),
                  _buildOrdersList(
                    _completedOrders,
                    'No tienes pedidos en el historial',
                    Icons.history_rounded,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOrdersList(
      List<Order> orders, String emptyMessage, IconData emptyIcon) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.pierVerde.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(emptyIcon,
                  size: 80,
                  color: AppColors.pierVerde.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            Text(emptyMessage,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Cuando realices una compra, aparecerá aquí.',
              style:
                  TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) =>
          _buildOrderCard(context, orders[index]),
    );
  }

  Widget _buildOrderCard(BuildContext context, Order order) {
    final statusData =
        _getStatusData(order.status.toString().split('.').last);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => OrderDetailScreen(order: order)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
              color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pedido #${order.id}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppColors.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusData['bgColor'],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusData['text'],
                      style: TextStyle(
                          color: statusData['textColor'],
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.pierArena,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: AppColors.pierVerde,
                        size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text('Fecha de compra',
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(order.createdAt),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total: \$${order.total.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: AppColors.pierDoradoOscuro),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Colors.grey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} hrs';
  }

  Map<String, dynamic> _getStatusData(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'pendiente':
        return {
          'text': 'Pendiente',
          'bgColor': Colors.orange.withValues(alpha: 0.15),
          'textColor': Colors.orange[800],
        };
      case 'preparing':
      case 'preparando':
        return {
          'text': 'Preparando',
          'bgColor': Colors.blue.withValues(alpha: 0.15),
          'textColor': Colors.blue[800],
        };
      case 'ready':
      case 'listo':
        return {
          'text': 'Listo para recoger',
          'bgColor':
              AppColors.pierDorado.withValues(alpha: 0.15),
          'textColor': AppColors.pierDoradoOscuro,
        };
      case 'completed':
      case 'entregado':
        return {
          'text': 'Entregado',
          'bgColor': Colors.green.withValues(alpha: 0.15),
          'textColor': Colors.green[800],
        };
      case 'cancelled':
      case 'cancelado':
        return {
          'text': 'Cancelado',
          'bgColor': Colors.red.withValues(alpha: 0.15),
          'textColor': Colors.red[800],
        };
      default:
        return {
          'text': 'Procesando',
          'bgColor': Colors.grey.withValues(alpha: 0.15),
          'textColor': Colors.grey[800],
        };
    }
  }
}