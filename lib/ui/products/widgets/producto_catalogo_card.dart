// lib/ui/products/widgets/producto_catalogo_card.dart
//
// Tarjeta de un producto del catálogo, en cuadrícula o en lista: imagen con
// badges de promoción, corazón de favorito, precio (con descuento) y botón de
// agregar ("Avísame" si está agotado). Solo pinta: las acciones llegan por
// callbacks desde la pantalla (MVVM, Fase 4).
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/product_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:provider/provider.dart';

class ProductoCatalogoCard extends StatelessWidget {
  const ProductoCatalogoCard({
    required this.producto,
    required this.promociones,
    required this.enCuadricula,
    required this.esFavorito,
    required this.onTap,
    required this.onToggleFavorito,
    required this.onAgregar,
    this.animacionCarrito,
    super.key,
  });

  final Product producto;

  /// Fuente de promociones y precios con descuento.
  final ProductProvider promociones;
  final bool enCuadricula;
  final bool esFavorito;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorito;
  final VoidCallback onAgregar;

  /// Rebote del botón al agregar al carrito (lo anima la pantalla).
  final Animation<double>? animacionCarrito;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: enCuadricula ? _buildGridCard() : _buildListCard(),
        ),
      ),
    );
  }

  Widget _buildGridCard() {
    final p = producto;
    final tienePromo = promociones.tieneDescuento(p.id);
    final precioFinal = promociones.precioConDescuento(p.id, p.precio);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 55,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _imagen(tamanoIcono: 40),
              // Columna de badges por tipo (igual que el web)
              Positioned(
                top: 8, left: 8,
                child: _badges(compacto: false),
              ),
              Positioned(
                top: 8, right: 8,
                child: _BotonFavorito(
                  esFavorito: esFavorito,
                  onTap: onToggleFavorito,
                  diametro: 32,
                  tamanoIcono: 16,
                  difuminado: 8,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 45,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Precio con tachado si hay descuento
                Row(
                  children: [
                    Text('\$${precioFinal.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: tienePromo ? Colors.red.shade600 : AppColors.pierDoradoOscuro)),
                    if (tienePromo) ...[
                      const SizedBox(width: 5),
                      Text('\$${p.precio.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.5), decoration: TextDecoration.lineThrough)),
                    ],
                  ],
                ),
                if (p.categoria.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.pierVerde.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(p.categoria,
                        style: TextStyle(fontSize: 9, color: AppColors.pierVerde, fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(height: 3),
                Text(p.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(p.descripcion,
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.3),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _calificacion(tamanoEstrella: 13),
                    _BotonAgregar(
                      producto: p,
                      onTap: onAgregar,
                      animacion: animacionCarrito,
                      compacto: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListCard() {
    final p = producto;
    final tienePromo = promociones.tieneDescuento(p.id);
    final precioFinal = promociones.precioConDescuento(p.id, p.precio);

    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _imagen(tamanoIcono: 36),
              // Badges múltiples apilados igual que el web
              Positioned(
                top: 6, left: 6,
                child: _badges(compacto: true),
              ),
              Positioned(
                bottom: 8, right: 8,
                child: _BotonFavorito(
                  esFavorito: esFavorito,
                  onTap: onToggleFavorito,
                  diametro: 28,
                  tamanoIcono: 14,
                  difuminado: 6,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(p.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(p.descripcion,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Precio con tachado en lista
                        Row(children: [
                          Text('\$${precioFinal.toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800,
                                  color: tienePromo ? Colors.red.shade600 : AppColors.pierDoradoOscuro)),
                          if (tienePromo) ...[
                            const SizedBox(width: 6),
                            Text('\$${p.precio.toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.5),
                                    decoration: TextDecoration.lineThrough)),
                          ],
                        ]),
                        _calificacion(tamanoEstrella: 12),
                      ],
                    ),
                    _BotonAgregar(
                      producto: p,
                      onTap: onAgregar,
                      animacion: animacionCarrito,
                      compacto: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _imagen({required double tamanoIcono}) => Hero(
        tag: 'producto-img-${producto.id}',
        child: Image.network(producto.imagenUrl, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ColoredBox(
              color: AppColors.pierArena,
              child: Icon(LucideIcons.cake, color: AppColors.pierVerde, size: tamanoIcono),
            )),
      );

  Widget _calificacion({required double tamanoEstrella}) => Row(children: [
        Icon(Icons.star_rounded, color: Colors.amber, size: tamanoEstrella),
        const SizedBox(width: 3),
        Text(producto.rating > 0 ? producto.rating.toStringAsFixed(1) : '—',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      ]);

  /// Agotado, Popular y los de la promoción activa. En cuadrícula "Popular"
  /// solo sale si no hay promo; en lista ([compacto]) sale siempre.
  Widget _badges({required bool compacto}) {
    final p = producto;
    final tienePromo = promociones.tieneDescuento(p.id);
    final promo = promociones.promocionDeProducto(p.id);
    final tipo = promo?['tipo']?.toString() ?? '';
    final porcentaje = promo?['descuento_porcentaje']?.toString();
    final badgeDestacado = promo?['badge_destacado']?.toString();

    Widget badge(Color color, IconData icon, String label) =>
        _Badge(color: color, icon: icon, label: label, compacto: compacto);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Agotado (stock_online = 0): el backend rechaza agregarlo
        if (p.agotado) badge(AppColors.textSecondary, LucideIcons.ban, 'Agotado'),
        if (p.popular && (compacto || !tienePromo))
          badge(AppColors.pierDorado, Icons.star_rounded, 'Popular'),
        if (tienePromo) ...[
          if (porcentaje != null)
            badge(Colors.red.shade500, LucideIcons.tag, '-$porcentaje%'),
          if (tipo == 'relampago')
            badge(Colors.orange.shade600, LucideIcons.zap, 'Flash'),
          if (tipo == 'temporada')
            badge(Colors.orange.shade700, LucideIcons.sparkles, 'Temporada'),
          if (tipo == 'destacado' && badgeDestacado != null)
            badge(Colors.purple.shade500, LucideIcons.sparkles, badgeDestacado),
          if (tipo == 'nuevo')
            badge(Colors.blue.shade500, LucideIcons.badgePlus, 'Nuevo'),
        ],
      ],
    );
  }
}

/// Corazón de favorito con "pop" al marcar (al desmarcar entra sin rebote).
class _BotonFavorito extends StatelessWidget {
  const _BotonFavorito({
    required this.esFavorito,
    required this.onTap,
    required this.diametro,
    required this.tamanoIcono,
    required this.difuminado,
  });

  final bool esFavorito;
  final VoidCallback onTap;
  final double diametro;
  final double tamanoIcono;
  final double difuminado;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: diametro, height: diametro,
        decoration: BoxDecoration(
          color: esFavorito ? Colors.red : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: difuminado)],
        ),
        child: TweenAnimationBuilder<double>(
          key: ValueKey(esFavorito),
          tween: Tween(begin: esFavorito ? 1.6 : 1.0, end: 1),
          duration: const Duration(milliseconds: 450),
          curve: Curves.elasticOut,
          builder: (_, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Icon(
            esFavorito ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: esFavorito ? Colors.white : AppColors.textSecondary,
            size: tamanoIcono,
          ),
        ),
      ),
    );
  }
}

/// Botón de agregar al carrito (palomita si ya está). Agotado: campana de
/// "Avísame", con texto en la vista de lista.
class _BotonAgregar extends StatelessWidget {
  const _BotonAgregar({
    required this.producto,
    required this.onTap,
    required this.animacion,
    required this.compacto,
  });

  final Product producto;
  final VoidCallback onTap;
  final Animation<double>? animacion;

  /// Cuadrícula: botón cuadrado de 34. Lista: botón ancho con "Avísame".
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final enCarrito =
        context.select<CartProvider, bool>((c) => c.isInCart(producto.id));
    final agotado = producto.agotado;
    final icono = Icon(
        agotado
            ? LucideIcons.bellRing
            : enCarrito ? LucideIcons.check : LucideIcons.plus,
        color: Colors.white, size: 20);
    Widget boton = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: compacto ? 34 : null,
        height: compacto ? 34 : null,
        padding: compacto
            ? null
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: agotado ? AppColors.pierDorado : AppColors.pierVerde,
            borderRadius: BorderRadius.circular(compacto ? 10 : 12)),
        child: agotado && !compacto
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.bellRing, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text('Avísame',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ])
            : icono,
      ),
    );
    final anim = animacion;
    if (anim != null) boton = ScaleTransition(scale: anim, child: boton);
    return boton;
  }
}

/// Badge de promoción; [compacto] = texto más chico (vista de lista).
class _Badge extends StatelessWidget {
  const _Badge({
    required this.color,
    required this.icon,
    required this.label,
    required this.compacto,
  });

  final Color color;
  final IconData icon;
  final String label;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: EdgeInsets.symmetric(
          horizontal: compacto ? 5 : 7, vertical: compacto ? 2 : 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: compacto ? 8 : 9),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: compacto ? 7 : 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2)),
        ],
      ),
    );
  }
}
