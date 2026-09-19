// lib/ui/repartidor/widgets/historial_repartidor_screen.dart
//
// "Historial": entregas finalizadas hoy (entregadas y fallidas) + total del día.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/ui/core/state/entregas_provider.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/entrega_detail_screen.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/repartidor_ui.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

class HistorialRepartidorScreen extends StatelessWidget {
  const HistorialRepartidorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final provider = context.watch<EntregasProvider>();
    final historial = provider.historial;

    return Column(
      children: [
        // ── HEADER ──────────────────────────────────────────────
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Historial',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Entregas finalizadas hoy',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: provider.isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.pierVerde))
              : RefreshIndicator(
                  color: AppColors.pierVerde,
                  onRefresh: () => provider.cargar(silent: true),
                  child: historial.isEmpty
                      ? _empty()
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          itemCount: historial.length,
                          separatorBuilder: (_, _) => const Divider(height: 28),
                          itemBuilder: (_, i) =>
                              _HistorialItem(entrega: historial[i]),
                        ),
                ),
        ),
        if (historial.isNotEmpty) _TotalDiaBar(provider: provider),
      ],
    );
  }

  Widget _empty() {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.history, size: 60, color: AppColors.textSecondary),
                  SizedBox(height: 16),
                  Text(
                    'Aún no hay entregas finalizadas hoy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistorialItem extends StatelessWidget {
  final EntregaRepartidor entrega;
  const _HistorialItem({required this.entrega});

  @override
  Widget build(BuildContext context) {
    final entregada = entrega.estado == EstadoEntrega.entregada;
    final barColor = entregada ? AppColors.pierVerde : AppColors.error;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EntregaDetailScreen(entrega: entrega),
        ),
      ),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entrega.numero,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                width: 64,
                height: 10,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entrega.clienteNombreCompleto,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(LucideIcons.mapPin,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  entrega.direccion.colonia ?? 'Sin colonia',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(LucideIcons.clock,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                entrega.finalizadoAt != null
                    ? formatHora(entrega.finalizadoAt!)
                    : '—',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                entregada ? formatMoneyMxn(entrega.total) : 'Fallida',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: entregada ? AppColors.pierVerde : AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalDiaBar extends StatelessWidget {
  final EntregasProvider provider;
  const _TotalDiaBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pierVerde,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total del día',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatMoneyMxn(provider.totalDia),
                style: const TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${provider.entregadasCount} entrega${provider.entregadasCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${provider.fallidasCount} fallo${provider.fallidasCount == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
