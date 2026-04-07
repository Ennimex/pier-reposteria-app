// lib/data/models/order_model.dart
import 'package:flutter/material.dart';

enum OrderStatus { pending, preparing, ready, completed, cancelled }

class OrderItem {
  final String nombre;
  final int cantidad;
  final String? tamano;
  final double precioUnitario;
  final double subtotal;

  OrderItem({
    required this.nombre,
    required this.cantidad,
    this.tamano,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      nombre: json['nombre_producto'] ?? json['nombre'] ?? '',
      cantidad: int.tryParse(json['cantidad']?.toString() ?? '1') ?? 1,
      tamano: json['tamano'],
      precioUnitario:
          double.tryParse(json['precio_unitario']?.toString() ?? '0') ?? 0.0,
      subtotal:
          double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class Order {
  final String id;
  final String numero;
  final List<OrderItem> items;
  final double total;
  final String? notas;
  final String? horarioRecogida;
  final String? metodoPago;
  final OrderStatus status;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.numero,
    required this.items,
    required this.total,
    this.notas,
    this.horarioRecogida,
    this.metodoPago,
    this.status = OrderStatus.pending,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] ?? [];
    final items = (itemsRaw as List)
        .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
        .toList();

    return Order(
      id: json['id']?.toString() ?? '',
      // El backend devuelve 'numero' (ej. PIER-260404-1234)
      numero: json['numero']?.toString() ?? json['id']?.toString() ?? '',
      items: items,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      notas: json['notas'],
      // El backend devuelve horario_recogida
      horarioRecogida: json['horario_recogida'],
      metodoPago: json['metodo_pago'],
      status: _parseStatus(json['estado'] ?? 'pendiente'),
      // El backend devuelve created_at
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
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
        return OrderStatus.ready;
      case 'completed':
      case 'completado':
        return OrderStatus.completed;
      case 'cancelled':
      case 'cancelado':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  String get statusText {
    switch (status) {
      case OrderStatus.pending:    return 'Pendiente';
      case OrderStatus.preparing:  return 'En preparación';
      case OrderStatus.ready:      return 'Listo para recoger';
      case OrderStatus.completed:  return 'Completado';
      case OrderStatus.cancelled:  return 'Cancelado';
    }
  }

  Color get statusColor {
    switch (status) {
      case OrderStatus.pending:    return const Color(0xFFFFA500);
      case OrderStatus.preparing:  return const Color(0xFF2196F3);
      case OrderStatus.ready:      return const Color(0xFF4CAF50);
      case OrderStatus.completed:  return const Color(0xFF9E9E9E);
      case OrderStatus.cancelled:  return const Color(0xFFF44336);
    }
  }
}