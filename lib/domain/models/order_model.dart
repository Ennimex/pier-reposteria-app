// lib/domain/models/order_model.dart
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';

enum OrderStatus {
  pending,
  preparing,
  ready,
  completed,
  cancelled,
  // Estados del flujo a domicilio (backend: asignado/en_camino/entregado/entrega_fallida)
  assigned,
  onTheWay,
  delivered,
  deliveryFailed,
}

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
  final String? tipoEntrega; // 'pickup' | 'domicilio'
  final OrderStatus status;
  // Pedido programado con productos sin stock hoy: el personal debe
  // aprobarlo o rechazarlo (backend: tblpedidos.por_confirmar). Con el
  // flujo nuevo, todo pedido 'pendiente' nace con esta bandera.
  final bool porConfirmar;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.numero,
    required this.items,
    required this.total,
    this.notas,
    this.horarioRecogida,
    this.metodoPago,
    this.tipoEntrega,
    this.status = OrderStatus.pending,
    this.porConfirmar = false,
    required this.createdAt,
  });

  bool get esDomicilio => tipoEntrega == 'domicilio';

  /// Estados terminales: el pedido ya no está en curso (va a "Historial").
  bool get esFinalizado =>
      status == OrderStatus.completed ||
      status == OrderStatus.cancelled ||
      status == OrderStatus.delivered ||
      status == OrderStatus.deliveryFailed;

  /// El cliente puede cancelar su pedido mientras nadie lo haya tomado.
  /// Espejo de la regla del backend (PUT /pedidos/:id/cancelar): solo
  /// 'pendiente' o 'listo'; al pasar a 'asignado' ya no aplica.
  bool get esCancelablePorCliente =>
      status == OrderStatus.pending || status == OrderStatus.ready;

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
      tipoEntrega: json['tipo_entrega'],
      status: _parseStatus(json['estado'] ?? 'pendiente'),
      porConfirmar: json['por_confirmar'] == true ||
          json['por_confirmar']?.toString() == 'true' ||
          json['por_confirmar']?.toString() == 't',
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
      // Flujo a domicilio
      case 'asignado':
        return OrderStatus.assigned;
      case 'en_camino':
        return OrderStatus.onTheWay;
      case 'entregado':
        return OrderStatus.delivered;
      case 'entrega_fallida':
        return OrderStatus.deliveryFailed;
      default:
        return OrderStatus.pending;
    }
  }

  String get statusText {
    switch (status) {
      case OrderStatus.pending:    return porConfirmar ? 'Por confirmar' : 'Pendiente';
      case OrderStatus.preparing:  return 'En preparación';
      case OrderStatus.ready:      return esDomicilio ? 'Listo para envío' : 'Listo para recoger';
      case OrderStatus.completed:  return 'Completado';
      case OrderStatus.cancelled:  return 'Cancelado';
      case OrderStatus.assigned:       return 'Repartidor asignado';
      case OrderStatus.onTheWay:       return 'En camino';
      case OrderStatus.delivered:      return 'Entregado';
      case OrderStatus.deliveryFailed: return 'Entrega fallida';
    }
  }

  Color get statusColor {
    switch (status) {
      case OrderStatus.pending:    return AppColors.estadoPendiente;
      case OrderStatus.preparing:  return AppColors.estadoPreparacion;
      case OrderStatus.ready:      return AppColors.estadoListo;
      case OrderStatus.completed:  return AppColors.estadoCompletado;
      case OrderStatus.cancelled:  return AppColors.estadoCancelado;
      case OrderStatus.assigned:       return AppColors.estadoAsignada;
      case OrderStatus.onTheWay:       return AppColors.estadoEnCamino;
      case OrderStatus.delivered:      return AppColors.estadoEntregada;
      case OrderStatus.deliveryFailed: return AppColors.estadoFallida;
    }
  }
}