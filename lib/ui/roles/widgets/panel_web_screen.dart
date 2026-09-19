// lib/ui/roles/widgets/panel_web_screen.dart
//
// Pantalla para los roles internos (empleado, gerencia, direccion_general).
// Estos roles operan desde el panel web; la app móvil no tiene sus vistas.
// Se les da la bienvenida con su identidad de rol y se les invita a abrir el
// sitio web para tener una mejor perspectiva de su trabajo.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

/// Datos de presentación de cada rol interno (título, acento, icono).
class _RolInfo {
  final String panel;
  final String descripcion;
  final IconData icono;
  final Color acento;
  final Color acentoOscuro;

  const _RolInfo({
    required this.panel,
    required this.descripcion,
    required this.icono,
    required this.acento,
    required this.acentoOscuro,
  });

  /// Deriva la info a partir del rol del backend.
  static _RolInfo from(String? rol) {
    switch (rol) {
      case 'gerencia':
        return const _RolInfo(
          panel: 'Panel de Gerencia',
          descripcion:
              'Supervisión de operaciones, usuarios y reportes del negocio.',
          icono: LucideIcons.chartLine,
          acento: Color(0xFF2A4060),
          acentoOscuro: Color(0xFF1A2744),
        );
      case 'direccion_general':
        return const _RolInfo(
          panel: 'Panel de Dirección',
          descripcion:
              'Control general, configuración y estrategia de Pier Repostería.',
          icono: LucideIcons.award,
          acento: Color(0xFF5A3D7A),
          acentoOscuro: Color(0xFF2D1B4E),
        );
      case 'empleado':
      default:
        return _RolInfo(
          panel: 'Panel de Operación',
          descripcion:
              'Gestión de productos, pedidos, promociones y atención diaria.',
          icono: LucideIcons.store,
          acento: AppColors.pierVerde,
          acentoOscuro: AppColors.pierVerdeOscuro,
        );
    }
  }
}

class PanelWebScreen extends StatelessWidget {
  const PanelWebScreen({super.key});

  String _primerNombre(Map<String, dynamic>? user) {
    final n = (user?['nombre']?.toString() ?? '').trim();
    if (n.isEmpty) return '';
    return n.split(' ').first;
  }

  Future<void> _abrirSitio(BuildContext context) async {
    final uri = Uri.parse(BusinessInfo.sitioWeb);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el sitio web'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    await auth.logout();
    if (context.mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final auth = context.watch<AuthProvider>();
    final info = _RolInfo.from(auth.rol);
    final nombre = _primerNombre(auth.currentUser);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [info.acentoOscuro, info.acento],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              children: [
                // Cerrar sesión arriba a la derecha
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _cerrarSesion(context),
                    icon: const Icon(LucideIcons.logOut,
                        size: 18, color: Colors.white),
                    label: const Text(
                      'Cerrar sesión',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const Spacer(),

                // Icono del rol
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(info.icono, size: 54, color: Colors.white),
                ),
                const SizedBox(height: 24),

                // Saludo
                Text(
                  nombre.isEmpty ? '¡Hola!' : '¡Hola, $nombre!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  info.panel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 20),

                // Tarjeta con el mensaje principal
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Icon(LucideIcons.globe,
                          size: 30, color: info.acento),
                      const SizedBox(height: 12),
                      const Text(
                        'Es necesario que te dirijas al sitio web '
                        'para poder tener una mejor perspectiva.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        info.descripcion,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Botón: abrir sitio web
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _abrirSitio(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: info.acentoOscuro,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(LucideIcons.externalLink, size: 20),
                    label: const Text(
                      'Abrir sitio web',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  BusinessInfo.sitioWeb.replaceFirst('https://', ''),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
