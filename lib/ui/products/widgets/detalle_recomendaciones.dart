// lib/ui/products/widgets/detalle_recomendaciones.dart
//
// "Otros clientes también pidieron" (recomendaciones del backend por
// co-compra). Cada recomendado se resuelve contra el catálogo ya cargado para
// recuperar descripción y rating (el payload de /recomendaciones es reducido).
// La sección abre su espacio cuando llegan, las tarjetas entran desde la
// derecha y su foto vuela al detalle que abren.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/ui/core/state/cart_provider.dart';
import 'package:pier_reposteria/ui/core/state/product_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/core/ui/tarjeta_producto_angosta.dart';
import 'package:pier_reposteria/ui/products/widgets/detalle_badges.dart';
import 'package:provider/provider.dart';

class DetalleRecomendaciones extends StatelessWidget {
  const DetalleRecomendaciones({
    required this.recomendaciones,
    required this.catalogo,
    required this.animaciones,
    required this.onAbrir,
    required this.onAgregar,
    this.ambitoFoto,
    super.key,
  });

  final List<Product> recomendaciones;

  /// Catálogo y promociones (para completar datos y precios con descuento).
  final ProductProvider catalogo;

  /// Rebote del botón de carrito por producto (lo anima la pantalla).
  final Map<String, Animation<double>> animaciones;
  final ValueChanged<Product> onAbrir;

  /// Agregar un recomendado; recibe también el contexto del botón tocado
  /// (de ahí sale la miniatura que vuela al carrito).
  final void Function(Product producto, BuildContext boton) onAgregar;

  /// Ámbito del Hero de las fotos de estas tarjetas: el detalle que abren
  /// usa el mismo, así la foto vuela (null = sin Hero).
  final String? ambitoFoto;

  @override
  Widget build(BuildContext context) {
    final items = recomendaciones.map((r) {
      final delCatalogo = catalogo.productos.where((p) => p.id == r.id);
      return delCatalogo.isNotEmpty ? delCatalogo.first : r;
    }).toList();
    // Las recomendaciones llegan con el detalle ya abierto: la sección abre
    // su espacio y aparece en vez de saltar.
    return Aparicion(
      visible: recomendaciones.isNotEmpty,
      child: Column(
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
            // Las tarjetas entran desde la derecha en cascada, una sola vez:
            // volver con scroll no las repite.
            child: AmbitoEntradas(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final p = items[i];
                  return EntradaSuave(
                    key: ValueKey<String>(p.id),
                    id: p.id,
                    desplazamiento:
                        const Offset(AppMovimiento.distanciaLarga, 0),
                    child: PresionEscala(
                      child: GestureDetector(
                        onTap: () => onAbrir(p),
                        child: ProductoRelacionadoCard(
                          producto: p,
                          promociones: catalogo,
                          ambitoFoto: ambitoFoto,
                          animacionCarrito: animaciones[p.id],
                          onAgregar: (boton) => onAgregar(p, boton),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
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
    this.ambitoFoto,
    super.key,
  });

  final Product producto;
  final ProductProvider promociones;

  /// Recibe el contexto del botón tocado (de ahí sale la miniatura que vuela
  /// al carrito).
  final ValueChanged<BuildContext> onAgregar;
  final Animation<double>? animacionCarrito;

  /// Ámbito del Hero de la foto (TarjetaProductoAngosta.ambitoFoto).
  final String? ambitoFoto;

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
      ambitoFoto: ambitoFoto,
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

/// Botón + de la tarjeta: se hunde al presionarlo y el ícono cambia con un
/// rebote (+ → palomita al agregarlo).
class _BotonAgregarRelacionado extends StatelessWidget {
  const _BotonAgregarRelacionado({
    required this.productoId,
    required this.onTap,
    required this.animacion,
  });

  final String productoId;

  /// Recibe el contexto de este botón (de ahí sale la miniatura al carrito).
  final ValueChanged<BuildContext> onTap;
  final Animation<double>? animacion;

  @override
  Widget build(BuildContext context) {
    final enCarrito =
        context.select<CartProvider, bool>((c) => c.isInCart(productoId));
    // El rebote va siempre en el mismo lugar del árbol (en reposo, escala
    // 1): cuando llega con el primer alta, el botón no se vuelve a montar y
    // su cambio + → palomita se alcanza a ver.
    return ScaleTransition(
      scale: animacion ?? kAlwaysCompleteAnimation,
      child: PresionEscala(
        escala: AppMovimiento.escalaPresionChica,
        child: GestureDetector(
          onTap: () => onTap(context),
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: AppColors.pierVerde,
              borderRadius: BorderRadius.circular(9),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
            ),
            child: CambioAnimado(
              tipo: TipoCambio.escalar,
              alineacion: Alignment.center,
              child: Icon(
                enCarrito ? LucideIcons.check : LucideIcons.plus,
                key: ValueKey<bool>(enCarrito),
                color: Colors.white, size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
