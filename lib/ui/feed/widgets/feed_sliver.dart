// lib/ui/feed/widgets/feed_sliver.dart
//
// «Novedades de Pier» al final del inicio del cliente (#132): las
// publicaciones con las promociones intercaladas y, al acabarse, las
// sugerencias; abajo, cargando más, el error para reintentar o «Ya viste todo
// por hoy». HomeScreen pide más páginas al acercarse al final.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/domain/models/publicacion.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/feed/view_model/feed_view_model.dart';
import 'package:pier_pasteleria/ui/feed/widgets/tarjeta_publicacion.dart';
import 'package:pier_pasteleria/utils/moneda.dart';

/// Agrega [producto] (tamaño chico) al carrito con [precio] de referencia.
typedef AgregarAlCarrito =
    Future<void> Function(Product producto, double precio);

class FeedSliver extends StatelessWidget {
  const FeedSliver({
    required this.viewModel,
    required this.alAgregar,
    super.key,
  });

  final FeedViewModel viewModel;
  final AgregarAlCarrito alAgregar;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final vm = viewModel;
      final elementos = vm.elementos;
      return SliverMainAxisGroup(
        slivers: [
          const SliverToBoxAdapter(child: _Titulo()),
          if (vm.sinPublicaciones)
            const SliverToBoxAdapter(
              child: _Estado(
                icono: LucideIcons.cakeSlice,
                titulo: 'Aún no hay publicaciones',
                detalle:
                    'Muy pronto verás aquí lo nuevo de Pier: '
                    'pasteles recién salidos del horno, novedades y '
                    'promociones.',
              ),
            ),
          SliverList.builder(
            itemCount: elementos.length,
            itemBuilder: (_, i) => switch (elementos[i]) {
              ElementoPublicacion(:final publicacion) => TarjetaPublicacion(
                publicacion,
              ),
              ElementoPromocion(:final promocion) => _TarjetaPromocion(
                promocion,
                alAgregar,
              ),
              ElementoSugerencias(:final productos, :final primero) =>
                _BloqueSugerencias(productos, alAgregar, primero: primero),
            },
          ),
          SliverToBoxAdapter(child: _Pie(vm)),
        ],
      );
    },
  );
}

class _Titulo extends StatelessWidget {
  const _Titulo();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Row(
      children: [
        Icon(LucideIcons.sparkles, size: 20, color: AppColors.pierVerde),
        const SizedBox(width: 8),
        const Text(
          'Novedades de Pier',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}

/// Abajo del feed: primera carga, error, cargando más o fin.
class _Pie extends StatelessWidget {
  const _Pie(this.vm);

  final FeedViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.cargando || vm.cargandoMas) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.pierVerde),
        ),
      );
    }
    if (!vm.iniciado && vm.error != null) {
      return _Estado(
        icono: LucideIcons.circleAlert,
        titulo: 'No pudimos cargar las publicaciones',
        detalle: vm.error,
        accion: () => unawaited(vm.cargar()),
      );
    }
    if (vm.errorMas != null) {
      return _Estado(
        icono: LucideIcons.wifiOff,
        titulo: 'No se pudieron cargar más',
        detalle: vm.errorMas,
        accion: () => unawaited(vm.cargarMas()),
      );
    }
    if (vm.iniciado && vm.fase == FaseFeed.fin) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Center(
          child: Text(
            'Ya viste todo por hoy',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}

class _Estado extends StatelessWidget {
  const _Estado({
    required this.icono,
    required this.titulo,
    this.detalle,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String? detalle;
  final VoidCallback? accion;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
    child: Column(
      children: [
        Icon(icono, size: 36, color: AppColors.textSecondary),
        const SizedBox(height: 8),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (detalle != null)
          Text(
            detalle!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        if (accion != null)
          TextButton(onPressed: accion, child: const Text('Reintentar')),
      ],
    ),
  );
}

/// Promoción intercalada: foto, título, precio con descuento y «Agregar».
class _TarjetaPromocion extends StatelessWidget {
  const _TarjetaPromocion(this.promocion, this.alAgregar);

  final PromocionFeed promocion;
  final AgregarAlCarrito alAgregar;

  @override
  Widget build(BuildContext context) {
    final p = promocion;
    final conDescuento = p.precioPromocion < p.precioNormal;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.pierDorado.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 140,
            child: ImagenFeed(p.imagenUrl),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.etiqueta ?? 'Promoción',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.pierDoradoOscuro,
                    ),
                  ),
                  Text(
                    p.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (p.subtitulo case final subtitulo?)
                    Text(
                      subtitulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        moneda(p.precioPromocion),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.pierVerde,
                        ),
                      ),
                      if (conDescuento)
                        Text(
                          moneda(p.precioNormal),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      if (p.descuentoPorcentaje case final d? when conDescuento)
                        Text(
                          '-$d %',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  BotonAgregar(
                    alTocar: () => alAgregar(p.comoProducto, p.precioPromocion),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «Te podría gustar»: rejilla de productos sugeridos con su motivo.
class _BloqueSugerencias extends StatelessWidget {
  const _BloqueSugerencias(
    this.productos,
    this.alAgregar, {
    required this.primero,
  });

  final List<ProductoSugerido> productos;
  final bool primero;
  final AgregarAlCarrito alAgregar;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (primero)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Te podría gustar',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.62,
          children: [
            for (final s in productos) _TarjetaSugerido(s, alAgregar),
          ],
        ),
      ],
    ),
  );
}

class _TarjetaSugerido extends StatelessWidget {
  const _TarjetaSugerido(this.producto, this.alAgregar);

  final ProductoSugerido producto;
  final AgregarAlCarrito alAgregar;

  @override
  Widget build(BuildContext context) {
    final s = producto;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: SizedBox.expand(child: ImagenFeed(s.imagenUrl))),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  s.motivo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  moneda(s.precioChico),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.pierVerde,
                  ),
                ),
                const SizedBox(height: 4),
                BotonAgregar(
                  alTocar: () => alAgregar(s.comoProducto, s.precioChico),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// «Agregar» que se deshabilita mientras se agrega (sin dobles toques).
class BotonAgregar extends StatefulWidget {
  const BotonAgregar({required this.alTocar, super.key});

  final Future<void> Function() alTocar;

  @override
  State<BotonAgregar> createState() => _BotonAgregarState();
}

class _BotonAgregarState extends State<BotonAgregar> {
  bool _agregando = false;

  Future<void> _agregar() async {
    setState(() => _agregando = true);
    await widget.alTocar();
    if (mounted) setState(() => _agregando = false);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: _agregando ? null : () => unawaited(_agregar()),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.pierVerde,
        minimumSize: const Size(0, 36),
        padding: EdgeInsets.zero,
      ),
      child: const Text('Agregar'),
    ),
  );
}
