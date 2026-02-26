import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../main_screen.dart'; 

class OrderSuccessScreen extends StatelessWidget {
  final String orderId;
  final String branchName;
  final String pickupDate;
  final String pickupTime;
  final double total;

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.branchName,
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
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.green, size: 60),
              ),
              const SizedBox(height: 24),
              const Text('¡Pago Exitoso!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.pierVerdeOscuro)),
              const SizedBox(height: 8),
              Text('Tu pedido #$orderId está confirmado.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              
              const SizedBox(height: 40),
              
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  // Usamos withValues para evitar deprecation warning
                  color: AppColors.pierArena.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.pierVerde.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    _buildTicketRow('Sucursal', branchName, icon: Icons.store),
                    const Divider(),
                    _buildTicketRow('Fecha', pickupDate, icon: Icons.calendar_today),
                    const Divider(),
                    _buildTicketRow('Hora', pickupTime, icon: Icons.access_time),
                    const Divider(),
                    _buildTicketRow('Total', '\$${total.toStringAsFixed(0)}', isBold: true),
                  ],
                ),
              ),
              
              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context, 
                    MaterialPageRoute(builder: (_) => const MainScreen()), 
                    (r) => false
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pierVerde,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Volver al Inicio', style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketRow(String label, String value, {bool isBold = false, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: Colors.grey), const SizedBox(width: 8)],
          Text(label, style: TextStyle(color: Colors.grey[700])),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? AppColors.pierVerde : Colors.black87)),
        ],
      ),
    );
  }
}