// lib/ui/notifications/widgets/notificaciones_partes.dart
//
// Piezas de «Notificaciones»: la tarjeta de cada aviso (resaltada mientras
// no se lee) y el mensaje a pantalla completa que sirve para la lista vacía y
// para el error de carga.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/notificacion.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';

/// Un aviso: ícono según su tipo, título, mensaje (2 líneas) y [cuando].
class NotificacionTarjeta extends StatelessWidget {
  const NotificacionTarjeta({
    required this.notificacion,
    required this.cuando,
    required this.onTap,
    super.key,
  });

  final Notificacion notificacion;

  /// «Hace 5 min», «Ayer, 6:30 PM»…
  final String cuando;
  final VoidCallback onTap;

  static IconData icono(String tipo) => switch (tipo) {
        'pedido' => LucideIcons.shoppingBag,
        'promocion' => LucideIcons.tag,
        'resena' => Icons.star_outline_rounded,
        'reembolso' => LucideIcons.rotateCcw,
        'producto' => LucideIcons.cake,
        _ => LucideIcons.bell,
      };

  @override
  Widget build(BuildContext context) {
    final leida = notificacion.leida;
    return GestureDetector(
      onTap: onTap,
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
              : Border.all(color: AppColors.pierVerde.withValues(alpha: 0.15)),
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: leida
                    ? AppColors.textSecondary.withValues(alpha: 0.08)
                    : AppColors.pierVerde.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono(notificacion.tipo),
                  color: leida
                      ? AppColors.textSecondary.withValues(alpha: 0.5)
                      : AppColors.pierVerde,
                  size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: _textos()),
            if (!leida) ...[
              const SizedBox(width: 8),
              Container(
                key: const ValueKey('punto-no-leida'),
                width: 8,
                height: 8,
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

  Widget _textos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          notificacion.titulo,
          style: TextStyle(
              fontWeight: notificacion.leida ? FontWeight.w500 : FontWeight.bold,
              fontSize: 14,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          notificacion.mensaje,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 6),
        Text(
          cuando,
          style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

/// Mensaje a pantalla completa con un botón: la lista vacía («Explorar
/// Menú») o el error de carga («Reintentar»).
class AvisoNotificaciones extends StatelessWidget {
  const AvisoNotificaciones({
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.boton,
    required this.iconoBoton,
    required this.onPressed,
    super.key,
  });

  final IconData icono;
  final String titulo;
  final String texto;
  final String boton;
  final IconData iconoBoton;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: AppColors.pierVerde.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icono,
                  size: 56, color: AppColors.pierVerde.withValues(alpha: 0.45)),
            ),
            const SizedBox(height: 28),
            Text(titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onPressed,
                icon: Icon(iconoBoton, color: Colors.white, size: 18),
                label: Text(boton,
                    style: const TextStyle(
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
}
