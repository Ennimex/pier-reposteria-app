// lib/ui/repartidor/widgets/entregas_screen.dart
//
// "Mis entregas": disponibilidad + lista de entregas en curso.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/entregas_provider.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/entrega_detail_screen.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/repartidor_ui.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

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
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
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
              ? Center(
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

                      // ── Pool de pedidos disponibles para tomar ──
                      if (provider.disponibles.isNotEmpty) ...[
                        _SectionTitle(
                          'Disponibles',
                          count: provider.disponibles.length,
                        ),
                        const SizedBox(height: 12),
                        ...provider.disponibles.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _DisponibleCard(pedido: p),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // ── Mis entregas en curso ──
                      _SectionTitle(
                        'En curso',
                        count: provider.activas.length,
                      ),
                      const SizedBox(height: 12),
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
                provider.disponible ? LucideIcons.zap : LucideIcons.circlePause,
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
                const Icon(LucideIcons.clock,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    formatHorarioEntrega(entrega.horarioEntrega),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (entrega.metodoPago != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
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
                ],
                Text(
                  formatMoneyMxn(entrega.total),
                  style: TextStyle(
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;
  const _SectionTitle(this.title, {required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Playfair Display',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.pierVerde.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.pierVerde,
              ),
            ),
          ),
      ],
    );
  }
}

/// Tarjeta de un pedido del pool con botón para tomarlo.
class _DisponibleCard extends StatefulWidget {
  final PedidoDisponible pedido;
  const _DisponibleCard({required this.pedido});

  @override
  State<_DisponibleCard> createState() => _DisponibleCardState();
}

class _DisponibleCardState extends State<_DisponibleCard> {
  bool _aceptando = false;

  Future<void> _aceptar() async {
    final provider = context.read<EntregasProvider>();
    setState(() => _aceptando = true);
    final res = await provider.aceptar(widget.pedido.pedidoId);
    if (!mounted) return;
    setState(() => _aceptando = false);

    final ok = res['success'] == true;
    final msg = res['message']?.toString() ??
        (ok ? 'Pedido tomado' : 'No se pudo tomar el pedido');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? AppColors.pierVerde : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pierVerde.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.pierVerde.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.numero,
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                formatMoneyMxn(p.total),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.pierVerde,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            p.clienteNombreCompleto,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(LucideIcons.mapPin,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  p.direccion.colonia ?? 'Sin colonia',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (p.horarioEntrega != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(LucideIcons.clock,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    formatHorarioEntrega(p.horarioEntrega),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _aceptando ? null : _aceptar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pierVerde,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _aceptando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(LucideIcons.check, size: 20),
              label: Text(_aceptando ? 'Tomando…' : 'Tomar entrega'),
            ),
          ),
        ],
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
