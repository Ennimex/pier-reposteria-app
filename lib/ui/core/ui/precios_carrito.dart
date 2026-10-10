// lib/ui/core/ui/precios_carrito.dart
//
// Precios con descuento que comparten el carrito y el resumen del checkout:
// el precio unitario de una línea (con el de lista tachado) y el par
// «Subtotal tachado / Descuentos» antes del total.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/cart_item_model.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';

/// «$90 c/u» y, si la línea tiene descuento, el precio de lista tachado.
class PrecioUnitario extends StatelessWidget {
  const PrecioUnitario({required this.linea, super.key});

  final CartItem linea;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '\$${linea.precio.toStringAsFixed(0)} c/u',
          style: TextStyle(
              fontSize: 12,
              color: AppColors.pierVerde,
              fontWeight: FontWeight.w600),
        ),
        if (linea.tieneDescuento) ...[
          const SizedBox(width: 6),
          Text(
            '\$${linea.precioOriginal.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
                decoration: TextDecoration.lineThrough),
          ),
        ],
      ],
    );
  }
}

/// Subtotal sin descuentos (tachado) y el ahorro, con [sufijo] tras cada
/// monto (p. ej. « MXN»).
class ResumenDescuentos extends StatelessWidget {
  const ResumenDescuentos({
    required this.subtotal,
    required this.ahorro,
    this.etiqueta = 'Descuentos',
    this.sufijo = '',
    super.key,
  });

  final double subtotal;
  final double ahorro;
  final String etiqueta;
  final String sufijo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subtotal',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            Text(
              '\$${subtotal.toStringAsFixed(0)}$sufijo',
              style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  decoration: TextDecoration.lineThrough),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(LucideIcons.tag, size: 14, color: AppColors.pierVerde),
              const SizedBox(width: 6),
              Text(etiqueta,
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.pierVerde,
                      fontWeight: FontWeight.w600)),
            ]),
            Text(
              '-\$${ahorro.toStringAsFixed(0)}$sufijo',
              style: TextStyle(
                  fontSize: 14,
                  color: AppColors.pierVerde,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}
