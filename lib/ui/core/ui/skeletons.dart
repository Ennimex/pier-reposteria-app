// lib/ui/core/ui/skeletons.dart
//
// Placeholders animados (shimmer) reutilizables para los estados de carga.
// Cada tarjeta se auto-envuelve en Shimmer para poder usarse dentro de slivers
// (donde no se puede envolver todo el grid/lista de una sola vez).
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';

/// Envuelve un contenido en el shimmer con los colores de la paleta.
Widget _shimmer({required Widget child}) => Shimmer.fromColors(
      baseColor: AppColors.textSecondary.withValues(alpha: 0.14),
      highlightColor: AppColors.textSecondary.withValues(alpha: 0.04),
      child: child,
    );

Widget _box(double h, double w, {double radius = 8}) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );

/// Skeleton de una tarjeta de producto (para grids de catálogo / favoritos).
class ProductSkeletonCard extends StatelessWidget {
  const ProductSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _shimmer(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(12, double.infinity),
                  const SizedBox(height: 8),
                  _box(12, 90),
                  const SizedBox(height: 14),
                  _box(16, 70),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton de una tarjeta de pedido (para listas como "Mis pedidos").
class OrderSkeletonCard extends StatelessWidget {
  const OrderSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _shimmer(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _box(56, 56, radius: 12),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(14, double.infinity),
                  const SizedBox(height: 10),
                  _box(12, 120),
                  const SizedBox(height: 14),
                  _box(12, 80),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _box(24, 60, radius: 20),
          ],
        ),
      ),
    );
  }
}
