// lib/ui/products/widgets/product_detail_screen.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/product_provider.dart';
import 'package:pier_pasteleria/data/repositories/favoritos_repository.dart';
import 'package:pier_pasteleria/data/repositories/productos_repository.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:pier_pasteleria/data/services/demanda_service.dart';
import 'package:pier_pasteleria/ui/auth/widgets/login_screen.dart';
import 'package:pier_pasteleria/ui/reviews/widgets/create_review_screen.dart';
import 'package:pier_pasteleria/ui/reviews/widgets/product_reviews_screen.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with TickerProviderStateMixin {
  final _favoritosRepo = FavoritosRepository();
  final _productosRepo = ProductosRepository();

  int _quantity = 1;
  bool _isFavorite = false;
  int _currentImageIndex = 0;
  int _selectedSize = 0;
  late List<String> _images;
  late AnimationController _cartAnimController;
  late Animation<double> _cartAnim;

  List<Map<String, dynamic>> _resenas = [];
  bool _loadingResenas = true;
  Map<String, dynamic>? _detalleProducto;
  bool _isSharing = false;

  // Recomendaciones del backend (co-compra); si no llegan, la sección no se pinta
  List<Product> _recomendaciones = [];

  // Animaciones para el botón de carrito en las cards de relacionados
  final Map<String, AnimationController> _relatedCartControllers = {};
  final Map<String, Animation<double>> _relatedCartAnims = {};

  // Solo etiquetas: el backend no tiene campo de porciones/personas,
  // asi que no se inventa ese dato aqui.
  final List<String> _sizes = ['Chico', 'Grande'];

  double get _precioBase =>
      _selectedSize == 0
          ? widget.product.precio
          : (widget.product.precioGrande ?? widget.product.precio * 1.4);

  @override
  void initState() {
    super.initState();
    PierLog.nav('→ ProductDetailScreen: ${widget.product.nombre}');
    _images = widget.product.imagenes.isNotEmpty
        ? widget.product.imagenes
        : [widget.product.imagenUrl];

    _cartAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _cartAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _cartAnimController, curve: Curves.elasticOut));

    _cargarDetalle();
    _cargarEstadoFavorito();
    _cargarRecomendaciones();
    // Catálogo/promos: no-op si ya están cargados; las cards de recomendados/
    // relacionados los usan para precio con descuento y datos completos.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<ProductProvider>(context, listen: false).cargarProductos();
      }
    });
  }

  @override
  void dispose() {
    _cartAnimController.dispose();
    for (final c in _relatedCartControllers.values) { c.dispose(); }
    super.dispose();
  }

  AnimationController _getRelatedCartController(String id) {
    if (!_relatedCartControllers.containsKey(id)) {
      final c = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 500));
      _relatedCartControllers[id] = c;
      _relatedCartAnims[id] = Tween<double>(begin: 1.0, end: 1.3).animate(
          CurvedAnimation(parent: c, curve: Curves.elasticOut));
    }
    return _relatedCartControllers[id]!;
  }

  Future<void> _cargarEstadoFavorito() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;
    final result = await _favoritosRepo.ids();
    if (!mounted) return;
    if (result['success'] == true) {
      final ids = List<String>.from(
          (result['ids'] ?? []).map((e) => e.toString()));
      setState(() => _isFavorite = ids.contains(widget.product.id));
    } else {
      PierLog.error('Error al cargar favorito: ${result['message']}');
    }
  }

  Future<void> _toggleFavorito() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    final yaEsFav = _isFavorite;
    setState(() => _isFavorite = !_isFavorite);
    final result = yaEsFav
        ? await _favoritosRepo.quitar(widget.product.id)
        : await _favoritosRepo.agregar(widget.product.id);
    if (!mounted) return;
    if (result['success'] != true) {
      PierLog.error('Error al actualizar favorito: ${result['message']}');
      setState(() => _isFavorite = yaEsFav);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Error al actualizar favorito'),
        backgroundColor: AppColors.error,
      ));
    } else {
      PierLog.info('Favorito ${yaEsFav ? 'removido' : 'agregado'}');
    }
  }

  Future<void> _cargarDetalle() async {
    PierLog.info('Cargando detalle: ${widget.product.id}');
    final provider = Provider.of<ProductProvider>(context, listen: false);
    final result = await provider.cargarDetalle(widget.product.id);
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _detalleProducto = result['producto'];
        _resenas = List<Map<String, dynamic>>.from(result['resenas'] ?? []);
        PierLog.info('✅ ${_resenas.length} reseñas cargadas');
        final imagenes = result['producto']?['imagenes'];
        if (imagenes is List && imagenes.isNotEmpty) {
          final urls = imagenes
              .map((e) => e is Map ? (e['url'] ?? '').toString() : e.toString())
              .where((s) => s.isNotEmpty)
              .toList();
          if (urls.isNotEmpty) _images = urls;
        } else if (imagenes is String && imagenes.trim().startsWith('[')) {
          try {
            final decoded = jsonDecode(imagenes);
            if (decoded is List && decoded.isNotEmpty) {
              final urls = decoded
                  .map((e) => e is Map
                      ? (e['url'] ?? '').toString()
                      : e.toString())
                  .where((s) => s.isNotEmpty)
                  .toList();
              if (urls.isNotEmpty) _images = urls;
            }
          } catch (e) {
            PierLog.error('Error decodificando imagenes JSON: $e');
          }
        }
        _loadingResenas = false;
      });
    } else {
      PierLog.error('No se pudo cargar detalle de ${widget.product.id}');
      setState(() => _loadingResenas = false);
    }
  }

  // GET /recomendaciones/:id — el payload es reducido (id, nombre, precios,
  // imagen_url, stock_online, categoria, afinidad); al pintar se resuelve cada
  // id contra el catálogo del provider para recuperar descripción/rating.
  // La afinidad no se muestra (métrica interna del backend).
  Future<void> _cargarRecomendaciones() async {
    final result =
        await _productosRepo.recomendaciones(widget.product.id);
    if (!mounted) return;
    if (result['success'] == true) {
      final data =
          List<Map<String, dynamic>>.from(result['recomendaciones'] ?? []);
      final items = data
          .map((json) => Product.fromJson(json))
          .where((p) => p.id.isNotEmpty && p.id != widget.product.id)
          .toList();
      PierLog.info('✅ ${items.length} recomendaciones cargadas');
      setState(() => _recomendaciones = items);
    } else {
      PierLog.debug('Sin recomendaciones: ${result['message']}');
    }
  }

  /// "Avísame" para producto agotado: registra el interés (demanda no
  /// atendida) y lo confirma. No requiere sesión, igual que en la web.
  void _avisarme() {
    DemandaService.registrarClicAgotado(widget.product.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(LucideIcons.bellRing, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  'Anotamos tu interés en "${widget.product.nombre}". Te avisaremos cuando vuelva.')),
        ]),
        backgroundColor: AppColors.pierDoradoOscuro,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
  }

  void _addToCart() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    if (widget.product.agotado) return; // el botón ya es "Avísame"; doble guard
    // Tamaño elegido: el selector solo aparece si hay precio grande, así que
    // sin selector _selectedSize queda en 0 (chico).
    final tamano = _selectedSize == 1 ? 'grande' : 'chico';
    PierLog.info('🛒 Agregando: ${widget.product.nombre} ($tamano) x$_quantity');
    final cart = Provider.of<CartProvider>(context, listen: false);
    cart.addItem(widget.product, _quantity, tamano, _precioBase);
    _cartAnimController.forward(from: 0);
    final sufijoTam = tamano == 'grande' ? ' (Grande)' : '';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text('$_quantity × ${widget.product.nombre}$sufijoTam agregado'),
      ]),
      backgroundColor: AppColors.pierVerde,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
    Navigator.pop(context);
  }

  void _addRelatedToCart(Product p) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    PierLog.info('🛒 Agregando relacionado: ${p.nombre}');
    final cart = Provider.of<CartProvider>(context, listen: false);
    cart.addItem(p);
    _getRelatedCartController(p.id).forward(from: 0);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('${p.nombre} agregado')),
        ]),
        backgroundColor: AppColors.pierVerde,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  void _shareProduct() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    PierLog.info('Compartiendo: ${widget.product.nombre}');
    final title =
        '¡Mira este delicioso producto!\n\n${widget.product.nombre} por solo \$${widget.product.precio.toStringAsFixed(2)}\n\nEncuéntralo en ${BusinessInfo.marca}.';
    try {
      if (widget.product.imagenUrl.isNotEmpty) {
        final response = await http
            .get(Uri.parse(widget.product.imagenUrl))
            .timeout(const Duration(seconds: 5));
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/producto_compartido.jpg');
        await file.writeAsBytes(response.bodyBytes);
        await SharePlus.instance.share(
            ShareParams(files: [XFile(file.path)], text: title));
      } else {
        await SharePlus.instance.share(ShareParams(text: title));
      }
    } catch (e) {
      PierLog.error('Fallo compartir imagen: $e');
      await SharePlus.instance.share(ShareParams(text: title));
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  String _formatFecha(dynamic fecha) {
    if (fecha == null) return '';
    try {
      final dt = DateTime.parse(fecha.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays == 0) return 'Hoy';
      if (diff.inDays == 1) return 'Ayer';
      if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
      if (diff.inDays < 30) return 'Hace ${(diff.inDays / 7).floor()} sem.';
      return 'Hace ${(diff.inDays / 30).floor()} mes';
    } catch (e) {
      PierLog.error('Error formateando fecha: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    // listen: true — reacciona a cambios de promociones y productos
    final provider = Provider.of<ProductProvider>(context);
    final tienePromo = provider.tieneDescuento(widget.product.id);
    final precioFinalBase =
        provider.precioConDescuento(widget.product.id, widget.product.precio);
    final promo = provider.promocionDeProducto(widget.product.id);

    // ✅ FIX: extraer tipo igual que en products_screen y web PromoBadge
    final tipo = promo?['tipo']?.toString() ?? '';
    final porcentaje = promo?['descuento_porcentaje']?.toString();
    final badgeDestacado = promo?['badge_destacado']?.toString();
    final nombreTemporada = promo?['nombre_temporada']?.toString();

    final totalPrice =
        provider.precioConDescuento(widget.product.id, _precioBase) * _quantity;

    final totalResenas = _detalleProducto != null
        ? (int.tryParse(_detalleProducto!['reviews']?.toString() ?? '0') ?? 0)
        : widget.product.totalResenas;

    final rating = _detalleProducto != null
        ? (double.tryParse(
                _detalleProducto!['rating_promedio']?.toString() ?? '0') ??
            0.0)
        : widget.product.rating;

    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: CustomScrollView(
        slivers: [
          // ── GALERÍA ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 360,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Hero: la imagen "vuela" desde la tarjeta del catálogo /
                  // favoritos (mismo tag producto-img-<id>).
                  Hero(
                    tag: 'producto-img-${widget.product.id}',
                    child: PageView.builder(
                      itemCount: _images.length,
                      onPageChanged: (i) =>
                          setState(() => _currentImageIndex = i),
                      itemBuilder: (context, i) => Image.network(
                        _images[i],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, _) => Container(
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
                        _topBtn(LucideIcons.arrowLeft,
                            () => Navigator.pop(context)),
                        Row(children: [
                          TweenAnimationBuilder<double>(
                            key: ValueKey(_isFavorite),
                            // Pop solo al marcar favorito
                            tween: Tween(
                                begin: _isFavorite ? 1.35 : 1.0, end: 1.0),
                            duration: const Duration(milliseconds: 450),
                            curve: Curves.elasticOut,
                            builder: (_, scale, child) =>
                                Transform.scale(scale: scale, child: child),
                            child: _topBtn(
                              _isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              _toggleFavorito,
                              color: _isFavorite ? Colors.red : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _topBtn(LucideIcons.share2, _shareProduct),
                        ]),
                      ],
                    ),
                  ),
                  // ✅ FIX: badges múltiples por tipo (igual que web PromoBadge)
                  if (tienePromo || widget.product.popular)
                    Positioned(
                      bottom: 20, left: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.product.popular && !tienePromo)
                            _detailBadge(AppColors.pierDorado,
                                icon: Icons.star_rounded, label: 'Popular'),
                          if (tienePromo) ...[
                            if (porcentaje != null)
                              _detailBadge(Colors.red.shade500,
                                  icon: LucideIcons.tag,
                                  label: '-$porcentaje%'),
                            if (tipo == 'relampago')
                              _detailBadge(Colors.orange.shade600,
                                  icon: LucideIcons.zap,
                                  label: 'Oferta Relámpago'),
                            if (tipo == 'temporada')
                              _detailBadge(Colors.orange.shade700,
                                  icon: LucideIcons.sparkles,
                                  label: nombreTemporada ?? 'De Temporada'),
                            if (tipo == 'nuevo')
                              _detailBadge(Colors.blue.shade500,
                                  icon: LucideIcons.badgePlus,
                                  label: 'Nuevo'),
                            if (tipo == 'destacado' && badgeDestacado != null)
                              _detailBadge(Colors.purple.shade500,
                                  icon: LucideIcons.sparkles,
                                  label: badgeDestacado),
                          ],
                        ],
                      ),
                    ),
                  if (_images.length > 1)
                    Positioned(
                      bottom: 20, left: 0, right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                            _images.length,
                            (i) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  width: _currentImageIndex == i ? 20 : 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: _currentImageIndex == i
                                        ? AppColors.pierDorado
                                        : Colors.white.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                )),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── CONTENIDO ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.pierArena,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.pierVerde.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.product.categoria.toUpperCase(),
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.pierVerde,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5),
                          ),
                        ),
                        // ✅ NUEVO: chips tipo y sabor (igual que web)
                        if (widget.product.tipo != null &&
                            widget.product.tipo!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.pierDorado
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(widget.product.tipo!,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.pierDoradoOscuro,
                                    fontWeight: FontWeight.w700)),
                          ),
                        if (widget.product.sabor != null &&
                            widget.product.sabor!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.pierDorado.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(widget.product.sabor!,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.pierDoradoOscuro,
                                    fontWeight: FontWeight.w700)),
                          ),
                        Row(children: [
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            rating > 0 ? rating.toStringAsFixed(1) : '—',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary),
                          ),
                          const SizedBox(width: 4),
                          Text('($totalResenas)',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.textSecondary)),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.product.nombre,
                      style: const TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          height: 1.2),
                    ),
                    const SizedBox(height: 6),

                    // Precio con/sin descuento
                    if (tienePromo) ...[
                      Row(children: [
                        Text('\$${precioFinalBase.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.red.shade600)),
                        const SizedBox(width: 10),
                        Text(
                            '\$${widget.product.precio.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary.withValues(alpha: 0.5),
                                decoration: TextDecoration.lineThrough)),
                      ]),
                      const SizedBox(height: 8),
                      // ✅ FIX: badges de promo en sección info (igual que web PromoBadge)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (tipo == 'relampago')
                            _detailBadge(Colors.orange.shade600,
                                icon: LucideIcons.zap,
                                label: 'Oferta Relámpago'),
                          if (tipo == 'temporada')
                            _detailBadge(Colors.orange.shade700,
                                icon: LucideIcons.sparkles,
                                label: nombreTemporada ?? 'De Temporada'),
                          if (tipo == 'nuevo')
                            _detailBadge(Colors.blue.shade500,
                                icon: LucideIcons.badgePlus,
                                label: 'Nuevo'),
                          if (tipo == 'destacado' && badgeDestacado != null)
                            _detailBadge(Colors.purple.shade500,
                                icon: LucideIcons.sparkles,
                                label: badgeDestacado),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    Text(
                      widget.product.descripcion,
                      style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (widget.product.precioGrande != null) ...[
                      const SizedBox(height: 28),
                      const Text('Selecciona el tamaño',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 14),
                      Row(
                        children: List.generate(_sizes.length, (i) {
                          final sel = _selectedSize == i;
                          final precioTam = i == 0
                              ? widget.product.precio
                              : (widget.product.precioGrande ??
                                  widget.product.precio * 1.4);
                          final precioFinalTam = tienePromo
                              ? provider.precioConDescuento(
                                  widget.product.id, precioTam)
                              : precioTam;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedSize = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: EdgeInsets.only(
                                    right: i < _sizes.length - 1 ? 10 : 0),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? AppColors.pierVerde
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: sel
                                          ? AppColors.pierVerde
                                              .withValues(alpha: 0.3)
                                          : Colors.black
                                              .withValues(alpha: 0.05),
                                      blurRadius: sel ? 12 : 6,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(_sizes[i],
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: sel
                                                ? Colors.white
                                                : AppColors.textPrimary)),
                                    const SizedBox(height: 6),
                                    // ✅ NUEVO: precio por tamaño con tachado si hay descuento
                                    if (tienePromo) ...[
                                      Text(
                                          '\$${precioTam.toStringAsFixed(0)}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: sel
                                                  ? Colors.white
                                                      .withValues(alpha: 0.6)
                                                  : AppColors.textSecondary.withValues(alpha: 0.5),
                                              decoration:
                                                  TextDecoration.lineThrough)),
                                      Text(
                                          '\$${precioFinalTam.toStringAsFixed(0)}',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              color: sel
                                                  ? Colors.white
                                                  : Colors.red.shade600)),
                                    ] else
                                      Text(
                                          '\$${precioTam.toStringAsFixed(0)}',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              color: sel
                                                  ? Colors.white
                                                  : AppColors.pierVerde)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],

                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 2),
                              Text(
                                '\$${totalPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: tienePromo
                                        ? Colors.red.shade600
                                        : AppColors.pierVerde),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.pierArena,
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Row(children: [
                              _qtyBtn(LucideIcons.minus, () {
                                if (_quantity > 1)
                                  setState(() => _quantity--);
                              }),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                child: Text('$_quantity',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ),
                              _qtyBtn(LucideIcons.plus, () {
                                if (_quantity < 10)
                                  setState(() => _quantity++);
                              }),
                            ]),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ScaleTransition(
                              scale: _cartAnim,
                              child: SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  // Agotado → "Avísame" (registra interés)
                                  onPressed: widget.product.agotado
                                      ? _avisarme
                                      : _addToCart,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.product.agotado
                                        ? AppColors.pierDorado
                                        : AppColors.pierVerde,
                                    disabledBackgroundColor: AppColors
                                        .textSecondary
                                        .withValues(alpha: 0.35),
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final wide = constraints.maxWidth > 80;
                                      final agotado =
                                          widget.product.agotado;
                                      return Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                              agotado
                                                  ? LucideIcons.bellRing
                                                  : LucideIcons.shoppingCart,
                                              color: Colors.white,
                                              size: 18),
                                          if (wide) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                                agotado
                                                    ? 'Avísame'
                                                    : 'Añadir',
                                                style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color: Colors.white)),
                                          ],
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ✅ NUEVO: Sección ingredientes (igual que web)
                    if (widget.product.ingredientes.isNotEmpty) ...[
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
                        children: widget.product.ingredientes.map((ing) =>
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.pierVerde
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.pierVerde
                                      .withValues(alpha: 0.2)),
                            ),
                            child: Text(ing,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.pierVerde,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ).toList(),
                      ),
                    ],

                    // ── RESEÑAS ────────────────────────────────────────
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Opiniones destacadas',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CreateReviewScreen(
                                    product: widget.product)),
                          ).then((_) => _cargarDetalle()),
                          child: Row(children: [
                            Icon(LucideIcons.pencil,
                                color: AppColors.pierVerde, size: 16),
                            SizedBox(width: 4),
                            Text('Escribir',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.pierVerde,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _loadingResenas
                        ? Center(
                            child: CircularProgressIndicator(
                                color: AppColors.pierVerde))
                        : _resenas.isEmpty
                            ? Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Text('Aún no hay opiniones.',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14)),
                              )
                            : Column(
                                children: _resenas
                                    .take(2)
                                    .map((r) => Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 20),
                                          child: ReviewItemWidget(
                                            id: r['id']?.toString() ?? '',
                                            name: '${r['autor_nombre'] ?? ''} ${((r['autor_apellido'] ?? '') as String).isNotEmpty ? '${(r['autor_apellido'] as String)[0]}.' : ''}'
                                                .trim(),
                                            rating: double.tryParse(
                                                    r['rating']
                                                            ?.toString() ??
                                                        '5') ??
                                                5.0,
                                            comment: r['comentario'] ?? '',
                                            date: _formatFecha(
                                                r['created_at']),
                                            likesCount: int.tryParse(
                                                    r['likes_count']
                                                            ?.toString() ??
                                                        '0') ??
                                                0,
                                            hasLiked:
                                                r['user_has_liked'] == true ||
                                                    r['has_liked'] == 1 ||
                                                    r['user_has_liked'] == 1,
                                          ),
                                        ))
                                    .toList(),
                              ),
                    if (totalResenas > 0)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ProductReviewsScreen(
                                    product: widget.product)),
                          ).then((_) => _cargarDetalle()),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                                color: AppColors.textSecondary.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            'Ver las $totalResenas opiniones',
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                          ),
                        ),
                      ),

                    // ── OTROS CLIENTES TAMBIÉN PIDIERON ────────────────
                    // Recomendaciones del backend por co-compra (sustituyó a
                    // la antigua "También te puede gustar" de misma categoría)
                    _buildRecomendaciones(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NUEVO: sección "Otros clientes también pidieron" (recomendaciones del
  // backend; su fallback ya garantiza activos y con stock). Reusa la card de
  // relacionados; cada id se resuelve contra el catálogo si ya está cargado.
  Widget _buildRecomendaciones() {
    if (_recomendaciones.isEmpty) return const SizedBox.shrink();
    return Consumer<ProductProvider>(
      builder: (context, prov, _) {
        final items = _recomendaciones.map((r) {
          final delCatalogo = prov.productos.where((p) => p.id == r.id);
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
              // Misma altura que relacionados (y que home/products)
              height: 310,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final p = items[i];
                  return GestureDetector(
                    // push (no pushReplacement): el botón atrás regresa
                    // al producto de origen, igual que en relacionados.
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ProductDetailScreen(product: p))),
                    child: _buildRelatedCard(p, prov),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ✅ NUEVO: card idéntica a la del catálogo (products_screen _buildGridCard)
  Widget _buildRelatedCard(Product p, ProductProvider prov) {
    final tienePromo = prov.tieneDescuento(p.id);
    final precioFinal = prov.precioConDescuento(p.id, p.precio);
    final promo = prov.promocionDeProducto(p.id);
    final tipoRel = promo?['tipo']?.toString() ?? '';
    final porcentajeRel = promo?['descuento_porcentaje']?.toString();
    final badgeDestacadoRel = promo?['badge_destacado']?.toString();

    return Container(
      width: 165,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Imagen ──
            Expanded(
              flex: 55,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    p.imagenUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.pierArena,
                      child: Icon(LucideIcons.cake,
                          color: AppColors.pierVerde, size: 40),
                    ),
                  ),
                  // Gradiente inferior
                  Positioned(
                    bottom: 0, left: 0, right: 0, height: 70,
                    child: Container(
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
                  // Precio sobre imagen
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
                  // ✅ FIX: badges múltiples en relacionados (mismo sistema)
                  Positioned(
                    top: 8, left: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (p.popular && !tienePromo)
                          _detailBadge(AppColors.pierDorado,
                              icon: Icons.star_rounded, label: 'Popular',
                              small: true),
                        if (tienePromo) ...[
                          if (porcentajeRel != null)
                            _detailBadge(Colors.red.shade500,
                                icon: LucideIcons.tag,
                                label: '-$porcentajeRel%', small: true),
                          if (tipoRel == 'relampago')
                            _detailBadge(Colors.orange.shade600,
                                icon: LucideIcons.zap,
                                label: 'Flash', small: true),
                          if (tipoRel == 'temporada')
                            _detailBadge(Colors.orange.shade700,
                                icon: LucideIcons.sparkles,
                                label: 'Temporada', small: true),
                          if (tipoRel == 'destacado' && badgeDestacadoRel != null)
                            _detailBadge(Colors.purple.shade500,
                                icon: LucideIcons.sparkles,
                                label: badgeDestacadoRel, small: true),
                          if (tipoRel == 'nuevo')
                            _detailBadge(Colors.blue.shade500,
                                icon: LucideIcons.badgePlus,
                                label: 'Nuevo', small: true),
                        ],
                      ],
                    ),
                  ),
                  // Botón añadir al carrito
                  Positioned(
                    bottom: 8, right: 8,
                    child: Consumer<CartProvider>(
                      builder: (context, cart, _) {
                        final inCart = cart.isInCart(p.id);
                        final anim = _relatedCartAnims[p.id];
                        Widget btn = GestureDetector(
                          onTap: () => _addRelatedToCart(p),
                          child: Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.pierVerde,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: [BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6)],
                            ),
                            child: Icon(
                              inCart ? LucideIcons.check : LucideIcons.plus,
                              color: Colors.white, size: 18,
                            ),
                          ),
                        );
                        if (anim != null) {
                          btn = ScaleTransition(scale: anim, child: btn);
                        }
                        return btn;
                      },
                    ),
                  ),
                ],
              ),
            ),
            // ── Info ──
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
                        // Chip categoría
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
                        // Nombre
                        Text(p.nombre,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        // Descripción
                        Text(p.descripcion,
                            style: TextStyle(
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
                    // Rating
                    Row(children: [
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        p.rating > 0 ? p.rating.toStringAsFixed(1) : '—',
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600),
                      ),
                      if (p.totalResenas > 0) ...[
                        const SizedBox(width: 3),
                        Text('(${p.totalResenas})',
                            style: TextStyle(
                                fontSize: 9, color: AppColors.textSecondary.withValues(alpha: 0.5))),
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

  /// Helper: badge para la pantalla de detalle (galería + sección info + relacionados)
  Widget _detailBadge(Color color,
      {required IconData icon, required String label, bool small = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: EdgeInsets.symmetric(
          horizontal: small ? 6 : 10, vertical: small ? 3 : 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: color.withValues(alpha: 0.4), blurRadius: 6)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: small ? 9 : 13),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: small ? 8 : 11,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _topBtn(IconData icon, VoidCallback onTap, {Color? color}) =>
      GestureDetector(
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

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Icon(icon, color: AppColors.textPrimary, size: 18),
        ),
      );
}

// ── ReviewItemWidget ──────────────────────────────────────────────────────────
class ReviewItemWidget extends StatefulWidget {
  final String id;
  final String name;
  final double rating;
  final String comment;
  final String date;
  final int likesCount;
  final bool hasLiked;

  const ReviewItemWidget({
    super.key,
    required this.id,
    required this.name,
    required this.rating,
    required this.comment,
    required this.date,
    required this.likesCount,
    required this.hasLiked,
  });

  @override
  State<ReviewItemWidget> createState() => _ReviewItemWidgetState();
}

class _ReviewItemWidgetState extends State<ReviewItemWidget> {
  final _resenasRepo = ResenasRepository();
  late int _likes;
  late bool _hasLiked;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _likes = widget.likesCount;
    _hasLiked = widget.hasLiked;
  }

  Future<void> _toggleLike() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    if (_isLoading || widget.id.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasLiked = !_hasLiked;
      _likes += _hasLiked ? 1 : -1;
    });

    final result = await _resenasRepo.like(widget.id);
    if (!mounted) return;

    if (result['success'] != true) {
      PierLog.error('Error al dar like a reseña ${widget.id}');
      setState(() {
        _hasLiked = !_hasLiked;
        _likes += _hasLiked ? 1 : -1;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Error al dar me gusta'),
        backgroundColor: AppColors.error,
      ));
    } else {
      PierLog.info(
          'Like ${_hasLiked ? 'agregado' : 'removido'} — reseña ${widget.id}');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    AppColors.pierDorado.withValues(alpha: 0.15),
                child: Text(
                  widget.name.length >= 2
                      ? widget.name.substring(0, 2).toUpperCase()
                      : widget.name.isNotEmpty
                          ? widget.name[0]
                          : '?',
                  style: TextStyle(
                      color: AppColors.pierDoradoOscuro,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(widget.date,
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ]),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(children: [
                const Icon(Icons.star_rounded,
                    color: Colors.amber, size: 15),
                const SizedBox(width: 3),
                Text(widget.rating.toStringAsFixed(1),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary)),
              ]),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _toggleLike,
                child: Row(
                  children: [
                    Icon(
                      _hasLiked
                          ? LucideIcons.thumbsUp
                          : LucideIcons.thumbsUp,
                      color: _hasLiked
                          ? AppColors.pierVerde
                          : AppColors.textSecondary.withValues(alpha: 0.5),
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_likes',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _hasLiked
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _hasLiked
                            ? AppColors.pierVerde
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(widget.comment,
          style: TextStyle(
              fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
    ]);
  }
}