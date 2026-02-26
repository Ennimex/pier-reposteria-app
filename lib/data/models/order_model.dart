import 'package:flutter/material.dart';
import 'cart_item_model.dart';

enum OrderStatus {
  pending,
  preparing,
  ready,
  completed,
  cancelled,
}

class Order {
  final String id;
  final List<CartItem> items;
  final double subtotal;
  final double tax;
  final double total;
  final String sucursal;
  final DateTime deliveryDate;
  final String deliveryTime;
  final String notes;
  final OrderStatus status;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.sucursal,
    required this.deliveryDate,
    required this.deliveryTime,
    this.notes = '',
    this.status = OrderStatus.pending,
    required this.createdAt,
  });

  int get totalQuantity {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  String get statusText {
    switch (status) {
      case OrderStatus.pending:
        return 'Pendiente';
      case OrderStatus.preparing:
        return 'En preparación';
      case OrderStatus.ready:
        return 'Listo para recoger';
      case OrderStatus.completed:
        return 'Completado';
      case OrderStatus.cancelled:
        return 'Cancelado';
    }
  }

  Color get statusColor {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFFFA500); // Orange
      case OrderStatus.preparing:
        return const Color(0xFF2196F3); // Blue
      case OrderStatus.ready:
        return const Color(0xFF4CAF50); // Green
      case OrderStatus.completed:
        return const Color(0xFF9E9E9E); // Grey
      case OrderStatus.cancelled:
        return const Color(0xFFF44336); // Red
    }
  }
}