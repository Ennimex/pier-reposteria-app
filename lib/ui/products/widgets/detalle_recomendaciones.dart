// lib/ui/products/widgets/detalle_recomendaciones.dart
//
// "Otros clientes también pidieron" (recomendaciones del backend por
// co-compra). Cada recomendado se resuelve contra el catálogo ya cargado para
// recuperar descripción y rating (el payload de /recomendaciones es reducido).
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/product_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/products/widgets/detalle_badges.dart';
import 'package:provider/provider.dart';

class DetalleRecomendaciones extends StatelessWidget {
  const DetalleRecomendaciones({
    required this.recomendaciones,
    required this.catalogo,
    required this.animaciones,
    required this.onAbrir,
    required this.onAgregar,
    super.key,
  });

  final List<Product> recomendaciones;

  /// Catálogo y promociones (para completar datos y precios con descuento).
  final ProductProvider catalogo;

  /// Rebote del botón de carrito por producto (lo anima la pantalla).
  final Map<String, Animation<double>> animaciones;
  final ValueChanged<Product> onAbrir;
  final ValueChanged<Product> onAgregar;

  @override
  Widget build(BuildContext context) {
    if (recomendaciones.isEmpty) return const SizedBox.shrink();
    final items = recomendaciones.map((r) {
      final delCatalogo = catalogo.productos.where((p) => p.id == r.id);
      return delCatalogo.isNotEmpty ? delCatalogo.first : r;
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 36),
        const Text('Otros clientes también pidieron',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 14),
        SizedBox(
          // Misma altura que las tarjetas de home y catálogo
          height: 310,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final p = items[i];
              return GestureDetector(
                onTap: () => onAbrir(p),
                child: ProductoRelacionadoCard(
                  producto: p,
                  promociones: catalogo,
                  animacionCarrito: animaciones[p.id],
                  onAgregar: () => onAgregar(p),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Tarjeta angosta de un producto recomendado: foto con precio y badges,
/// botón de agregar y datos básicos.
class ProductoRelacionadoCard extends StatelessWidget {
  const ProductoRelacionadoCard({
    required this.producto,
    required this.promociones,
    required this.onAgregar,
    this.animacionCarrito,
    super.key,
  });

  final Product producto;
  final ProductProvider promociones;
  final VoidCallback onAgregar;
  final Animation<double>? animacionCarrito;

  @override
  Widget build(BuildContext context) {
    final p = producto;
    final tienePromo = promociones.tieneDescuento(p.id);
    final precioFinal = promociones.precioConDescuento(p.id, p.precio);
    final promo = promociones.promocionDeProducto(p.id);
    final porcentaje = promo?['descuento_porcentaje']?.toString();

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
                      '\$${precioFinal.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          shadows: [Shadow(color: Colors.black38, blurRadius: 4)]),
                    ),
                  ),
                  Positioned(
                    top: 8, left: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (p.popular && !tienePromo)
                          DetalleBadge(color: AppColors.pierDorado,
                              icon: Icons.star_rounded, label: 'Popular',
                              compacto: true),
                        if (tienePromo) ...[
                          if (porcentaje != null)
                            DetalleBadge(color: Colors.red.shade500,
                                icon: LucideIcons.tag,
                                label: '-$porcentaje%', compacto: true),
                          ...badgeDeTipoPromo(promo, largo: false, compacto: true),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 8, right: 8,
                    child: _BotonAgregarRelacionado(
                      productoId: p.id,
                      onTap: onAgregar,
                      animacion: animacionCarrito,
                    ),
                  ),
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
                        // Precio tachado si hay descuento
                        if (tienePromo) ...[
                          const SizedBox(height: 3),
                          Text('\$${p.precio.toStringAsFixed(0)}',
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

class _BotonAgregarRelacionado extends StatelessWidget {
  const _BotonAgregarRelacionado({
    required this.productoId,
    required this.onTap,
    required this.animacion,
  });

  final String productoId;
  final VoidCallback onTap;
  final Animation<double>? animacion;

  @override
  Widget build(BuildContext context) {
    final enCarrito =
        context.select<CartProvider, bool>((c) => c.isInCart(productoId));
    Widget boton = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: AppColors.pierVerde,
          borderRadius: BorderRadius.circular(9),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
        ),
        child: Icon(
          enCarrito ? LucideIcons.check : LucideIcons.plus,
          color: Colors.white, size: 18,
        ),
      ),
    );
    final anim = animacion;
    if (anim != null) boton = ScaleTransition(scale: anim, child: boton);
    return boton;
  }
}
