// lib/ui/repartidor/widgets/historial_repartidor_screen.dart
//
// Pestaña «Historial» (MVVM, Fase 5): entregas finalizadas hoy (entregadas y
// fallidas) y el total del día. Los datos vienen del RepartidorViewModel
// del shell.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/repartidor/view_model/repartidor_view_model.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/entregas_tarjetas.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/repartidor_ui.dart';
import 'package:provider/provider.dart';

class HistorialRepartidorScreen extends StatelessWidget {
  const HistorialRepartidorScreen({required this.viewModel, super.key});

  final RepartidorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final historial = viewModel.historial;
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
                    style:
                        TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: viewModel.cargando
                  ? Center(
                      child: CircularProgressIndicator(
                          color: AppColors.pierVerde))
                  : RefreshIndicator(
                      color: AppColors.pierVerde,
                      onRefresh: viewModel.recargar,
                      child: historial.isEmpty
                          ? const _SinHistorial()
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(20, 16, 20, 24),
                              itemCount: historial.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 28),
                              itemBuilder: (_, i) => _HistorialItem(
                                entrega: historial[i],
                                viewModel: viewModel,
                              ),
                            ),
                    ),
            ),
            if (historial.isNotEmpty) _TotalDiaBar(viewModel: viewModel),
          ],
        );
      },
    );
  }
}

class _SinHistorial extends StatelessWidget {
  const _SinHistorial();

  @override
  Widget build(BuildContext context) {
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
                  Icon(LucideIcons.history,
                      size: 60, color: AppColors.textSecondary),
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
  const _HistorialItem({required this.entrega, required this.viewModel});

  final EntregaRepartidor entrega;
  final RepartidorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final entregada = entrega.estado == EstadoEntrega.entregada;
    final color = entregada ? AppColors.pierVerde : AppColors.error;

    return GestureDetector(
      onTap: () => abrirEntrega(context, entrega, viewModel),
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
                  color: color,
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
          IconoTexto(
            icono: LucideIcons.mapPin,
            texto: entrega.direccion.colonia ?? 'Sin colonia',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: IconoTexto(
                  icono: LucideIcons.clock,
                  texto: entrega.finalizadoAt != null
                      ? formatHora(entrega.finalizadoAt!)
                      : '—',
                  tamanoTexto: 13,
                ),
              ),
              Text(
                entregada ? formatMoneyMxn(entrega.total) : 'Fallida',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
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
  const _TotalDiaBar({required this.viewModel});

  final RepartidorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final entregas = viewModel.entregadasCount;
    final fallos = viewModel.fallidasCount;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pierVerde,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
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
                  formatMoneyMxn(viewModel.totalDia),
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$entregas entrega${entregas == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$fallos fallo${fallos == 1 ? '' : 's'}',
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
