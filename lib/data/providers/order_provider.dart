import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';

class OrderProvider extends ChangeNotifier {
  final List<Order> _orders = [];

  List<Order> get orders => _orders;

  List<Order> get activeOrders {
    return _orders.where((order) {
      return order.status != OrderStatus.completed &&
          order.status != OrderStatus.cancelled;
    }).toList();
  }

  List<Order> get completedOrders {
    return _orders.where((order) {
      return order.status == OrderStatus.completed ||
          order.status == OrderStatus.cancelled;
    }).toList();
  }

  void addOrder(Order order) {
    _orders.insert(0, order);
    notifyListeners();
  }

  void updateOrderStatus(String orderId, OrderStatus status) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index >= 0) {
      final oldOrder = _orders[index];
      _orders[index] = Order(
        id: oldOrder.id,
        items: oldOrder.items,
        subtotal: oldOrder.subtotal,
        tax: oldOrder.tax,
        total: oldOrder.total,
        sucursal: oldOrder.sucursal,
        deliveryDate: oldOrder.deliveryDate,
        deliveryTime: oldOrder.deliveryTime,
        notes: oldOrder.notes,
        status: status,
        createdAt: oldOrder.createdAt,
      );
      notifyListeners();
    }
  }

  Order? getOrderById(String orderId) {
    try {
      return _orders.firstWhere((order) => order.id == orderId);
    } catch (e) {
      return null;
    }
  }

  // Método para generar órdenes de prueba
  void generateSampleOrders() {
    final sampleProducts = ProductData.getSampleProducts();
    
    _orders.addAll([
      Order(
        id: 'ORD-001',
        items: [
          CartItem(product: sampleProducts[0], quantity: 1),
          CartItem(product: sampleProducts[1], quantity: 2),
        ],
        subtotal: 1090.0,
        tax: 174.4,
        total: 1264.4,
        sucursal: 'Repostería',
        deliveryDate: DateTime.now().add(const Duration(days: 1)),
        deliveryTime: '10:00 AM',
        notes: 'Decoración especial de cumpleaños',
        status: OrderStatus.preparing,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Order(
        id: 'ORD-002',
        items: [
          CartItem(product: sampleProducts[2], quantity: 1),
        ],
        subtotal: 280.0,
        tax: 44.8,
        total: 324.8,
        sucursal: 'Cafetería',
        deliveryDate: DateTime.now(),
        deliveryTime: '3:00 PM',
        notes: '',
        status: OrderStatus.ready,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      Order(
        id: 'ORD-003',
        items: [
          CartItem(product: sampleProducts[3], quantity: 4),
          CartItem(product: sampleProducts[4], quantity: 2),
        ],
        subtotal: 610.0,
        tax: 97.6,
        total: 707.6,
        sucursal: 'Repostería',
        deliveryDate: DateTime.now().subtract(const Duration(days: 2)),
        deliveryTime: '11:00 AM',
        notes: '',
        status: OrderStatus.completed,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ]);
    notifyListeners();
  }
}