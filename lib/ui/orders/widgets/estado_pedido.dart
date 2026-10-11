// lib/ui/orders/widgets/estado_pedido.dart
//
// Estado de un pedido como lo pintan «Mis Pedidos» y el detalle: el chip con
// la etiqueta corta y el color del estado, y el ícono de cada estado.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/order_model.dart';

/// Chip redondeado con el estado del pedido («Listo», «En camino»…).
class EstadoPedidoChip extends StatelessWidget {
  const EstadoPedidoChip({required this.pedido, super.key});

  final Order pedido;

  @override
  Widget build(BuildContext context) {
    final color = pedido.statusColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(pedido.estadoCorto,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

/// Ícono de cada estado (cabecera del detalle y pasos de la línea de tiempo).
IconData iconoEstadoPedido(OrderStatus estado) => switch (estado) {
      OrderStatus.pending => LucideIcons.inbox,
      OrderStatus.preparing => LucideIcons.cookingPot,
      OrderStatus.ready => Icons.check_circle_outline,
      OrderStatus.completed || OrderStatus.delivered => LucideIcons.checkCheck,
      OrderStatus.cancelled => LucideIcons.circleX,
      OrderStatus.assigned => LucideIcons.userRound,
      OrderStatus.onTheWay => LucideIcons.truck,
      OrderStatus.deliveryFailed => LucideIcons.circleAlert,
    };
