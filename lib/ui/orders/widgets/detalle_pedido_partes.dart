// lib/ui/orders/widgets/detalle_pedido_partes.dart
//
// Piezas del detalle de un pedido: la tarjeta con título, las filas de
// información (ícono + etiqueta + valor), el renglón de cada producto y el
// botón «Cancelar pedido».
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/order_model.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';

/// Tarjeta blanca con [titulo] arriba de [child].
class TarjetaDetalle extends StatelessWidget {
  const TarjetaDetalle({required this.titulo, required this.child, super.key});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Fila de «Información del pedido»: ícono, etiqueta y valor.
class FilaInfo extends StatelessWidget {
  const FilaInfo({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    super.key,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: AppColors.pierVerde.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icono, size: 16, color: AppColors.pierVerde),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etiqueta,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const SizedBox(height: 2),
              Text(valor,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Separador entre filas de una tarjeta.
class DivisorDetalle extends StatelessWidget {
  const DivisorDetalle({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Divider(height: 1, color: Colors.grey.withValues(alpha: 0.12)),
      );
}

/// Un producto del pedido: «2× $90 c/u · grande» y su subtotal.
class RenglonProducto extends StatelessWidget {
  const RenglonProducto({required this.item, super.key});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final tamano = item.tamano != null ? ' · ${item.tamano}' : '';
    return Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: AppColors.pierVerde.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(LucideIcons.cake, color: AppColors.pierVerde, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.nombre,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(
              '${item.cantidad}× '
              '\$${item.precioUnitario.toStringAsFixed(0)} c/u$tamano',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
      Text(
        '\$${item.subtotal.toStringAsFixed(0)}',
        style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AppColors.pierDoradoOscuro),
      ),
    ]);
  }
}

/// «Cancelar pedido» con su nota; mientras [cancelando] muestra un spinner.
class BotonCancelarPedido extends StatelessWidget {
  const BotonCancelarPedido({
    required this.cancelando,
    required this.onCancelar,
    super.key,
  });

  final bool cancelando;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: cancelando ? null : onCancelar,
          icon: cancelando
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.error))
              : const Icon(LucideIcons.circleX,
                  size: 18, color: AppColors.error),
          label: Text(cancelando ? 'Cancelando…' : 'Cancelar pedido',
              style: const TextStyle(
                  color: AppColors.error, fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text('Disponible mientras tu pedido no haya sido tomado',
          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
    ]);
  }
}
