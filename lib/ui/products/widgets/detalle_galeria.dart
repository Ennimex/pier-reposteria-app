// lib/ui/products/widgets/detalle_galeria.dart
//
// Galería del detalle: carrusel de imágenes (con Hero desde la tarjeta del
// catálogo), botones de atrás, favorito y compartir, badges de promoción y
// puntos de página. La foto visible es estado de la interfaz. Mientras la
// foto aterriza, los botones aparecen con un pop, los badges entran desde la
// izquierda y los puntos con un fundido.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/ui/core/state/product_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/foto_producto.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/products/widgets/detalle_badges.dart';
import 'package:pier_reposteria/ui/products/widgets/movimiento_catalogo.dart';

class DetalleGaleria extends StatefulWidget {
  const DetalleGaleria({
    required this.producto,
    required this.imagenes,
    required this.promociones,
    required this.esFavorito,
    required this.onFavorito,
    required this.onCompartir,
    this.ambitoFoto,
    this.grande = false,
    super.key,
  });

  final Product producto;
  final List<String> imagenes;
  final ProductProvider promociones;
  final bool esFavorito;
  final VoidCallback onFavorito;
  final VoidCallback onCompartir;

  /// Ámbito del Hero de la foto: el mismo de la tarjeta que abrió el detalle
  /// (null = la etiqueta de siempre).
  final String? ambitoFoto;

  /// Si se eligió el tamaño Grande: la foto se acerca un poco.
  final bool grande;

  @override
  State<DetalleGaleria> createState() => _DetalleGaleriaState();
}

class _DetalleGaleriaState extends State<DetalleGaleria> {
  /// Cuánto se acerca la foto con el tamaño Grande.
  static const double _acercamiento = 1.04;

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
          // favoritos (mismo tag producto-img-<id>). El vuelo pinta la foto
          // de la tarjeta (ya en caché), no este carrusel.
          FotoProductoHero(
            productoId: p.id,
            imagenUrl: p.imagenUrl,
            ambito: widget.ambitoFoto,
            marcador: false,
            // Al elegir Grande la foto se acerca un poco (y regresa con
            // Chico); la galería recorta lo que sobra.
            child: AnimatedScale(
              scale: widget.grande ? _acercamiento : 1,
              duration: AppMovimiento.duracion(context, AppMovimiento.media),
              curve: AppMovimiento.curvaEstandar,
              child: PageView.builder(
                itemCount: imagenes.length,
                onPageChanged: (i) => setState(() => _pagina = i),
                itemBuilder: (context, i) => _foto(imagenes, i),
              ),
            ),
          ),
          Positioned(
            key: const ValueKey('botones'),
            top: MediaQuery.of(context).padding.top + 8,
            left: 16, right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _aparecer(
                  0,
                  _BotonRedondo(
                      icon: LucideIcons.arrowLeft,
                      onTap: () => Navigator.pop(context)),
                ),
                _aparecer(
                  1,
                  Row(children: [
                    // Al marcarlo con un toque da un pop con destello (la
                    // carga del favorito no destella) y el ícono cambia con
                    // un rebote.
                    DestelloCorazon(
                      activo: widget.esFavorito,
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
                ),
              ],
            ),
          ),
          // Badges múltiples por tipo (igual que PromoBadge de la web);
          // entran desde la izquierda.
          if (tienePromo || p.popular)
            Positioned(
              key: const ValueKey('insignias'),
              bottom: 20, left: 16,
              child: EntradaSuave(
                orden: 2,
                retraso: AppMovimiento.trasEmpuje,
                desplazamiento: const Offset(-AppMovimiento.distanciaLarga, 0),
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
            ),
          if (imagenes.length > 1)
            Positioned(
              key: const ValueKey('puntos'),
              bottom: 20, left: 0, right: 0,
              child: EntradaSuave(
                orden: 3,
                retraso: AppMovimiento.trasEmpuje,
                desplazamiento: Offset.zero,
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
            ),
        ],
      ),
    );
  }

  /// Los botones sobre la foto aparecen con un pop corto mientras la página
  /// llega (cada uno desde su centro).
  Widget _aparecer(int orden, Widget boton) => EntradaSuave(
        orden: orden,
        retraso: AppMovimiento.trasEmpuje,
        desplazamiento: Offset.zero,
        escalaInicial: 0.85,
        child: boton,
      );

  /// La foto [i] del carrusel; si llega de internet aparece con un fundido.
  Widget _foto(List<String> imagenes, int i) {
    final foto = Image.network(
      imagenes[i],
      fit: BoxFit.cover,
      frameBuilder: (_, imagen, cuadro, sincrona) =>
          AparicionFoto(foto: imagen, cuadro: cuadro, sincrona: sincrona),
      errorBuilder: (context, error, _) => ColoredBox(
        color: AppColors.pierArena,
        child: const Icon(LucideIcons.image,
            size: 60, color: AppColors.textSecondary),
      ),
    );
    // La primera foto del carrusel es la completa, todavía sin bajar (aunque
    // sea la misma dirección que la de la tarjeta, que se pidió reducida):
    // debajo queda la de la tarjeta (fotoDeTarjeta, ya en caché), así al
    // aterrizar el Hero no queda un hueco y la de la galería aparece encima
    // con un fundido.
    final deLaTarjeta = widget.producto.imagenUrl;
    if (i != 0 || deLaTarjeta.isEmpty) return foto;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
            image: fotoDeTarjeta(deLaTarjeta),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink()),
        foto,
      ],
    );
  }
}

/// Botón blanco circular sobre la foto: se hunde al presionarlo y, si cambia
/// de ícono (el corazón), el nuevo llega con un rebote.
class _BotonRedondo extends StatelessWidget {
  const _BotonRedondo({required this.icon, required this.onTap, this.color});

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return PresionEscala(
      escala: AppMovimiento.escalaPresionChica,
      child: GestureDetector(
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
          child: CambioAnimado(
            tipo: TipoCambio.escalar,
            alineacion: Alignment.center,
            child: Icon(icon,
                key: ValueKey<IconData>(icon),
                size: 20,
                color: color ?? AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
