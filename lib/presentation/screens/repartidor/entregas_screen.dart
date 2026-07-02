// lib/presentation/screens/repartidor/entregas_screen.dart
//
// "Mis entregas": disponibilidad + lista de entregas en curso.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/entrega_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/entregas_provider.dart';
import 'entrega_detail_screen.dart';
import 'widgets/repartidor_ui.dart';

class EntregasScreen extends StatelessWidget {
  const EntregasScreen({super.key});

  String _iniciales(Map<String, dynamic>? user) {
    final n = (user?['nombre']?.toString() ?? '').trim();
    final a = (user?['apellido']?.toString() ?? '').trim();
    final ini = '${n.isNotEmpty ? n[0] : ''}${a.isNotEmpty ? a[0] : ''}'
        .toUpperCase();
    return ini.isEmpty ? '?' : ini;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final provider = context.watch<EntregasProvider>();

    return Column(
      children: [
        // ── HEADER ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              const Text(
                'Mis entregas',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              InicialesAvatar(
                iniciales: _iniciales(user),
                size: 44,
                background: AppColors.pierVerde,
                foreground: Colors.white,
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: provider.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.pierVerde))
              : RefreshIndicator(
                  color: AppColors.pierVerde,
                  onRefresh: () => provider.cargar(silent: true),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      _DisponibilidadCard(provider: provider),
                      const SizedBox(height: 20),
                      if (provider.activas.isEmpty)
                        _EmptyState(disponible: provider.disponible)
                      else
                        ...provider.activas.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _EntregaCard(entrega: e),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _DisponibilidadCard extends StatelessWidget {
  final EntregasProvider provider;
  const _DisponibilidadCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final n = provider.activas.length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pierDorado.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Disponible para entregas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Switch(
                value: provider.disponible,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.pierVerde,
                onChanged: (v) async {
                  final ok = await provider.setDisponible(v);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No se pudo cambiar la disponibilidad'),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                provider.disponible ? Icons.bolt : Icons.pause_circle_outline,
                size: 18,
                color: AppColors.pierVerde,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  provider.disponible
                      ? (n == 0
                          ? 'Sin entregas activas por ahora'
                          : 'Tienes $n entrega${n == 1 ? '' : 's'} activa${n == 1 ? '' : 's'} para hoy')
                      : 'No estás recibiendo entregas',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EntregaCard extends StatelessWidget {
  final EntregaRepartidor entrega;
  const _EntregaCard({required this.entrega});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EntregaDetailScreen(entrega: entrega),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.pierDorado.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entrega.numero,
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                EstadoEntregaChip(estado: entrega.estado),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              entrega.clienteNombreCompleto,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              entrega.direccion.colonia ?? 'Sin colonia',
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const Divider(height: 28),
            Row(
              children: [
                const Icon(Icons.access_time,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  entrega.horarioEntrega ?? 'Sin horario',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (entrega.metodoPago != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.textSecondary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      entrega.esEfectivo ? 'Efectivo' : 'Tarjeta',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                Text(
                  formatMoneyMxn(entrega.total),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.pierVerde,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool disponible;
  const _EmptyState({required this.disponible});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.pierVerde.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                disponible ? Icons.local_shipping_outlined : Icons.pause_circle,
                size: 46,
                color: AppColors.pierVerde.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              disponible ? 'Sin entregas por ahora' : 'No estás disponible',
              style: const TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              disponible
                  ? 'Cuando te asignen una entrega\naparecerá aquí.'
                  : 'Actívate arriba para recibir\nnuevas entregas.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
