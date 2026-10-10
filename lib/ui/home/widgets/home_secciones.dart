// lib/ui/home/widgets/home_secciones.dart
//
// Secciones del inicio que solo pintan datos: carrusel de productos
// (destacados, pide de nuevo, mejor calificados, recién llegados),
// reseñas destacadas y por qué elegirnos.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/tarjeta_producto_angosta.dart';
import 'package:pier_pasteleria/ui/products/widgets/product_detail_screen.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:provider/provider.dart';

/// Título con "Ver más" y carrusel horizontal de productos.
class HomeSeccionProductos extends StatelessWidget {
  const HomeSeccionProductos({
    required this.title,
    required this.productos,
    this.titleIcon,
    super.key,
  });

  final String title;
  final List<Product> productos;
  final IconData? titleIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (titleIcon != null) ...[
                      Icon(titleIcon, color: AppColors.pierVerde, size: 20),
                      const SizedBox(width: 6),
                    ],
                    Text(title,
                        style: const TextStyle(
                            fontFamily: 'Playfair Display',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                  ],
                ),
                GestureDetector(
                  onTap: () => context.read<NavigationProvider>().goCatalogo(),
                  child: Text('Ver más',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.pierVerde,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 310,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: productos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final p = productos[i];
                return GestureDetector(
                  onTap: () {
                    PierLog.nav('→ ProductDetailScreen: ${p.nombre}');
                    Navigator.push(context,
                        MaterialPageRoute<void>(
                            builder: (_) => ProductDetailScreen(product: p)));
                  },
                  child: TarjetaProductoAngosta(
                    producto: p,
                    precio: p.precio,
                    insignias: p.popular ? const _BadgePopular() : null,
                    // De adorno: tocar la tarjeta abre el detalle.
                    boton: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.pierVerde,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6)],
                      ),
                      child: const Icon(LucideIcons.plus,
                          color: Colors.white, size: 18),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgePopular extends StatelessWidget {
  const _BadgePopular();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.pierDorado,
        borderRadius: BorderRadius.circular(7),
        boxShadow: [BoxShadow(
            color: AppColors.pierDorado.withValues(alpha: 0.5), blurRadius: 6)],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: Colors.white, size: 9),
          SizedBox(width: 3),
          Text('POPULAR',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

/// Reseñas destacadas de clientes.
class HomeResenasDestacadas extends StatelessWidget {
  const HomeResenasDestacadas({
    required this.resenas,
    super.key,
  });

  final List<Map<String, dynamic>> resenas;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.star_rounded, color: AppColors.pierDorado, size: 20),
            SizedBox(width: 6),
            Text('Lo que dicen nuestros clientes',
                style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 14),
          ...resenas.map((r) {
            final nombre =
                '${r['autor_nombre'] ?? ''} ${r['autor_apellido'] ?? ''}'.trim();
            final iniciales = nombre.length >= 2
                ? nombre.substring(0, 2).toUpperCase()
                : nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
            final rating =
                double.tryParse(r['rating']?.toString() ?? '5') ?? 5.0;
            final comentario = r['comentario']?.toString() ?? '';
            final producto = r['producto_nombre']?.toString() ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          AppColors.pierDorado.withValues(alpha: 0.15),
                      child: Text(iniciales,
                          style: TextStyle(
                              color: AppColors.pierDoradoOscuro,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nombre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if (producto.isNotEmpty)
                            Text(producto,
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Row(
                        children: List.generate(
                            5,
                            (i) => Icon(
                                  i < rating.floor()
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: Colors.amber,
                                  size: 14))),
                  ]),
                  const SizedBox(height: 10),
                  Text(comentario,
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Por qué elegirnos.
class HomePorQueElegirnos extends StatelessWidget {
  const HomePorQueElegirnos({super.key});

  @override
  Widget build(BuildContext context) {
    final features = [
      {'icon': LucideIcons.leaf,             'title': 'Natural',   'desc': 'Sin conservadores'},
      {'icon': LucideIcons.handshake,       'title': 'Artesanal', 'desc': 'Hecho a mano'},
      {'icon': Icons.star_outline_rounded,     'title': 'Calidad',   'desc': 'Ingredientes Premium'},
      {'icon': Icons.favorite_outline_rounded, 'title': 'Amor',      'desc': 'Recetas de casa'},
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        children: [
          const Text('¿Por qué elegirnos?',
              style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: features.map((f) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.pierVerde.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(f['icon'] as IconData,
                          color: AppColors.pierVerde, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(f['title'] as String,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary)),
                          Text(f['desc'] as String,
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
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
