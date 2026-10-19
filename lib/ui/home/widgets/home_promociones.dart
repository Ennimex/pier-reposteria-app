// lib/ui/home/widgets/home_promociones.dart
//
// Secciones de promociones del inicio (mismo concepto que la web): banner,
// ofertas relámpago, de temporada y destacadas. Pintan lo que el
// HomeViewModel separó por tipo; tocar una oferta abre su producto.
//
// Movimiento: las tarjetas entran al compás de su sección (las de temporada
// desde la derecha), se hunden al tocarlas y sus fotos aparecen con un
// fundido; las de temporada y destacadas vuelan al detalle que abren, como
// las de los carruseles de productos. En el banner la flama parpadea, una
// luz cruza el código de descuento y la flecha del botón empuja dos veces;
// cada título hace su gesto (el rayo se sacude, los brillos destellan). Todo
// una sola vez.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/promociones_inicio.dart';
import 'package:pier_reposteria/ui/core/state/navigation_provider.dart';
import 'package:pier_reposteria/ui/core/state/product_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/home/view_model/home_view_model.dart';
import 'package:pier_reposteria/ui/home/widgets/movimiento_inicio.dart';
import 'package:pier_reposteria/ui/products/widgets/product_detail_screen.dart';
import 'package:pier_reposteria/utils/logger.dart';
import 'package:provider/provider.dart';

/// Abre el detalle del producto de [promo] si ya está en el catálogo
/// cargado; si no, lleva al catálogo. Con [ambitoFoto] (el de la foto de la
/// tarjeta tocada) la foto vuela al detalle.
void _abrirProductoDePromo(
    BuildContext context, Map<String, dynamic> promo, String origen,
    {String? ambitoFoto}) {
  final productoId = promo['producto_id']?.toString();
  final producto = context
      .read<ProductProvider>()
      .productos
      .where((p) => productoId != null && p.id == productoId)
      .firstOrNull;
  if (producto == null || producto.id.isEmpty) {
    context.read<NavigationProvider>().goCatalogo();
    return;
  }
  PierLog.nav('→ ProductDetailScreen desde $origen');
  Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => ProductDetailScreen(
              product: producto, ambitoFoto: ambitoFoto))).ignore();
}

/// Lo que devuelve el `frameBuilder` de las fotos de las ofertas.
Widget _fundido(BuildContext _, Widget foto, int? cuadro, bool sincrona) =>
    FotoConFundido(foto: foto, cuadro: cuadro, sincrona: sincrona);

/// La foto de una oferta que abre su producto: vuela al detalle como las de
/// los carruseles de productos. Cada tarjeta lleva su propio ámbito (sección
/// e índice): un producto puede repetirse entre ofertas y en los carruseles.
/// Mientras vuela, la tarjeta deja ver su propio fondo (el tinte o la arena
/// de mientras la foto llega).
Widget _fotoQueVuela({
  required Map<String, dynamic> promo,
  required String ambito,
  required String imagenUrl,
  required BorderRadius radio,
  required Widget foto,
}) {
  final productoId = promo['producto_id']?.toString();
  if (productoId == null) return foto;
  return FotoProductoHero(
    productoId: productoId,
    imagenUrl: imagenUrl,
    ambito: ambito,
    radio: radio,
    marcador: false,
    child: foto,
  );
}

/// Banner de la promoción tipo 'banner'.
class HomePromoBanner extends StatelessWidget {
  const HomePromoBanner({
    required this.promociones,
    super.key,
  });

  final PromocionesInicio promociones;

  @override
  Widget build(BuildContext context) {
    final p = promociones.banner!;
    final titulo = p['titulo_banner']?.toString() ?? 'Promoción especial';
    final subtitulo = p['subtitulo_banner']?.toString() ?? '';
    final descripcion = p['descripcion_banner']?.toString() ?? '';
    final codigo = p['codigo_descuento']?.toString();
    final fechaFin = p['fecha_fin']?.toString();
    final tiempo = tiempoRestante(fechaFin);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.pierVerdeOscuro, AppColors.pierVerde],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
              color: AppColors.pierVerdeOscuro.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header badge
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                // La flama parpadea dos veces al llegar el banner.
                child: const GestoIcono(
                  tipo: TipoGesto.flama,
                  child: Icon(LucideIcons.flame,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Oferta activa',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
              if (tiempo.isNotEmpty) ...[
                const Spacer(),
                Row(children: [
                  const Icon(LucideIcons.timer,
                      color: Colors.white70, size: 13),
                  const SizedBox(width: 4),
                  Text(tiempo,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500)),
                ]),
              ],
            ]),
            const SizedBox(height: 14),

            // Título
            Text(titulo,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.2)),
            if (subtitulo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitulo,
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.pierDorado,
                      fontWeight: FontWeight.w600)),
            ],
            if (descripcion.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(descripcion,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],

            const SizedBox(height: 16),

            // Código de descuento: una luz lo cruza una vez.
            if (codigo != null && codigo.isNotEmpty) ...[
              BarridoDeLuz(
                radio: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.pierDorado.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.pierDorado.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.gift,
                          color: AppColors.pierDorado, size: 16),
                      const SizedBox(width: 8),
                      Text(codigo,
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Botón CTA: su flecha empuja dos veces, invitando a tocar.
            SizedBox(
              width: double.infinity,
              child: PresionEscala(
                child: GestureDetector(
                  onTap: () => context.read<NavigationProvider>().goCatalogo(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Ver productos',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.pierVerdeOscuro)),
                        const SizedBox(width: 6),
                        // Empuja cuando la flama terminó de parpadear.
                        GestoIcono(
                          tipo: TipoGesto.empujon,
                          retraso: AppMovimiento.rapida +
                              GestoIcono.duracionDe(TipoGesto.flama),
                          child: Icon(LucideIcons.arrowRight,
                              color: AppColors.pierVerdeOscuro, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carrusel de ofertas relámpago con su cuenta regresiva.
class HomeOfertasRelampago extends StatelessWidget {
  const HomeOfertasRelampago({
    required this.promociones,
    super.key,
  });

  final PromocionesInicio promociones;

  @override
  Widget build(BuildContext context) {
    final fuente = promociones.relampago.take(2).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: GestoIcono(
                tipo: TipoGesto.chispazo,
                child: Icon(LucideIcons.zap,
                    color: Colors.amber.shade700, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Ofertas Relámpago',
                style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 12),
          Row(
            children: List.generate(fuente.length, (idx) {
              final promo = fuente[idx];
              final imagenUrl = promo['producto_imagen']?.toString() ?? '';
              final porcentaje = promo['descuento_porcentaje']?.toString() ?? '';
              final tag = promo['badge_destacado']?.toString() ??
                  (porcentaje.isNotEmpty ? '$porcentaje% OFF' : 'OFERTA');
              final titulo = promo['titulo_banner']?.toString() ??
                  promo['producto_nombre']?.toString() ??
                  'Oferta especial';
              // El backend solo cobra el % (precio_oferta no se cobra); el
              // "Desde" se calcula sobre el precio real con el % de descuento.
              final precioBaseBanner =
                  double.tryParse(promo['precio_chico']?.toString() ?? '0') ?? 0;
              final porcentajeBanner = double.tryParse(
                      promo['descuento_porcentaje']?.toString() ?? '0') ??
                  0;
              final precioDesde = porcentajeBanner > 0
                  ? (precioBaseBanner * (1 - porcentajeBanner / 100))
                      .roundToDouble()
                  : precioBaseBanner;
              final subtitulo = promo['subtitulo_banner']?.toString() ??
                  (precioDesde > 0
                      ? 'Desde \$${precioDesde.toStringAsFixed(0)} MXN'
                      : '');
              final tiempo = tiempoRestante(promo['fecha_fin']?.toString());
              final gradientColor =
                  idx == 0 ? AppColors.pierVerdeOscuro : AppColors.pierDoradoOscuro;

              return Expanded(
                // Las dos tarjetas llegan una tras otra.
                child: EntradaInicio(
                  orden: idx + 1,
                  child: PresionEscala(
                    child: GestureDetector(
                      // Sin vuelo de foto: aquí la foto es el fondo, bajo un
                      // degradado del color de la tarjeta; si volara saldría
                      // sin ese tinte, como si fuera otra foto.
                      onTap: () => _abrirProductoDePromo(context, promo, 'relámpago'),
                      child: Container(
                        margin: EdgeInsets.only(
                            left: idx == 0 ? 0 : 8, right: idx == 0 ? 8 : 0),
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(
                              color: gradientColor.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(fit: StackFit.expand, children: [
                            // El color de la tarjeta mientras la foto llega
                            // (y si no hay foto o falla).
                            ColoredBox(color: gradientColor),
                            if (imagenUrl.isNotEmpty)
                              Image.network(imagenUrl,
                                  fit: BoxFit.cover,
                                  frameBuilder: _fundido,
                                  errorBuilder: (_, _, _) =>
                                      ColoredBox(color: gradientColor)),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    gradientColor.withValues(alpha: 0.5),
                                    gradientColor.withValues(alpha: 0.88),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(tag,
                                          style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white)),
                                    ),
                                    if (tiempo.isNotEmpty) ...[
                                      const Spacer(),
                                      Row(children: [
                                        const Icon(LucideIcons.timer,
                                            color: Colors.white70, size: 11),
                                        const SizedBox(width: 2),
                                        Text(tiempo,
                                            style: const TextStyle(
                                                fontSize: 9,
                                                color: Colors.white70)),
                                      ]),
                                    ],
                                  ]),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(titulo,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      if (subtitulo.isNotEmpty)
                                        Text(subtitulo,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.white
                                                    .withValues(alpha: 0.85))),
                                      const SizedBox(height: 2),
                                      Row(children: [
                                        const Text('Ver detalle',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 2),
                                        Icon(LucideIcons.chevronRight,
                                            size: 9,
                                            color:
                                                Colors.white.withValues(alpha: 0.9)),
                                      ]),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Ofertas de temporada.
class HomeOfertasTemporada extends StatelessWidget {
  const HomeOfertasTemporada({
    required this.promociones,
    super.key,
  });

  final PromocionesInicio promociones;

  @override
  Widget build(BuildContext context) {
    final accentColors = [
      AppColors.pierVerde, AppColors.pierDorado,
      AppColors.estadoCancelado, AppColors.pierDoradoOscuro,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 28, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAE3D0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(children: [
                  GestoIcono(
                    tipo: TipoGesto.destello,
                    child: Icon(LucideIcons.sparkles,
                        size: 13, color: AppColors.estadoCancelado),
                  ),
                  SizedBox(width: 4),
                  Text('Temporada',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.estadoCancelado)),
                ]),
              ),
              const SizedBox(width: 10),
              const Text('De Temporada',
                  style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
            ]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 230,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: promociones.temporada.length,
              itemBuilder: (context, idx) {
                final promo = promociones.temporada[idx];
                final accent = accentColors[idx % accentColors.length];
                final imagenUrl = promo['producto_imagen']?.toString() ?? '';
                final titulo = promo['nombre_temporada']?.toString() ??
                    promo['titulo_banner']?.toString() ??
                    promo['producto_nombre']?.toString() ?? 'Temporada';
                final subtitulo = promo['subtitulo_banner']?.toString() ?? '';
                final precioBruto =
                    double.tryParse(promo['precio_chico']?.toString() ?? '0') ?? 0;
                final porcentaje = double.tryParse(
                        promo['descuento_porcentaje']?.toString() ?? '0') ??
                    0;
                // El backend solo cobra el % (precio_oferta no se cobra).
                final precioFinal = porcentaje > 0
                    ? (precioBruto * (1 - porcentaje / 100)).roundToDouble()
                    : precioBruto;
                final precioStr =
                    precioFinal > 0 ? '\$${precioFinal.toStringAsFixed(0)}' : '';
                final tiempo =
                    tiempoRestante(promo['fecha_fin']?.toString());
                // La foto vuela al detalle que abre la tarjeta.
                final ambitoFoto = 'inicio-temporada-$idx';
                // Las primeras llegan desde la derecha, una tras otra; las
                // que aparecen al desplazar ya están en su lugar.
                return EntradaInicio(
                  orden: idx + 1,
                  desplazamiento: const Offset(AppMovimiento.distanciaLarga, 0),
                  child: PresionEscala(
                    child: _buildTemporadaCard(
                      idx: idx,
                      promo: promo,
                      ambitoFoto: ambitoFoto,
                      imagenUrl: imagenUrl,
                      titulo: titulo,
                      subtitulo: subtitulo.isNotEmpty
                          ? subtitulo
                          : (tiempo.isNotEmpty ? 'Hasta $tiempo' : ''),
                      precio: precioStr,
                      precioOriginal:
                          porcentaje > 0 ? '\$${precioBruto.toStringAsFixed(0)}' : null,
                      accent: accent,
                      onTap: () => _abrirProductoDePromo(
                          context, promo, 'temporada',
                          ambitoFoto: ambitoFoto),
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

  Widget _buildTemporadaCard({
    required int idx,
    required Map<String, dynamic> promo,
    required String ambitoFoto,
    required String imagenUrl,
    required String titulo,
    required String subtitulo,
    required String precio,
    required Color accent,
    required VoidCallback onTap,
    String? precioOriginal,
  }) {
    final fondoFoto = accent.withValues(alpha: 0.12);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 155,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          )],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 115,
                width: double.infinity,
                child: Stack(fit: StackFit.expand, children: [
                  if (imagenUrl.isNotEmpty) ...[
                    // El tinte mientras la foto llega.
                    ColoredBox(color: fondoFoto),
                    _fotoQueVuela(
                      promo: promo,
                      ambito: ambitoFoto,
                      imagenUrl: imagenUrl,
                      radio: const BorderRadius.vertical(
                          top: Radius.circular(18)),
                      foto: Image.network(imagenUrl, fit: BoxFit.cover,
                          frameBuilder: _fundido,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: fondoFoto,
                            child: Icon(LucideIcons.cake,
                                color: accent, size: 40),
                          )),
                    ),
                  ] else
                    ColoredBox(
                      color: fondoFoto,
                      child: Icon(LucideIcons.cake,
                          color: accent, size: 40),
                    ),
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.sparkles,
                              size: 8, color: Colors.white),
                          SizedBox(width: 3),
                          Text('Temporada',
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titulo,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  height: 1.2),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          if (subtitulo.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(subtitulo,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (precio.isNotEmpty)
                                Text(precio,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: accent)),
                              // ✅ Precio tachado si hay descuento
                              if (precioOriginal != null)
                                Text(precioOriginal,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                                        decoration:
                                            TextDecoration.lineThrough)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Ver',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: accent)),
                                const SizedBox(width: 2),
                                Icon(LucideIcons.chevronRight,
                                    size: 8, color: accent),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Promociones destacadas.
class HomePromoDestacado extends StatelessWidget {
  const HomePromoDestacado({
    required this.promociones,
    super.key,
  });

  final PromocionesInicio promociones;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppColors.pierDorado, AppColors.pierDoradoOscuro]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const GestoIcono(
                tipo: TipoGesto.destello,
                child: Icon(LucideIcons.sparkles,
                    color: Colors.white, size: 16),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Productos Destacados',
                style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 4),
          const Text('Seleccionados especialmente para ti',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          ...promociones.destacado.indexed.map((entrada) {
            final (indice, promo) = entrada;
            final imagenUrl = promo['producto_imagen']?.toString() ?? '';
            final nombre =
                promo['producto_nombre']?.toString() ?? 'Producto';
            final badge = promo['badge_destacado']?.toString() ?? 'Destacado';
            final precioOriginal =
                double.tryParse(promo['precio_original']?.toString() ??
                        promo['precio_chico']?.toString() ?? '0') ??
                    0;
            final porcentaje =
                double.tryParse(promo['descuento_porcentaje']?.toString() ?? '0') ??
                    0;
            // El backend solo cobra el % (precio_oferta no se cobra).
            final precioFinalDest = porcentaje > 0
                ? (precioOriginal * (1 - porcentaje / 100)).roundToDouble()
                : precioOriginal;
            final fechaFin = promo['fecha_fin']?.toString();
            final tiempo = tiempoRestante(fechaFin);
            // La foto vuela al detalle que abre la fila.
            final ambitoFoto = 'inicio-destacado-$indice';

            final fila = GestureDetector(
              onTap: () => _abrirProductoDePromo(context, promo, 'destacado',
                  ambitoFoto: ambitoFoto),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                      color: AppColors.pierDorado.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: [
                      // Imagen
                      SizedBox(
                        width: 110,
                        child: Stack(fit: StackFit.expand, children: [
                          if (imagenUrl.isNotEmpty) ...[
                            // La arena mientras la foto llega.
                            ColoredBox(color: AppColors.pierArena),
                            _fotoQueVuela(
                              promo: promo,
                              ambito: ambitoFoto,
                              imagenUrl: imagenUrl,
                              radio: const BorderRadius.horizontal(
                                  left: Radius.circular(16)),
                              foto: Image.network(imagenUrl,
                                  fit: BoxFit.cover,
                                  frameBuilder: _fundido,
                                  errorBuilder: (_, _, _) => ColoredBox(
                                    color: AppColors.pierArena,
                                    child: Icon(LucideIcons.cake,
                                        color: AppColors.pierDorado, size: 36),
                                  )),
                            ),
                          ] else
                            ColoredBox(
                              color: AppColors.pierArena,
                              child: Icon(LucideIcons.cake,
                                  color: AppColors.pierDorado, size: 36),
                            ),
                          // Badge dorado
                          Positioned(
                            top: 8, left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: [
                                      AppColors.pierDorado,
                                      AppColors.pierDoradoOscuro
                                    ]),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.sparkles,
                                      size: 8, color: Colors.white),
                                  const SizedBox(width: 3),
                                  Text(badge,
                                      style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                          // Badge descuento
                          if (porcentaje > 0)
                            Positioned(
                              bottom: 8, right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade500,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                    '-${porcentaje.round()}%',
                                    style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                              ),
                            ),
                        ]),
                      ),
                      // Info
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(nombre,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.textPrimary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Precio final (solo % que el backend cobra)
                                      Text(
                                        '\$${precioFinalDest.toStringAsFixed(0)}',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.pierDorado),
                                      ),
                                      // Precio tachado
                                      if (porcentaje > 0 &&
                                          precioOriginal > 0)
                                        Text(
                                          '\$${precioOriginal.toStringAsFixed(0)}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary.withValues(alpha: 0.5),
                                              decoration:
                                                  TextDecoration.lineThrough),
                                        ),
                                    ],
                                  ),
                                  // Tiempo restante
                                  if (tiempo.isNotEmpty)
                                    Row(children: [
                                      Icon(LucideIcons.timer,
                                          size: 12,
                                          color: AppColors.pierDorado),
                                      const SizedBox(width: 3),
                                      Text(tiempo,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.pierDorado,
                                              fontWeight: FontWeight.w600)),
                                    ]),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            // Las filas suben una tras otra.
            return EntradaInicio(
              orden: indice + 1,
              child: PresionEscala(child: fila),
            );
          }),
        ],
      ),
    );
  }
}
