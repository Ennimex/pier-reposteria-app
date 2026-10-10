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
import 'package:pier_pasteleria/ui/core/ui/tarjeta_producto_angosta.dart';
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

/// Tarjeta de un producto recomendado: precio con descuento, badges de
/// promoción y botón de agregar al carrito.
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
    final promo = promociones.promocionDeProducto(p.id);
    final porcentaje = promo?['descuento_porcentaje']?.toString();

    return TarjetaProductoAngosta(
      producto: p,
      precio: promociones.precioConDescuento(p.id, p.precio),
      precioTachado: tienePromo ? p.precio : null,
      insignias: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.popular && !tienePromo)
            DetalleBadge(color: AppColors.pierDorado,
                icon: Icons.star_rounded, label: 'Popular', compacto: true),
          if (tienePromo) ...[
            if (porcentaje != null)
              DetalleBadge(color: Colors.red.shade500,
                  icon: LucideIcons.tag, label: '-$porcentaje%', compacto: true),
            ...badgeDeTipoPromo(promo, largo: false, compacto: true),
          ],
        ],
      ),
      boton: _BotonAgregarRelacionado(
        productoId: p.id,
        onTap: onAgregar,
        animacion: animacionCarrito,
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
