// lib/ui/checkout/widgets/order_success_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:provider/provider.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
class OrderSuccessScreen extends StatelessWidget {
  final String orderId;
  final String pickupDate;
  final String pickupTime;
  final double total;
  final bool esDomicilio;
  final String? direccionResumen;
  // Pedido programado con productos sin stock hoy: el personal confirmará
  // la disponibilidad para la fecha elegida.
  final bool porConfirmar;

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.pickupDate,
    required this.pickupTime,
    required this.total,
    this.esDomicilio = false,
    this.direccionResumen,
    this.porConfirmar = false,
  });

  void _goHome(BuildContext context) {
    // Esta pantalla vive apilada en el navigator interno del tab Carrito:
    // hay que vaciar esa pila (si no, el tab se queda mostrando el éxito y
    // habría que dar doble tap al tab para limpiarlo) y luego cambiar a Inicio.
    final nav = Navigator.of(context);
    context.read<NavigationProvider>().setSelectedIndex(0);
    nav.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome(context);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── ÍCONO ────────────────────────────────────────────────
                // Celebración: check Lottie (una sola reproducción) y el
                // resto de la pantalla lo sigue en cascada.
                Lottie.asset(
                  'assets/lottie/success_check.json',
                  width: 170,
                  height: 170,
                  fit: BoxFit.contain,
                  repeat: false,
                ),
                const SizedBox(height: 24),
                Text('¡Pedido Confirmado!',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.pierVerdeOscuro))
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 350.ms)
                    .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 8),
                Text(
                  porConfirmar
                      ? 'Tu pedido #$orderId ha sido registrado.\nEstamos confirmando la disponibilidad para tu fecha.'
                      : 'Tu pedido #$orderId ha sido registrado.\nTe notificaremos cuando esté listo.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 330.ms, duration: 350.ms),

                if (porConfirmar) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.pierDorado.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              AppColors.pierDorado.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.clock,
                            size: 18, color: AppColors.pierDoradoOscuro),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Como tu pedido es para otra fecha, te avisaremos '
                            'muy pronto si podemos prepararlo. Si no fuera '
                            'posible, tu pago se reembolsa completo.',
                            style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 400.ms, duration: 350.ms),
                ],

                const SizedBox(height: 40),

                // ── TICKET ───────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.pierArena.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.pierVerde.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      esDomicilio
                          ? _buildRow(
                              LucideIcons.bike,
                              'Entrega a domicilio',
                              direccionResumen ?? 'A tu domicilio')
                          : _buildRow(LucideIcons.store, 'Sucursal',
                              '${BusinessInfo.sucursal} — ${BusinessInfo.ciudad}'),
                      const Divider(height: 24),
                      _buildRow(
                          LucideIcons.calendar,
                          esDomicilio ? 'Fecha de entrega' : 'Fecha de recogida',
                          pickupDate),
                      const Divider(height: 24),
                      _buildRow(LucideIcons.clock, 'Horario', pickupTime),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total pagado',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary)),
                          Text(
                            '\$${total.toStringAsFixed(0)} MXN',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: AppColors.pierVerde),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 450.ms, duration: 400.ms)
                    .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),

                const Spacer(),

                // ── BOTÓN ────────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _goHome(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pierVerde,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Volver al Inicio',
                        style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ).animate().fadeIn(delay: 650.ms, duration: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.pierVerde),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary)),
        ),
      ],
    );
  }
}