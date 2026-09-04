// lib/ui/repartidor/widgets/perfil_repartidor_screen.dart
//
// "Perfil" del repartidor: datos, estado de servicio (disponibilidad),
// métricas del día y cerrar sesión.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/entregas_provider.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/repartidor_ui.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

class PerfilRepartidorScreen extends StatelessWidget {
  const PerfilRepartidorScreen({super.key});

  String _iniciales(String nombre, String apellido) {
    final ini =
        '${nombre.isNotEmpty ? nombre[0] : ''}${apellido.isNotEmpty ? apellido[0] : ''}'
            .toUpperCase();
    return ini.isEmpty ? '?' : ini;
  }

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
    if (confirm != true || !context.mounted) return;

    context.read<EntregasProvider>().clear();
    await context.read<AuthProvider>().logout();
    if (context.mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<EntregasProvider>();
    final user = auth.currentUser ?? {};

    final nombre = user['nombre']?.toString() ?? '';
    final apellido = user['apellido']?.toString() ?? '';
    final email = user['email']?.toString() ?? '—';
    final telefono = user['telefono']?.toString() ?? '—';
    final id = user['id']?.toString() ?? '';

    return ListView(
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
                iniciales: _iniciales(nombre, apellido),
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
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
                      provider.disponible
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
              Switch(
                value: provider.disponible,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.pierVerde,
                onChanged: (v) => provider.setDisponible(v),
              ),
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
              _infoRow(LucideIcons.mail, 'Correo electrónico', email),
              const Divider(height: 1, indent: 68, endIndent: 20),
              _infoRow(LucideIcons.phone, 'Teléfono', telefono),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── MÉTRICAS ────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _statTile(
                'Entregas hoy',
                '${provider.entregadasCount}',
                AppColors.pierVerde,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _statTile(
                'En curso',
                '${provider.activas.length}',
                AppColors.pierDoradoOscuro,
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
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
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
            child: Icon(icon, size: 20, color: AppColors.pierDoradoOscuro),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
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

  Widget _statTile(String label, String value, Color color) {
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
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
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
