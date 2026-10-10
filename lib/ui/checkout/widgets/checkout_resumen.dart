// lib/ui/checkout/widgets/checkout_resumen.dart
//
// "Resumen del pedido": productos del carrito, descuentos, envío (a
// domicilio) y total a pagar.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/cart_item_model.dart';
import 'package:pier_pasteleria/ui/checkout/view_model/checkout_view_model.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/checkout_partes.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/precios_carrito.dart';
import 'package:provider/provider.dart';

class CheckoutResumen extends StatelessWidget {
  const CheckoutResumen({required this.viewModel, super.key});

  final CheckoutViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final vm = viewModel;
    final divisor = [
      const SizedBox(height: 10),
      Divider(color: AppColors.textSecondary.withValues(alpha: 0.2)),
      const SizedBox(height: 10),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoracionTarjeta(),
      child: Column(
        children: [
          ...cart.items.values.map(_renglon),
          const Divider(height: 24),
          if (cart.tieneDescuentos) ...[
            ResumenDescuentos(
              subtotal: cart.totalOriginal,
              ahorro: cart.totalAhorro,
              etiqueta: 'Descuentos aplicados',
            ),
            ...divisor,
          ],
          // Envío (solo domicilio)
          if (vm.esDomicilio) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(children: [
                  Icon(LucideIcons.truck, size: 16, color: AppColors.textSecondary),
                  SizedBox(width: 6),
                  Text('Costo de envío',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ]),
                Text(
                  switch (vm.direccion) {
                    null => '—',
                    final d when d.tieneCobertura =>
                      '\$${vm.costoEnvio.toStringAsFixed(0)}',
                    _ => 'Sin cobertura',
                  },
                  style: TextStyle(
                      color: vm.direccion?.tieneCobertura == false
                          ? AppColors.error
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
              ],
            ),
            ...divisor,
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total a Pagar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('\$${vm.totalConEnvio.toStringAsFixed(0)}',
                  style: TextStyle(
                      color: AppColors.pierVerde,
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _renglon(CartItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8)),
            child: Text('${item.quantity}x',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.pierVerde)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    item.tamano == 'grande'
                        ? '${item.nombre} (Grande)'
                        : item.nombre,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
                if (item.tieneDescuento) PrecioUnitario(linea: item),
              ],
            ),
          ),
          Text('\$${item.subtotal.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
