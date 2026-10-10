// lib/ui/home/widgets/home_encabezado.dart
//
// Parte de arriba del inicio: saludo con campana de notificaciones, banner
// del pedido activo, buscador (lleva al catálogo) y chips de categoría.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/order_model.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/state/notification_provider.dart';
import 'package:pier_pasteleria/ui/core/state/product_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/notifications/widgets/notifications_screen.dart';
import 'package:pier_pasteleria/ui/orders/widgets/order_detail_screen.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:provider/provider.dart';

IconData _iconoDeCategoria(String nombre) {
  switch (nombre.toLowerCase()) {
    case 'pasteles':  return LucideIcons.cake;
    case 'roscas':    return LucideIcons.donut;
    case 'pays':      return LucideIcons.chartPie;
    case 'postres':   return LucideIcons.cookie;
    case 'cafetería':
    case 'cafeteria': return LucideIcons.coffee;
    case 'bebidas':   return LucideIcons.cupSoda;
    case 'panes':     return LucideIcons.croissant;
    default:          return LucideIcons.sandwich;
  }
}

/// "Hola, Ana" (o "Bienvenido") y, con sesión, la campana con no leídas.
class HomeEncabezado extends StatelessWidget {
  const HomeEncabezado({
    required this.auth,
    required this.onVolverDeNotificaciones,
    super.key,
  });

  final AuthProvider auth;

  /// Al regresar de notificaciones (pudo cambiar el estado de un pedido).
  final VoidCallback onVolverDeNotificaciones;

  @override
  Widget build(BuildContext context) {
    final nombre =
        auth.currentUser?['nombre']?.toString().split(' ').first ?? '';
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20, right: 20, bottom: 16,
      ),
      color: AppColors.pierArena,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.isAuthenticated && nombre.isNotEmpty
                      ? 'Hola, $nombre'
                      : 'Bienvenido',
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                const Text('Descubre algo dulce hoy',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (auth.isAuthenticated)
            GestureDetector(
              onTap: () async {
                PierLog.nav('→ NotificationsScreen');
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => const NotificationsScreen()),
                );
                onVolverDeNotificaciones();
              },
              child: Builder(builder: (context) {
                final count = context.watch<NotificationProvider>().noLeidas;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2))],
                      ),
                      child: const Icon(LucideIcons.bell,
                          color: AppColors.textPrimary, size: 20),
                    ),
                    if (count > 0)
                      Positioned(
                        right: -2, top: -2,
                        child: Container(
                          width: 16, height: 16,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                          child: Center(
                            child: Text(
                              count > 9 ? '9+' : '$count',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              }),
            ),
        ],
      ),
    );
  }
}

/// Aviso del pedido en curso; tocarlo abre su detalle.
class PedidoActivoBanner extends StatelessWidget {
  const PedidoActivoBanner({required this.pedido, super.key});

  final Order pedido;

  @override
  Widget build(BuildContext context) {
    final numero = pedido.numero;
    final (IconData icon, String mensaje, Color color) = switch (pedido.status) {
      OrderStatus.preparing => (
          LucideIcons.cookingPot,
          'Pedido #$numero en preparación',
          AppColors.estadoPreparacion,
        ),
      OrderStatus.ready => (
          Icons.check_circle_outline_rounded,
          pedido.esDomicilio
              ? 'Pedido #$numero listo, buscando repartidor'
              : 'Pedido #$numero listo para recoger',
          AppColors.pierVerde,
        ),
      // 'pendiente' es exclusivo de los pedidos programados que el personal
      // debe confirmar (backend: por_confirmar).
      _ => (
          LucideIcons.hourglass,
          pedido.porConfirmar
              ? 'Pedido #$numero: confirmando disponibilidad'
              : 'Pedido #$numero recibido, en cola',
          AppColors.estadoPendiente,
        ),
    };
    return GestureDetector(
      onTap: () {
        PierLog.nav('→ OrderDetailScreen');
        Navigator.push(context,
            MaterialPageRoute<void>(builder: (_) => OrderDetailScreen(order: pedido)));
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(mensaje,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                    height: 1.3)),
          ),
          Icon(LucideIcons.chevronRight, color: color, size: 20),
        ]),
      ),
    );
  }
}

/// Buscador de adorno: lleva al catálogo.
class HomeBuscador extends StatelessWidget {
  const HomeBuscador({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: GestureDetector(
        onTap: () => context.read<NavigationProvider>().goCatalogo(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.2)),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3))],
          ),
          child: Row(
            children: [
              Icon(LucideIcons.search, color: AppColors.textSecondary.withValues(alpha: 0.5), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Busca tu pastel favorit...',
                    style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.pierVerde,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Text('Buscar',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hasta 5 categorías con cuántos productos disponibles tiene cada una;
/// tocar una abre el catálogo ya filtrado.
class HomeCategorias extends StatelessWidget {
  const HomeCategorias({required this.nombres, super.key});

  final List<String> nombres;

  @override
  Widget build(BuildContext context) {
    // Conteo por categoría (mismo dato que la web) calculado del catálogo ya
    // cargado; sin productos aún no se pinta el badge.
    final conteos = <String, int>{};
    for (final p in context.read<ProductProvider>().productos) {
      if (p.disponible) {
        conteos[p.categoria] = (conteos[p.categoria] ?? 0) + 1;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Categorías',
              style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: nombres.take(5).map((nombre) {
              final total = conteos[nombre] ?? 0;
              return GestureDetector(
                // Abre el catálogo YA filtrado por la categoría tocada
                onTap: () => context
                    .read<NavigationProvider>()
                    .goCatalogo(categoria: nombre),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(
                                color: Colors.black.withValues(alpha: 0.07),
                                blurRadius: 10,
                                offset: const Offset(0, 4))],
                          ),
                          child: Icon(_iconoDeCategoria(nombre),
                              color: AppColors.pierVerde, size: 26),
                        ),
                        if (total > 0)
                          Positioned(
                            top: -2, right: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.pierVerde,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.white, width: 1.5),
                              ),
                              child: Text('$total',
                                  style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(nombre,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
