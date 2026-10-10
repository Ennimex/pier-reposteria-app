// lib/ui/checkout/widgets/checkout_partes.dart
//
// Piezas pequeñas del checkout: tarjeta blanca, títulos de sección, avisos
// (fuera de servicio, pedidos especiales, error del pago) y el método de
// pago.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';

/// Fondo blanco redondeado con sombra suave de las secciones.
BoxDecoration decoracionTarjeta() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4)),
      ],
    );

class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.titulo, {super.key});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(titulo,
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.pierVerdeOscuro)),
    );
  }
}

/// Aviso cuando el pedido se hace fuera del horario de atención.
class AvisoFueraDeServicio extends StatelessWidget {
  const AvisoFueraDeServicio({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.clock,
                color: AppColors.error, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fuera de servicio',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error)),
                SizedBox(height: 2),
                Text(
                  'En este momento estamos cerrados. Horario: '
                  '${BusinessInfo.horario}. Puedes dejar tu pedido y lo '
                  'prepararemos en horario de atención.',
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Los pedidos especiales requieren anticipación y número de pedido.
class NotaPedidosEspeciales extends StatelessWidget {
  const NotaPedidosEspeciales({required this.esDomicilio, super.key});

  final bool esDomicilio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pierDorado.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.pierDorado.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info, color: AppColors.pierDoradoOscuro, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.pierDoradoOscuro),
                children: [
                  const TextSpan(
                      text: 'Nota importante: ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(
                      text: 'Los pedidos especiales requieren realizarse con 3 días '
                          'de anticipación. ${esDomicilio ? 'Ten a la mano tu número de pedido al recibir.' : 'Presenta tu número de pedido al recoger.'}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de crédito / débito con Stripe (único método).
class CheckoutMetodoPago extends StatelessWidget {
  const CheckoutMetodoPago({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoracionTarjeta(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.pierVerde.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(LucideIcons.creditCard,
                color: AppColors.pierVerde, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tarjeta de crédito / débito',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                SizedBox(height: 2),
                Text('Pago seguro con Stripe',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Icon(LucideIcons.lock, color: AppColors.pierVerde, size: 20),
        ],
      ),
    );
  }
}

/// Recuadro rojo con el error del último pago.
class AvisoErrorPago extends StatelessWidget {
  const AvisoErrorPago(this.mensaje, {super.key});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        const Icon(LucideIcons.circleAlert, color: AppColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(mensaje,
              style: const TextStyle(color: AppColors.error, fontSize: 13)),
        ),
      ]),
    );
  }
}
