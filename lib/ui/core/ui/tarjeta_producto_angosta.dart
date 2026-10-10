// lib/ui/core/ui/tarjeta_producto_angosta.dart
//
// Tarjeta angosta de producto de los carruseles horizontales (inicio y
// "Otros clientes también pidieron"): foto con el precio encima, datos
// básicos y estrellas. Quien la usa pone los badges y el botón de la foto.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';

class TarjetaProductoAngosta extends StatelessWidget {
  const TarjetaProductoAngosta({
    required this.producto,
    required this.precio,
    required this.boton,
    this.insignias,
    this.precioTachado,
    super.key,
  });

  final Product producto;

  /// Precio que va sobre la foto.
  final double precio;

  /// Botón de la esquina inferior derecha de la foto.
  final Widget boton;

  /// Badges de la esquina superior izquierda de la foto.
  final Widget? insignias;

  /// Precio original tachado bajo la descripción (si hay descuento).
  final double? precioTachado;

  @override
  Widget build(BuildContext context) {
    final p = producto;
    final tachado = precioTachado;
    return Container(
      width: 165,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 55,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    p.imagenUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: AppColors.pierArena,
                      child: Icon(LucideIcons.cake,
                          color: AppColors.pierVerde, size: 40),
                    ),
                  ),
                  // Gradiente inferior para que se lea el precio
                  Positioned(
                    bottom: 0, left: 0, right: 0, height: 70,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10, left: 10,
                    child: Text(
                      '\$${precio.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          shadows: [Shadow(color: Colors.black38, blurRadius: 4)]),
                    ),
                  ),
                  if (insignias != null)
                    Positioned(top: 8, left: 8, child: insignias!),
                  Positioned(bottom: 8, right: 8, child: boton),
                ],
              ),
            ),
            Expanded(
              flex: 45,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.pierVerde.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(p.categoria,
                              style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.pierVerde,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 4),
                        Text(p.nombre,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(p.descripcion,
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        if (tachado != null) ...[
                          const SizedBox(height: 3),
                          Text('\$${tachado.toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                                  decoration: TextDecoration.lineThrough)),
                        ],
                      ],
                    ),
                    Row(children: [
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        p.rating > 0 ? p.rating.toStringAsFixed(1) : '—',
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600),
                      ),
                      if (p.totalResenas > 0) ...[
                        const SizedBox(width: 3),
                        Text('(${p.totalResenas})',
                            style: TextStyle(
                                fontSize: 9,
                                color: AppColors.textSecondary.withValues(alpha: 0.5))),
                      ],
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
