import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../data/models/product_model.dart';
import '../../../../../data/providers/cart_provider.dart';
import '../../../../../data/providers/auth_provider.dart';
import '../../../../../data/providers/product_provider.dart';
import '../../../../../core/services/api_service.dart';
import '../../../../../core/constants/api_constants.dart';
import '../../auth/login_screen.dart';
import '../reviews/create_review_screen.dart';
import '../reviews/product_reviews_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with TickerProviderStateMixin {
  final ApiService _api = ApiService();

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

  final List<Map<String, String>> _sizes = [
    {'label': 'Chico',  'sub': '4–6 pers.'},
    {'label': 'Grande', 'sub': '10–12 pers.'},
  ];

  double get _totalPrice {
    final base = _selectedSize == 0
        ? widget.product.precio
        : (widget.product.precioGrande ?? widget.product.precio * 1.4);
    return base * _quantity;
  }

  @override
  void initState() {
    super.initState();
    _images = widget.product.imagenes.isNotEmpty
        ? widget.product.imagenes
        : [widget.product.imagenUrl];

    _cartAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _cartAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _cartAnimController, curve: Curves.elasticOut));

    _cargarDetalle();
    _cargarEstadoFavorito();
  }

  @override
  void dispose() {
    _cartAnimController.dispose();
    super.dispose();
  }

  Future<void> _cargarEstadoFavorito() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;
    final result = await _api.getAuth('/favoritos/ids');
    if (!mounted) return;
    if (result['success'] == true) {
      final ids = List<String>.from(
          (result['ids'] ?? []).map((e) => e.toString()));
      setState(() => _isFavorite = ids.contains(widget.product.id));
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
        ? await _api.deleteAuth(ApiConstants.favoritoById(widget.product.id))
        : await _api.postAuth('/favoritos/${widget.product.id}', {});
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() => _isFavorite = yaEsFav);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Error al actualizar favorito'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _cargarDetalle() async {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    final result = await provider.cargarDetalle(widget.product.id);
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _detalleProducto = result['producto'];
        _resenas = List<Map<String, dynamic>>.from(result['resenas'] ?? []);
        final imagenes = result['producto']?['imagenes'];
        if (imagenes is List && imagenes.isNotEmpty) {
          _images = imagenes.map((e) => e.toString()).toList();
        }
        _loadingResenas = false;
      });
    } else {
      setState(() => _loadingResenas = false);
    }
  }

  void _addToCart() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    final cart = Provider.of<CartProvider>(context, listen: false);
    cart.addItem(widget.product, _quantity);
    _cartAnimController.forward(from: 0);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text('$_quantity × ${widget.product.nombre} agregado'),
      ]),
      backgroundColor: AppColors.pierVerde,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
    Navigator.pop(context);
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
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final relatedProducts =
        Provider.of<ProductProvider>(context, listen: false)
            .productos
            .where((p) =>
                p.categoria == widget.product.categoria &&
                p.id != widget.product.id)
            .take(6)
            .toList();

    final totalResenas = _detalleProducto != null
        ? (int.tryParse(_detalleProducto!['reviews']?.toString() ?? '0') ?? 0)
        : widget.product.totalResenas;

    final rating = _detalleProducto != null
        ? (double.tryParse(
                _detalleProducto!['rating_promedio']?.toString() ?? '0') ??
            0.0)
        : widget.product.rating;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      body: CustomScrollView(
        slivers: [
          // ── GALERÍA ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 360,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: _images.length,
                    onPageChanged: (i) =>
                        setState(() => _currentImageIndex = i),
                    itemBuilder: (context, i) => Image.network(
                      _images[i],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, _) => Container(
                        color: const Color(0xFFE8E4DF),
                        child: const Icon(Icons.image_outlined,
                            size: 60, color: Colors.grey),
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 16, right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _topBtn(Icons.arrow_back_rounded,
                            () => Navigator.pop(context)),
                        Row(children: [
                          _topBtn(
                            _isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            _toggleFavorito,
                            color: _isFavorite ? Colors.red : null,
                          ),
                          const SizedBox(width: 10),
                          _topBtn(Icons.share_rounded, () {}),
                        ]),
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
              decoration: const BoxDecoration(
                color: Color(0xFFF5F2ED),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.pierVerde,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5),
                          ),
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
                                  fontSize: 13, color: Colors.grey[500])),
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
                    const SizedBox(height: 10),
                    Text(
                      widget.product.descripcion,
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.5),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // ── TAMAÑO ─────────────────────────────────────────
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
                          return Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedSize = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: EdgeInsets.only(
                                    right: i < _sizes.length - 1 ? 10 : 0),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
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
                                child: Column(children: [
                                  Text(_sizes[i]['label']!,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: sel
                                              ? Colors.white
                                              : AppColors.textPrimary)),
                                  const SizedBox(height: 3),
                                  Text(_sizes[i]['sub']!,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: sel
                                              ? Colors.white
                                                  .withValues(alpha: 0.75)
                                              : Colors.grey[500])),
                                ]),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],

                    // ── INSTRUCCIONES ──────────────────────────────────
                    const SizedBox(height: 28),
                    const Text('Instrucciones especiales',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    TextField(
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: "Ej. 'Feliz Cumpleaños Ana'...",
                        hintStyle: TextStyle(
                            color: Colors.grey[400], fontSize: 14),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.2))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: AppColors.pierVerde, width: 1.5)),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),

                    // ── TOTAL + CANTIDAD + CARRITO ─────────────────────
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
                                      color: Colors.grey[500])),
                              const SizedBox(height: 2),
                              Text(
                                '\$${_totalPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.pierVerde),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F2ED),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Row(children: [
                              _qtyBtn(Icons.remove_rounded, () {
                                if (_quantity > 1) {
                                  setState(() => _quantity--);
                                }
                              }),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                child: Text('$_quantity',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ),
                              _qtyBtn(Icons.add_rounded, () {
                                if (_quantity < 10) {
                                  setState(() => _quantity++);
                                }
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
                                  onPressed: _addToCart,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.pierVerde,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final wide =
                                          constraints.maxWidth > 80;
                                      return Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                              Icons.shopping_cart_rounded,
                                              color: Colors.white,
                                              size: 18),
                                          if (wide) ...[
                                            const SizedBox(width: 6),
                                            const Text('Añadir',
                                                style: TextStyle(
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
                        // ← Navega a CreateReviewScreen
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CreateReviewScreen(
                                    product: widget.product)),
                          ).then((_) => _cargarDetalle()),
                          child: const Row(children: [
                            Icon(Icons.edit_rounded,
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
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.pierVerde))
                        : _resenas.isEmpty
                            ? Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Text('Aún no hay opiniones.',
                                    style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 14)),
                              )
                            : Column(
                                children: _resenas
                                    .take(2)
                                    .map((r) => Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 20),
                                          child: _reviewItem(
                                            '${r['autor_nombre'] ?? ''} ${((r['autor_apellido'] ?? '') as String).isNotEmpty ? '${(r['autor_apellido'] as String)[0]}.' : ''}'
                                                .trim(),
                                            double.tryParse(r['rating']
                                                        ?.toString() ??
                                                    '5') ??
                                                5.0,
                                            r['comentario'] ?? '',
                                            _formatFecha(r['created_at']),
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
                                color: Colors.grey.withValues(alpha: 0.3)),
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

                    // ── RELACIONADOS ───────────────────────────────────
                    if (relatedProducts.isNotEmpty) ...[
                      const SizedBox(height: 36),
                      const Text('También te puede gustar',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 280,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: relatedProducts.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, i) {
                            final p = relatedProducts[i];
                            return GestureDetector(
                              onTap: () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          ProductDetailScreen(product: p))),
                              child: Container(
                                width: 160,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.06),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        height: 140,
                                        width: double.infinity,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.network(p.imagenUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) =>
                                                    Container(
                                                      color:
                                                          AppColors.pierArena,
                                                      child: const Icon(
                                                          Icons.cake_outlined,
                                                          color: AppColors
                                                              .pierVerde,
                                                          size: 32),
                                                    )),
                                            Positioned(
                                              bottom: 0,
                                              left: 0,
                                              right: 0,
                                              height: 50,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin:
                                                        Alignment.bottomCenter,
                                                    end: Alignment.topCenter,
                                                    colors: [
                                                      Colors.black.withValues(
                                                          alpha: 0.55),
                                                      Colors.transparent,
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              bottom: 8, left: 10,
                                              child: Text(
                                                  '\$${p.precio.toStringAsFixed(0)}',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 14,
                                                      shadows: [
                                                        Shadow(
                                                            color: Colors
                                                                .black38,
                                                            blurRadius: 4)
                                                      ])),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              10, 10, 10, 10),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(p.nombre,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                      color: AppColors
                                                          .textPrimary),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                              const SizedBox(height: 4),
                                              Text(p.descripcion,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[500],
                                                      height: 1.3),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                              const Spacer(),
                                              Row(children: [
                                                const Icon(
                                                    Icons.star_rounded,
                                                    color: Colors.amber,
                                                    size: 12),
                                                const SizedBox(width: 3),
                                                Text(
                                                  p.rating > 0
                                                      ? p.rating
                                                          .toStringAsFixed(1)
                                                      : '—',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey[600],
                                                      fontWeight:
                                                          FontWeight.w600),
                                                ),
                                              ]),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
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

  Widget _topBtn(IconData icon, VoidCallback onTap, {Color? color}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child:
              Icon(icon, size: 20, color: color ?? AppColors.textPrimary),
        ),
      );

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Icon(icon, color: AppColors.textPrimary, size: 18),
        ),
      );

  Widget _reviewItem(
          String name, double rating, String comment, String date) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    AppColors.pierDorado.withValues(alpha: 0.15),
                child: Text(
                  name.length >= 2
                      ? name.substring(0, 2).toUpperCase()
                      : name.isNotEmpty
                          ? name[0]
                          : '?',
                  style: const TextStyle(
                      color: AppColors.pierDoradoOscuro,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary)),
                    Text(date,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400])),
                  ]),
            ]),
            Row(children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 15),
              const SizedBox(width: 3),
              Text(rating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textPrimary)),
            ]),
          ],
        ),
        const SizedBox(height: 10),
        Text(comment,
            style: TextStyle(
                fontSize: 13, color: Colors.grey[600], height: 1.5)),
      ]);
}