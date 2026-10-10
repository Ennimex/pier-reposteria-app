// lib/ui/cart/widgets/cart_resumen.dart
//
// Pie de «Mi Carrito»: subtotal tachado y descuentos (si los hay), total con
// IVA incluido y el botón para pasar al pago.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/ui/cart/view_model/cart_view_model.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/precios_carrito.dart';

class CartResumen extends StatelessWidget {
  const CartResumen({required this.viewModel, required this.onPagar, super.key});

  final CartViewModel viewModel;
  final VoidCallback onPagar;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: Column(
        children: [
          if (vm.tieneDescuentos) ...[
            ResumenDescuentos(
              subtotal: vm.totalOriginal,
              ahorro: vm.ahorro,
              sufijo: ' MXN',
            ),
            const SizedBox(height: 10),
            Divider(color: AppColors.textSecondary.withValues(alpha: 0.2)),
            const SizedBox(height: 10),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              Text(
                '\$${vm.total.toStringAsFixed(0)} MXN',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.pierVerde),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text('IVA incluido',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.5))),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: onPagar,
              icon: const Icon(LucideIcons.creditCard,
                  color: Colors.white, size: 20),
              label: const Text('Proceder al Pago',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pierVerde,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
