// lib/presentation/screens/client/checkout/order_success_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../main_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String orderId;
  final String pickupDate;
  final String pickupTime;
  final double total;

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.pickupDate,
    required this.pickupTime,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── ÍCONO ────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: Colors.green[50], shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: Colors.green, size: 60),
              ),
              const SizedBox(height: 24),
              const Text('¡Pedido Confirmado!',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.pierVerdeOscuro)),
              const SizedBox(height: 8),
              Text(
                'Tu pedido #$orderId ha sido registrado.\nTe notificaremos cuando esté listo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              ),

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
                    _buildRow(Icons.store, 'Sucursal',
                        'Principal — Huejutla de Reyes'),
                    const Divider(height: 24),
                    _buildRow(Icons.calendar_today, 'Fecha de recogida',
                        pickupDate),
                    const Divider(height: 24),
                    _buildRow(
                        Icons.access_time, 'Horario', pickupTime),
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
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: AppColors.pierVerde),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── BOTÓN ────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MainScreen()),
                    (r) => false,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pierVerde,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Volver al Inicio',
                      style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.pierVerde),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary)),
      ],
    );
  }
}