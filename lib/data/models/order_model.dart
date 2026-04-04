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

  factory Order.fromJson(Map<String, dynamic> json) {
    // Parsear items del pedido
    final itemsRaw = json['items'] ?? json['productos'] ?? [];
    final items = (itemsRaw as List)
        .map((i) => CartItem.fromJson(i as Map<String, dynamic>))
        .toList();

    return Order(
      id: json['id_pedido']?.toString() ??
          json['id']?.toString() ??
          json['numero_pedido']?.toString() ??
          '',
      items: items,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      tax: double.tryParse(json['impuesto']?.toString() ??
              json['tax']?.toString() ??
              '0') ??
          0.0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      sucursal: json['sucursal'] ??
          json['nombre_sucursal'] ??
          json['sucursal_nombre'] ??
          '',
      deliveryDate: json['fecha_entrega'] != null
          ? DateTime.tryParse(json['fecha_entrega'].toString()) ??
              DateTime.now()
          : DateTime.now(),
      deliveryTime: json['hora_entrega'] ?? json['hora_recoleccion'] ?? '',
      notes: json['notas'] ?? json['notes'] ?? '',
      status: _parseStatus(
          json['estado'] ?? json['status'] ?? 'pending'),
      createdAt: json['fecha_creacion'] != null
          ? DateTime.tryParse(json['fecha_creacion'].toString()) ??
              DateTime.now()
          : json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString()) ??
                  DateTime.now()
              : DateTime.now(),
    );
  }

  static OrderStatus _parseStatus(dynamic status) {
    switch (status.toString().toLowerCase()) {
      case 'pending':
      case 'pendiente':
        return OrderStatus.pending;
      case 'preparing':
      case 'preparando':
      case 'en_preparacion':
        return OrderStatus.preparing;
      case 'ready':
      case 'listo':
      case 'listo_para_recoger':
        return OrderStatus.ready;
      case 'completed':
      case 'completado':
      case 'entregado':
        return OrderStatus.completed;
      case 'cancelled':
      case 'cancelado':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  int get totalQuantity =>
      items.fold(0, (sum, item) => sum + item.quantity);

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
        return const Color(0xFFFFA500);
      case OrderStatus.preparing:
        return const Color(0xFF2196F3);
      case OrderStatus.ready:
        return const Color(0xFF4CAF50);
      case OrderStatus.completed:
        return const Color(0xFF9E9E9E);
      case OrderStatus.cancelled:
        return const Color(0xFFF44336);
    }
  }
}