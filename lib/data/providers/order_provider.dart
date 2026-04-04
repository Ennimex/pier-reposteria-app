import 'package:flutter/foundation.dart';
import '../models/order_model.dart';

class OrderProvider extends ChangeNotifier {
  final List<Order> _orders = [];

  List<Order> get orders => _orders;

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

  void addOrder(Order order) {
    _orders.insert(0, order);
    notifyListeners();
  }

  void updateOrderStatus(String orderId, OrderStatus status) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      final old = _orders[index];
      _orders[index] = Order(
        id: old.id,
        items: old.items,
        subtotal: old.subtotal,
        tax: old.tax,
        total: old.total,
        sucursal: old.sucursal,
        deliveryDate: old.deliveryDate,
        deliveryTime: old.deliveryTime,
        notes: old.notes,
        status: status,
        createdAt: old.createdAt,
      );
      notifyListeners();
    }
  }

  Order? getOrderById(String orderId) {
    try {
      return _orders.firstWhere((o) => o.id == orderId);
    } catch (_) {
      return null;
    }
  }
}