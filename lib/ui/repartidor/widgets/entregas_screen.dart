// lib/ui/repartidor/widgets/entregas_screen.dart
//
// Pestaña «Mis entregas» (MVVM, Fase 5): disponibilidad, el pool de pedidos
// que se pueden tomar y las entregas en curso. Los datos vienen del
// RepartidorViewModel del shell; las tarjetas están en entregas_tarjetas.dart.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/repartidor/view_model/repartidor_view_model.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/entregas_tarjetas.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/repartidor_ui.dart';
import 'package:provider/provider.dart';

class EntregasScreen extends StatelessWidget {
  const EntregasScreen({required this.viewModel, super.key});

  final RepartidorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final user = context.watch<AuthProvider>().currentUser;

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
                iniciales: inicialesDe(
                  user?['nombre']?.toString() ?? '',
                  user?['apellido']?.toString() ?? '',
                ),
                size: 44,
                background: AppColors.pierVerde,
                foreground: Colors.white,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListenableBuilder(
            listenable: viewModel,
            builder: (context, _) => viewModel.cargando
                ? Center(
                    child:
                        CircularProgressIndicator(color: AppColors.pierVerde))
                : RefreshIndicator(
                    color: AppColors.pierVerde,
                    onRefresh: viewModel.recargar,
                    child: _lista(),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _lista() {
    final vm = viewModel;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (vm.errorCarga != null) ...[
          _ErrorCarga(mensaje: vm.errorCarga!),
          const SizedBox(height: 16),
        ],
        _DisponibilidadCard(viewModel: vm),
        const SizedBox(height: 20),

        // ── Pool de pedidos disponibles para tomar ──
        if (vm.disponibles.isNotEmpty) ...[
          TituloSeccion('Disponibles', count: vm.disponibles.length),
          const SizedBox(height: 12),
          ...vm.disponibles.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DisponibleCard(pedido: p, viewModel: vm),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // ── Mis entregas en curso ──
        TituloSeccion('En curso', count: vm.activas.length),
        const SizedBox(height: 12),
        if (vm.activas.isEmpty)
          _EmptyState(disponible: vm.disponible)
        else
          ...vm.activas.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: EntregaCard(entrega: e, viewModel: vm),
            ),
          ),
      ],
    );
  }
}

class _DisponibilidadCard extends StatelessWidget {
  const _DisponibilidadCard({required this.viewModel});

  final RepartidorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final n = viewModel.activas.length;
    final s = n == 1 ? '' : 's';
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
              SwitchDisponible(viewModel: viewModel),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                viewModel.disponible
                    ? LucideIcons.zap
                    : LucideIcons.circlePause,
                size: 18,
                color: AppColors.pierVerde,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  !viewModel.disponible
                      ? 'No estás recibiendo entregas'
                      : n == 0
                          ? 'Sin entregas activas por ahora'
                          : 'Tienes $n entrega$s activa$s para hoy',
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

/// Aviso de que la última carga de entregas falló.
class _ErrorCarga extends StatelessWidget {
  const _ErrorCarga({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.wifiOff, size: 20, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$mensaje. Desliza hacia abajo para reintentar.',
              style: const TextStyle(fontSize: 13, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.disponible});

  final bool disponible;

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
                disponible ? LucideIcons.truck : LucideIcons.circlePause,
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
                  ? 'Toma un pedido de "Disponibles"\ny aparecerá aquí.'
                  : 'Actívate arriba para tomar\nnuevas entregas.',
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
