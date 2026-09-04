// lib/ui/notifications/widgets/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/state/notification_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    PierLog.nav('→ NotificationsScreen');
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    PierLog.info('Refrescando notificaciones...');
    await context.read<NotificationProvider>().refresh();
    if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _marcarTodasLeidas() async {
    PierLog.api('PUT /notificaciones/leer-todas');
    await context.read<NotificationProvider>().marcarTodasLeidas();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Todas marcadas como leídas'),
      backgroundColor: AppColors.pierVerde,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // Agrupa notificaciones por: Hoy, Ayer, Anteriores
  Map<String, List<Map<String, dynamic>>> _agrupar(
      List<Map<String, dynamic>> notificaciones) {
    final Map<String, List<Map<String, dynamic>>> grupos = {
      'Hoy': [],
      'Ayer': [],
      'Anteriores': [],
    };
    final now = DateTime.now();
    for (final n in notificaciones) {
      try {
        final dt = DateTime.parse(n['created_at'].toString()).toLocal();
        final diff = now.difference(dt);
        if (diff.inDays == 0) {
          grupos['Hoy']!.add(n);
        } else if (diff.inDays == 1) {
          grupos['Ayer']!.add(n);
        } else {
          grupos['Anteriores']!.add(n);
        }
      } catch (_) {
        grupos['Anteriores']!.add(n);
      }
    }
    grupos.removeWhere((_, v) => v.isEmpty);
    return grupos;
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final notifProvider = context.watch<NotificationProvider>();
    final notificaciones = notifProvider.notificaciones;
    final noLeidas = notifProvider.noLeidas;
    final grupos = _agrupar(notificaciones);

    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: const Icon(LucideIcons.chevronLeft,
                          size: 16, color: AppColors.textPrimary),
                    ),
                  ),
                  const Spacer(),
                  if (noLeidas > 0)
                    GestureDetector(
                      onTap: _marcarTodasLeidas,
                      child: Text('Leer todas',
                          style: TextStyle(
                              fontSize: 14,
                              color: AppColors.pierVerde,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),

            // ── TÍTULO + BADGE ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Notificaciones',
                      style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  if (noLeidas > 0) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.pierVerde,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$noLeidas',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),

            // ── LISTA ─────────────────────────────────────────────
            Expanded(
              child: _isRefreshing
                  ? Center(
                      child: CircularProgressIndicator(
                          color: AppColors.pierVerde))
                  : notificaciones.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          color: AppColors.pierVerde,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(
                                16, 0, 16, 32),
                            children: grupos.entries.map((entry) {
                              return Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // ── SEPARADOR DE GRUPO ─────────
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            vertical: 14),
                                    child: Center(
                                      child: Text(entry.key,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary,
                                              fontWeight:
                                                  FontWeight.w600,
                                              letterSpacing: 0.3)),
                                    ),
                                  ),
                                  // ── ITEMS DEL GRUPO ────────────
                                  ...entry.value.map((n) => Padding(
                                        padding:
                                            const EdgeInsets.only(
                                                bottom: 10),
                                        child: _buildItem(n),
                                      )),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> notif) {
    final bool leida = notif['leida'] == true;
    final tipo = notif['tipo']?.toString() ?? 'sistema';

    IconData icon;
    switch (tipo) {
      case 'pedido':    icon = LucideIcons.shoppingBag; break;
      case 'promocion': icon = LucideIcons.tag; break;
      case 'resena':    icon = Icons.star_outline_rounded; break;
      case 'reembolso': icon = LucideIcons.rotateCcw; break;
      case 'producto':  icon = LucideIcons.cake; break;
      default:          icon = LucideIcons.bell;
    }

    return GestureDetector(
      onTap: () {
        final id = notif['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          PierLog.info('Marcando leída: $id');
          context.read<NotificationProvider>().marcarLeida(id);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: leida
              ? Colors.white
              : AppColors.pierVerde.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: leida
              ? null
              : Border.all(
                  color:
                      AppColors.pierVerde.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícono
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: leida
                    ? AppColors.textSecondary.withValues(alpha: 0.08)
                    : AppColors.pierVerde.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: leida
                      ? AppColors.textSecondary.withValues(alpha: 0.5)
                      : AppColors.pierVerde,
                  size: 22),
            ),
            const SizedBox(width: 14),

            // Texto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif['titulo'] ?? '',
                    style: TextStyle(
                        fontWeight: leida
                            ? FontWeight.w500
                            : FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif['mensaje'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatFecha(notif['created_at']),
                    style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            // Punto no leída
            if (!leida) ...[
              const SizedBox(width: 8),
              Container(
                width: 8, height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: AppColors.pierVerde,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                color: AppColors.pierVerde.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.bellOff,
                  size: 56,
                  color:
                      AppColors.pierVerde.withValues(alpha: 0.45)),
            ),
            const SizedBox(height: 28),
            const Text('Sin notificaciones',
                style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            Text(
              'Aquí aparecerán tus pedidos, promociones y novedades de Pier Repostería.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  try {
                    context.read<NavigationProvider>().goCatalogo();
                  } catch (_) {}
                },
                icon: const Icon(LucideIcons.cake,
                    color: Colors.white, size: 18),
                label: const Text('Explorar Menú',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pierVerde,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFecha(dynamic fecha) {
    if (fecha == null) return '';
    try {
      final dt = DateTime.parse(fecha.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Ahora';
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
      if (diff.inHours < 24) {
        return 'Hace ${diff.inHours} '
            '${diff.inHours == 1 ? 'hora' : 'horas'}';
      }
      if (diff.inDays == 1) {
        final h = dt.hour.toString().padLeft(2, '0');
        final m = dt.minute.toString().padLeft(2, '0');
        return 'Ayer, $h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
      }
      // ✅ FIX: const en lugar de final
      const months = [
        'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
      ];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return '';
    }
  }
}