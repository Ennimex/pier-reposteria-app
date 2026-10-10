// lib/ui/products/widgets/detalle_galeria.dart
//
// Galería del detalle: carrusel de imágenes (con Hero desde la tarjeta del
// catálogo), botones de atrás, favorito y compartir, badges de promoción y
// puntos de página. La foto visible es estado de la interfaz.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/core/state/product_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/products/widgets/detalle_badges.dart';

class DetalleGaleria extends StatefulWidget {
  const DetalleGaleria({
    required this.producto,
    required this.imagenes,
    required this.promociones,
    required this.esFavorito,
    required this.onFavorito,
    required this.onCompartir,
    super.key,
  });

  final Product producto;
  final List<String> imagenes;
  final ProductProvider promociones;
  final bool esFavorito;
  final VoidCallback onFavorito;
  final VoidCallback onCompartir;

  @override
  State<DetalleGaleria> createState() => _DetalleGaleriaState();
}

class _DetalleGaleriaState extends State<DetalleGaleria> {
  int _pagina = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    final imagenes = widget.imagenes;
    final tienePromo = widget.promociones.tieneDescuento(p.id);
    final promo = widget.promociones.promocionDeProducto(p.id);
    final porcentaje = promo?['descuento_porcentaje']?.toString();

    return SizedBox(
      height: 360,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Hero: la imagen "vuela" desde la tarjeta del catálogo /
          // favoritos (mismo tag producto-img-<id>).
          Hero(
            tag: 'producto-img-${p.id}',
            child: PageView.builder(
              itemCount: imagenes.length,
              onPageChanged: (i) => setState(() => _pagina = i),
              itemBuilder: (context, i) => Image.network(
                imagenes[i],
                fit: BoxFit.cover,
                errorBuilder: (context, error, _) => ColoredBox(
                  color: AppColors.pierArena,
                  child: const Icon(LucideIcons.image,
                      size: 60, color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16, right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _BotonRedondo(
                    icon: LucideIcons.arrowLeft,
                    onTap: () => Navigator.pop(context)),
                Row(children: [
                  TweenAnimationBuilder<double>(
                    key: ValueKey(widget.esFavorito),
                    // Pop solo al marcar favorito
                    tween: Tween(
                        begin: widget.esFavorito ? 1.35 : 1.0, end: 1),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.elasticOut,
                    builder: (_, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: _BotonRedondo(
                      icon: widget.esFavorito
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      onTap: widget.onFavorito,
                      color: widget.esFavorito ? Colors.red : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _BotonRedondo(
                      icon: LucideIcons.share2, onTap: widget.onCompartir),
                ]),
              ],
            ),
          ),
          // Badges múltiples por tipo (igual que PromoBadge de la web)
          if (tienePromo || p.popular)
            Positioned(
              bottom: 20, left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.popular && !tienePromo)
                    DetalleBadge(color: AppColors.pierDorado,
                        icon: Icons.star_rounded, label: 'Popular'),
                  if (tienePromo) ...[
                    if (porcentaje != null)
                      DetalleBadge(color: Colors.red.shade500,
                          icon: LucideIcons.tag, label: '-$porcentaje%'),
                    ...badgeDeTipoPromo(promo, largo: true),
                  ],
                ],
              ),
            ),
          if (imagenes.length > 1)
            Positioned(
              bottom: 20, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    imagenes.length,
                    (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _pagina == i ? 20 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _pagina == i
                                ? AppColors.pierDorado
                                : Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )),
              ),
            ),
        ],
      ),
    );
  }
}

/// Botón blanco circular sobre la foto.
class _BotonRedondo extends StatelessWidget {
  const _BotonRedondo({required this.icon, required this.onTap, this.color});

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2))],
        ),
        child: Icon(icon, size: 20, color: color ?? AppColors.textPrimary),
      ),
    );
  }
}
