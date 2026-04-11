// lib/data/providers/order_provider.dart
import 'package:flutter/foundation.dart';
import '../../core/utils/logger.dart';
import '../models/order_model.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';

class OrderProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Order> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Order> get activeOrders => _orders
      .where((o) =>
          o.status != OrderStatus.completed &&
          o.status != OrderStatus.cancelled)
      .toList();

  List<Order> get completedOrders => _orders
      .where((o) =>
          o.status == OrderStatus.completed ||
          o.status == OrderStatus.cancelled)
      .toList();

  Future<void> cargarPedidos() async {
    PierLog.info('📦 Descargando historial de pedidos...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _api.getAuth(ApiConstants.misPedidos);

    _isLoading = false;

    if (result['success'] == true) {
      final data = result['pedidos'] ?? result['data'] ?? [];
      _orders = (data as List)
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();
      PierLog.info('✅ Historial de pedidos cargados: ${_orders.length}');
    } else {
      _errorMessage = result['message'] ?? 'Error al cargar pedidos';
      PierLog.error('Error al cargar pedidos: $_errorMessage');
    }

    notifyListeners();
  }

  Future<void> refrescar() async {
    _orders = [];
    await cargarPedidos();
  }

  Order? getOrderById(String id) {
    try {
      return _orders.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }
}