// lib/ui/products/widgets/product_detail_screen.dart
//
// Detalle de producto (MVVM, Fase 4): la vista pinta lo que expone
// ProductDetailViewModel (galería, reseñas, favorito, recomendaciones,
// tamaño y cantidad). Aquí solo queda lo que es de la interfaz: navegar,
// mandar a iniciar sesión, los avisos (SnackBar), el rebote de los botones de
// carrito y compartir con el menú del sistema.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/auth/widgets/login_screen.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/product_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/products/view_model/product_detail_view_model.dart';
import 'package:pier_pasteleria/ui/products/widgets/detalle_badges.dart';
import 'package:pier_pasteleria/ui/products/widgets/detalle_compra.dart';
import 'package:pier_pasteleria/ui/products/widgets/detalle_galeria.dart';
import 'package:pier_pasteleria/ui/products/widgets/detalle_recomendaciones.dart';
import 'package:pier_pasteleria/ui/products/widgets/detalle_resenas.dart';
import 'package:pier_pasteleria/ui/reviews/widgets/create_review_screen.dart';
import 'package:pier_pasteleria/ui/reviews/widgets/product_reviews_screen.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({required this.product, super.key, this.viewModel});

  final Product product;

  /// Para pruebas; si es null la pantalla crea el suyo.
  final ProductDetailViewModel? viewModel;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with TickerProviderStateMixin {
  // El State es dueño del ViewModel (lo crea, lo carga y lo libera).
  late final ProductDetailViewModel _vm = widget.viewModel ??
      ProductDetailViewModel(
        producto: widget.product,
        productosRepo: context.read(),
        favoritosRepo: context.read(),
        resenasRepo: context.read(),
        demandaRepo: context.read(),
      );
  late final AnimationController _cartAnimController;
  late final Animation<double> _cartAnim;
  bool _compartiendo = false;

  // Rebote del botón de carrito en las tarjetas de recomendados
  final Map<String, AnimationController> _relatedCartControllers = {};
  final Map<String, Animation<double>> _relatedCartAnims = {};

  Product get _producto => widget.product;
  bool get _autenticado => context.read<AuthProvider>().isAuthenticated;

  @override
  void initState() {
    super.initState();
    PierLog.nav('→ ProductDetailScreen: ${_producto.nombre}');
    _cartAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _cartAnim = Tween<double>(begin: 1, end: 1.08).animate(
        CurvedAnimation(parent: _cartAnimController, curve: Curves.elasticOut));
    unawaited(_vm.cargar(autenticado: _autenticado));
    // Catálogo/promos: no-op si ya están cargados; las tarjetas de
    // recomendados los usan para precio con descuento y datos completos.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<ProductProvider>().cargarProductos());
    });
  }

  @override
  void dispose() {
    _cartAnimController.dispose();
    for (final c in _relatedCartControllers.values) {
      c.dispose();
    }
    _vm.dispose();
    super.dispose();
  }

  void _irALogin() => Navigator.push(
      context, MaterialPageRoute<void>(builder: (_) => const LoginScreen()));

  void _aviso(String texto,
      {required IconData icono, required Color color, int? segundos}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(icono, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(texto)),
        ]),
        backgroundColor: color,
        duration: Duration(seconds: segundos ?? 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  void _error(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensaje),
      backgroundColor: AppColors.error,
    ));
  }

  Future<void> _toggleFavorito() async {
    if (!_autenticado) {
      _irALogin();
      return;
    }
    final error = await _vm.alternarFavorito();
    if (error != null && mounted) _error(error);
  }

  Future<void> _toggleUtil(String resenaId) async {
    if (!_autenticado) {
      _irALogin();
      return;
    }
    final error = await _vm.alternarUtil(resenaId);
    if (error != null && mounted) _error(error);
  }

  /// "Avísame" para producto agotado: registra el interés (demanda no
  /// atendida) y lo confirma. No requiere sesión, igual que en la web.
  void _avisarme() {
    _vm.avisarme();
    _aviso(
        'Anotamos tu interés en "${_producto.nombre}". Te avisaremos cuando vuelva.',
        icono: LucideIcons.bellRing,
        color: AppColors.pierDoradoOscuro,
        segundos: 3);
  }

  void _addToCart() {
    if (!_autenticado) {
      _irALogin();
      return;
    }
    if (_producto.agotado) return; // el botón ya es "Avísame"; doble guard
    final tamano = _vm.tamanoParaCarrito;
    PierLog.info('🛒 Agregando: ${_producto.nombre} ($tamano) x${_vm.cantidad}');
    context
        .read<CartProvider>()
        .addItem(_producto, _vm.cantidad, tamano, _vm.precioBase);
    _cartAnimController.forward(from: 0);
    final sufijoTam = tamano == 'grande' ? ' (Grande)' : '';
    _aviso('${_vm.cantidad} × ${_producto.nombre}$sufijoTam agregado',
        icono: Icons.check_circle_rounded, color: AppColors.pierVerde);
    Navigator.pop(context);
  }

  void _addRelatedToCart(Product p) {
    if (!_autenticado) {
      _irALogin();
      return;
    }
    PierLog.info('🛒 Agregando relacionado: ${p.nombre}');
    context.read<CartProvider>().addItem(p);
    _relatedCartControllers.putIfAbsent(p.id, () {
      final c = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 500));
      _relatedCartAnims[p.id] = Tween<double>(begin: 1, end: 1.3).animate(
          CurvedAnimation(parent: c, curve: Curves.elasticOut));
      return c;
    }).forward(from: 0);
    _aviso('${p.nombre} agregado',
        icono: Icons.check_circle_rounded,
        color: AppColors.pierVerde,
        segundos: 2);
  }

  Future<void> _compartir() async {
    if (_compartiendo) return;
    setState(() => _compartiendo = true);
    PierLog.info('Compartiendo: ${_producto.nombre}');
    final texto =
        '¡Mira este delicioso producto!\n\n${_producto.nombre} por solo \$${_producto.precio.toStringAsFixed(2)}\n\nEncuéntralo en ${BusinessInfo.marca}.';
    try {
      if (_producto.imagenUrl.isNotEmpty) {
        final response = await http
            .get(Uri.parse(_producto.imagenUrl))
            .timeout(const Duration(seconds: 5));
        final file = File('${Directory.systemTemp.path}/producto_compartido.jpg');
        await file.writeAsBytes(response.bodyBytes);
        await SharePlus.instance
            .share(ShareParams(files: [XFile(file.path)], text: texto));
      } else {
        await SharePlus.instance.share(ShareParams(text: texto));
      }
    } on Exception catch (e) {
      PierLog.error('Fallo compartir imagen: $e');
      await SharePlus.instance.share(ShareParams(text: texto));
    } finally {
      if (mounted) setState(() => _compartiendo = false);
    }
  }

  /// Abre otra pantalla y al volver recarga reseñas (pudo escribir una).
  Future<void> _abrirYRecargar(Widget pantalla) async {
    await Navigator.push(
        context, MaterialPageRoute<void>(builder: (_) => pantalla));
    if (mounted) await _vm.cargarDetalle();
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    // Reacciona a cambios de promociones y productos
    final promociones = context.watch<ProductProvider>();

    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.pierArena,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: DetalleGaleria(
                producto: _producto,
                imagenes: _vm.imagenes,
                promociones: promociones,
                esFavorito: _vm.esFavorito,
                onFavorito: _toggleFavorito,
                onCompartir: _compartir,
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.pierArena,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _encabezado(),
                      const SizedBox(height: 12),
                      Text(
                        _producto.nombre,
                        style: const TextStyle(
                            fontFamily: 'Playfair Display',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            height: 1.2),
                      ),
                      const SizedBox(height: 6),
                      ..._precioYPromo(promociones),
                      Text(
                        _producto.descripcion,
                        style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.5),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_vm.tieneTamanos) ...[
                        const SizedBox(height: 28),
                        const Text('Selecciona el tamaño',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 14),
                        DetalleSelectorTamano(
                            viewModel: _vm, promociones: promociones),
                      ],
                      const SizedBox(height: 24),
                      DetalleBarraCompra(
                        viewModel: _vm,
                        promociones: promociones,
                        animacion: _cartAnim,
                        onAgregar: _addToCart,
                        onAvisarme: _avisarme,
                      ),
                      ..._ingredientes(),
                      const SizedBox(height: 32),
                      DetalleResenas(
                        viewModel: _vm,
                        onEscribir: () => _abrirYRecargar(
                            CreateReviewScreen(product: _producto)),
                        onVerTodas: () => _abrirYRecargar(
                            ProductReviewsScreen(product: _producto)),
                        onUtil: _toggleUtil,
                      ),
                      DetalleRecomendaciones(
                        recomendaciones: _vm.recomendaciones,
                        catalogo: promociones,
                        animaciones: _relatedCartAnims,
                        // push (no pushReplacement): atrás regresa al
                        // producto de origen.
                        onAbrir: (p) => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => ProductDetailScreen(product: p))),
                        onAgregar: _addRelatedToCart,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Categoría, tipo, sabor y calificación.
  Widget _encabezado() {
    final rating = _vm.rating;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _Etiqueta(
          texto: _producto.categoria.toUpperCase(),
          fondo: AppColors.pierVerde.withValues(alpha: 0.1),
          color: AppColors.pierVerde,
          grosor: FontWeight.w800,
        ),
        // Chips de tipo y sabor (igual que la web)
        for (final extra in [_producto.tipo, _producto.sabor])
          if (extra != null && extra.isNotEmpty)
            _Etiqueta(
              texto: extra,
              fondo: AppColors.pierDorado.withValues(alpha: 0.12),
              color: AppColors.pierDoradoOscuro,
              grosor: FontWeight.w700,
            ),
        Row(children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
          const SizedBox(width: 4),
          Text(
            rating > 0 ? rating.toStringAsFixed(1) : '—',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(width: 4),
          Text('(${_vm.totalResenas})',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ]),
      ],
    );
  }

  /// Precio con descuento (tachado el original) y badges del tipo de promo.
  List<Widget> _precioYPromo(ProductProvider promociones) {
    final id = _producto.id;
    if (!promociones.tieneDescuento(id)) return const [];
    final precioFinal = promociones.precioConDescuento(id, _producto.precio);
    return [
      Row(children: [
        Text('\$${precioFinal.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.red.shade600)),
        const SizedBox(width: 10),
        Text('\$${_producto.precio.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
                decoration: TextDecoration.lineThrough)),
      ]),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: badgeDeTipoPromo(
            promociones.promocionDeProducto(id), largo: true),
      ),
      const SizedBox(height: 8),
    ];
  }

  List<Widget> _ingredientes() {
    if (_producto.ingredientes.isEmpty) return const [];
    return [
      const SizedBox(height: 28),
      const Text('Ingredientes principales',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary)),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _producto.ingredientes
            .map((ing) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.pierVerde.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.pierVerde.withValues(alpha: 0.2)),
                  ),
                  child: Text(ing,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.pierVerde,
                          fontWeight: FontWeight.w600)),
                ))
            .toList(),
      ),
    ];
  }
}

/// Chip pequeño del encabezado (categoría, tipo, sabor).
class _Etiqueta extends StatelessWidget {
  const _Etiqueta({
    required this.texto,
    required this.fondo,
    required this.color,
    required this.grosor,
  });

  final String texto;
  final Color fondo;
  final Color color;
  final FontWeight grosor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(texto,
          style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: grosor,
              letterSpacing: grosor == FontWeight.w800 ? 0.5 : null)),
    );
  }
}
