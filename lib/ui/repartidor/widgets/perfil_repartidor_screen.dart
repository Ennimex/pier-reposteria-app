// lib/ui/repartidor/widgets/perfil_repartidor_screen.dart
//
// Pestaña «Perfil» del repartidor (MVVM, Fase 5): datos de la sesión,
// estado de servicio (disponibilidad), métricas del día y cerrar sesión.
// Disponibilidad y métricas vienen del RepartidorViewModel del shell.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/repartidor/view_model/repartidor_view_model.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/repartidor_ui.dart';
import 'package:provider/provider.dart';

class PerfilRepartidorScreen extends StatelessWidget {
  const PerfilRepartidorScreen({required this.viewModel, super.key});

  final RepartidorViewModel viewModel;

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres cerrar tu sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (!(confirm ?? false) || !context.mounted) return;

    // El panel (y su ViewModel) se desmonta al salir: no hay estado que
    // limpiar a mano.
    await context.read<AuthProvider>().logout();
    if (context.mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final user = context.watch<AuthProvider>().currentUser ?? {};

    final nombre = user['nombre']?.toString() ?? '';
    final apellido = user['apellido']?.toString() ?? '';
    final email = user['email']?.toString() ?? '—';
    final telefono = user['telefono']?.toString() ?? '—';
    final id = user['id']?.toString() ?? '';

    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          // ── HEADER ──────────────────────────────────────────────
          const Text(
            'Perfil',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // ── TARJETA IDENTIDAD ───────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.pierDorado.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                InicialesAvatar(
                  iniciales: inicialesDe(nombre, apellido),
                  size: 92,
                  background: AppColors.pierVerde,
                  foreground: Colors.white,
                ),
                const SizedBox(height: 14),
                Text(
                  '$nombre $apellido'.trim(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Repartidor autorizado',
                  style:
                      TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                if (id.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      'ID: PIER-REP-${id.padLeft(3, '0')}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── ESTADO DE SERVICIO ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.pierDorado.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estado de servicio',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        viewModel.disponible
                            ? 'Disponible para entregas'
                            : 'No disponible',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SwitchDisponible(viewModel: viewModel),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── INFORMACIÓN PERSONAL ────────────────────────────────
          const Text(
            'Información personal',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.pierDorado.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _InfoFila(
                    icono: LucideIcons.mail,
                    etiqueta: 'Correo electrónico',
                    valor: email),
                const Divider(height: 1, indent: 68, endIndent: 20),
                _InfoFila(
                    icono: LucideIcons.phone,
                    etiqueta: 'Teléfono',
                    valor: telefono),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── MÉTRICAS ────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _Metrica(
                  etiqueta: 'Entregas hoy',
                  valor: '${viewModel.entregadasCount}',
                  color: AppColors.pierVerde,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _Metrica(
                  etiqueta: 'En curso',
                  valor: '${viewModel.activas.length}',
                  color: AppColors.pierDoradoOscuro,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── CERRAR SESIÓN ───────────────────────────────────────
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _logout(context),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              icon: const Icon(LucideIcons.logOut, size: 18),
              label: const Text('Cerrar sesión'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoFila extends StatelessWidget {
  const _InfoFila({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, size: 20, color: AppColors.pierDoradoOscuro),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.pierVerde,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metrica extends StatelessWidget {
  const _Metrica({
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.pierDorado.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
