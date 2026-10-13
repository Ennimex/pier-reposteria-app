// lib/ui/checkout/widgets/checkout_resumen.dart
//
// "Resumen del pedido": productos del carrito, descuentos, envío (a
// domicilio) y total a pagar.
//
// Movimiento: el total cuenta hasta su nuevo valor (p. ej. al sumar el
// envío) y la fila del envío abre o cierra su espacio al cambiar entre
// domicilio y recoger. Tras pagar se queda con lo que se pagó: el carrito se
// vacía antes de navegar y el resumen no debe verse vacío mientras la
// pantalla se va.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/cart_item_model.dart';
import 'package:pier_pasteleria/ui/checkout/view_model/checkout_view_model.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/checkout_partes.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_pasteleria/ui/core/ui/precios_carrito.dart';
import 'package:provider/provider.dart';

class CheckoutResumen extends StatefulWidget {
  const CheckoutResumen({
    required this.viewModel,
    this.congelado = false,
    super.key,
  });

  final CheckoutViewModel viewModel;

  /// true tras un pago exitoso: sigue mostrando lo último que pintó.
  final bool congelado;

  @override
  State<CheckoutResumen> createState() => _CheckoutResumenState();
}

class _CheckoutResumenState extends State<CheckoutResumen> {
  // Lo último que se pintó (para quedarse quieto tras pagar).
  _Resumen? _ultimo;

  // Último texto del envío a domicilio: la fila lo conserva mientras se
  // desvanece al volver a recoger (para entonces el envío ya vale 0).
  String _envio = '—';
  bool _sinCobertura = false;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final vm = widget.viewModel;
    final previo = _ultimo;
    final r = widget.congelado && previo != null
        ? previo
        : _Resumen(
            lineas: cart.items.values.toList(),
            tieneDescuentos: cart.tieneDescuentos,
            totalOriginal: cart.totalOriginal,
            ahorro: cart.totalAhorro,
            esDomicilio: vm.esDomicilio,
            total: vm.totalConEnvio,
          );
    _ultimo = r;
    if (r.esDomicilio && !widget.congelado) {
      _envio = switch (vm.direccion) {
        null => '—',
        final d when d.tieneCobertura =>
          '\$${vm.costoEnvio.toStringAsFixed(0)}',
        _ => 'Sin cobertura',
      };
      _sinCobertura = vm.direccion?.tieneCobertura == false;
    }
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
          ...r.lineas.map(_renglon),
          const Divider(height: 24),
          if (r.tieneDescuentos) ...[
            ResumenDescuentos(
              subtotal: r.totalOriginal,
              ahorro: r.ahorro,
              etiqueta: 'Descuentos aplicados',
            ),
            ...divisor,
          ],
          // Envío (solo domicilio): la fila abre su espacio al elegir
          // domicilio y lo cierra al volver a recoger.
          Aparicion(
            visible: r.esDomicilio,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(children: [
                      Icon(LucideIcons.truck,
                          size: 16, color: AppColors.textSecondary),
                      SizedBox(width: 6),
                      Text('Costo de envío',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14)),
                    ]),
                    // El costo nuevo rueda a su lugar al cambiar de dirección.
                    CambioAnimado(
                      tipo: TipoCambio.subir,
                      alineacion: AlignmentDirectional.centerEnd,
                      child: Text(
                        _envio,
                        key: ValueKey(_envio),
                        style: TextStyle(
                            color: _sinCobertura
                                ? AppColors.error
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                    ),
                  ],
                ),
                ...divisor,
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total a Pagar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              MontoAnimado(
                valor: r.total,
                formato: (v) => '\$${v.toStringAsFixed(0)}',
                estilo: TextStyle(
                    color: AppColors.pierVerde,
                    fontWeight: FontWeight.bold,
                    fontSize: 20),
              ),
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

/// Lo que pinta el resumen en un cuadro.
class _Resumen {
  const _Resumen({
    required this.lineas,
    required this.tieneDescuentos,
    required this.totalOriginal,
    required this.ahorro,
    required this.esDomicilio,
    required this.total,
  });

  final List<CartItem> lineas;
  final bool tieneDescuentos;
  final double totalOriginal;
  final double ahorro;
  final bool esDomicilio;
  final double total;
}
