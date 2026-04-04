import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../data/models/product_model.dart';
import '../../../../../data/providers/cart_provider.dart';
import '../../../../../data/providers/auth_provider.dart';
import '../../../../../data/providers/product_provider.dart';
import '../../auth/login_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with TickerProviderStateMixin {
  int _quantity = 1;
  bool _isFavorite = false;
  int _currentImageIndex = 0;
  int _selectedSize = 1;
  late List<String> _images;
  late AnimationController _cartAnimController;
  late Animation<double> _cartAnim;

  final List<Map<String, String>> _sizes = [
    {'label': 'Chico',   'sub': '4–6 pers.'},
    {'label': 'Mediano', 'sub': '10–12 pers.'},
    {'label': 'Grande',  'sub': '20–25 pers.'},
  ];

  double get _totalPrice =>
      widget.product.precio * _quantity * (1 + _selectedSize * 0.4);

  @override
  void initState() {
    super.initState();
    _images = [
      widget.product.imagenUrl,
      widget.product.imagenUrl,
      widget.product.imagenUrl,
    ];
    _cartAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _cartAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _cartAnimController, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _cartAnimController.dispose();
    super.dispose();
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

  void _showReviewsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, sc) => Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            height: 4, width: 40,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Opiniones',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              controller: sc,
              padding: const EdgeInsets.all(20),
              itemCount: 10,
              separatorBuilder: (context, index) => const Divider(height: 28),
              itemBuilder: (context, i) {
                final names = ['María G.', 'Carlos R.', 'Ana P.', 'Luis M.', 'Sofía T.'];
                final stars = [5.0, 4.8, 5.0, 5.0, 3.5];
                final dates = ['Hace 2 días', 'Hace 1 semana', 'Hace 2 semanas', 'Hace 1 mes', 'Hace 1 mes'];
                final comments = [
                  '¡Delicioso! El pan es súper suave y la mezcla de leches tiene el dulzor perfecto.',
                  'Excelente presentación y sabor. Llegó justo a tiempo para mi evento familiar.',
                  'Lo pedí para el cumpleaños de mi mamá, quedó encantada.',
                  'Muy bueno, lo recomiendo ampliamente.',
                  'Estuvo bien, aunque esperaba un poco más.',
                ];
                final idx = i % 5;
                return _reviewItem(names[idx], stars[idx], comments[idx], dates[idx]);
              },
            ),
          ),
        ]),
      ),
    );
  }

  void _showAddReviewSheet() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    int selectedRating = 5;
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Calificar producto',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => IconButton(
                iconSize: 40,
                icon: Icon(i < selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Colors.amber),
                onPressed: () => setModal(() => selectedRating = i + 1),
              )),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Cuéntanos tu experiencia...',
                filled: true,
                fillColor: const Color(0xFFF5F2ED),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.pierVerde, width: 1.5)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('¡Gracias por tu opinión!'),
                    backgroundColor: AppColors.pierVerde,
                  ));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pierVerde,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Enviar opinión',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final relatedProducts = Provider.of<ProductProvider>(context, listen: false)
        .productos
        .where((p) => p.categoria == widget.product.categoria && p.id != widget.product.id)
        .take(6)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 360,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: _images.length,
                    onPageChanged: (i) => setState(() => _currentImageIndex = i),
                    itemBuilder: (context, i) => Image.network(
                      _images[i], fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFE8E4DF),
                        child: const Icon(Icons.image_outlined, size: 60, color: Colors.grey),
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 16, right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _topBtn(Icons.arrow_back_rounded, () => Navigator.pop(context)),
                        Row(children: [
                          _topBtn(
                            _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            () {
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              if (!auth.isAuthenticated) {
                                Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const LoginScreen()));
                                return;
                              }
                              setState(() => _isFavorite = !_isFavorite);
                            },
                            color: _isFavorite ? Colors.red : null,
                          ),
                          const SizedBox(width: 10),
                          _topBtn(Icons.share_rounded, () {}),
                        ]),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 20, left: 0, right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_images.length, (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.pierVerde.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.product.categoria.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.pierVerde,
                                fontWeight: FontWeight.w800, letterSpacing: 0.5),
                          ),
                        ),
                        Row(children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            widget.product.rating > 0
                                ? widget.product.rating.toStringAsFixed(1)
                                : '4.9',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${widget.product.totalResenas > 0 ? widget.product.totalResenas : 120})',
                            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                          ),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.product.nombre,
                      style: const TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 28, fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary, height: 1.2),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.product.descripcion,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 28),
                    const Text('Selecciona el tamaño',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 14),
                    Row(
                      children: List.generate(_sizes.length, (i) {
                        final sel = _selectedSize == i;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedSize = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.only(
                                right: i < _sizes.length - 1 ? 10 : 0,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: sel ? AppColors.pierVerde : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(
                                  color: sel
                                      ? AppColors.pierVerde.withValues(alpha: 0.3)
                                      : Colors.black.withValues(alpha: 0.05),
                                  blurRadius: sel ? 12 : 6,
                                  offset: const Offset(0, 4),
                                )],
                              ),
                              child: Column(children: [
                                Text(_sizes[i]['label']!,
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: sel ? Colors.white : AppColors.textPrimary)),
                                const SizedBox(height: 3),
                                Text(_sizes[i]['sub']!,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: sel
                                            ? Colors.white.withValues(alpha: 0.75)
                                            : Colors.grey[500])),
                              ]),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 28),
                    const Text('Instrucciones especiales',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    TextField(
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: "Ej. 'Feliz Cumpleaños Ana'...",
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: Border.all(color: Colors.grey.withValues(alpha: 0.2)).top),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.pierVerde, width: 1.5)),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12, offset: const Offset(0, 4),
                        )],
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total a pagar',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                              const SizedBox(height: 2),
                              Text(
                                '\$${_totalPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w900,
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
                                if (_quantity > 1) setState(() => _quantity--);
                              }),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('$_quantity',
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                              _qtyBtn(Icons.add_rounded, () {
                                if (_quantity < 10) setState(() => _quantity++);
                              }),
                            ]),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ScaleTransition(
                              scale: _cartAnim,
                              child: SizedBox(
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: _addToCart,
                                  icon: const Icon(Icons.shopping_cart_rounded,
                                      color: Colors.white, size: 18),
                                  label: const Text('Añadir',
                                      style: TextStyle(
                                          fontSize: 15, fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.pierVerde,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Opiniones destacadas',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        GestureDetector(
                          onTap: _showAddReviewSheet,
                          child: const Row(children: [
                            Icon(Icons.edit_rounded,
                                color: AppColors.pierVerde, size: 16),
                            SizedBox(width: 4),
                            Text('Escribir',
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.pierVerde,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _reviewItem('María G.', 5.0,
                        '¡Delicioso! El pan es súper suave y la mezcla de leches tiene el dulzor perfecto.',
                        'Hace 2 días'),
                    const SizedBox(height: 20),
                    _reviewItem('Carlos R.', 4.8,
                        'Excelente presentación y sabor. Llegó justo a tiempo para mi evento familiar.',
                        'Hace 1 semana'),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _showReviewsSheet,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'Ver las ${widget.product.totalResenas > 0 ? widget.product.totalResenas : 120} opiniones',
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ),
                    if (relatedProducts.isNotEmpty) ...[
                      const SizedBox(height: 36),
                      const Text('También te puede gustar',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 230,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: relatedProducts.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 12),
                          itemBuilder: (context, i) {
                            final p = relatedProducts[i];
                            return GestureDetector(
                              onTap: () => Navigator.pushReplacement(context,
                                  MaterialPageRoute(
                                      builder: (_) => ProductDetailScreen(product: p))),
                              child: Container(
                                width: 148,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 12, offset: const Offset(0, 4),
                                  )],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 6,
                                        child: Stack(fit: StackFit.expand, children: [
                                          Image.network(p.imagenUrl, fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                color: AppColors.pierArena,
                                                child: const Icon(Icons.cake_outlined,
                                                    color: AppColors.pierVerde, size: 32),
                                              )),
                                          Positioned(
                                            bottom: 0, left: 0, right: 0, height: 50,
                                            child: Container(
                                              decoration: BoxDecoration(gradient: LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: [Colors.black.withValues(alpha: 0.5), Colors.transparent],
                                              )),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 8, left: 10,
                                            child: Text('\$${p.precio.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 14,
                                                    shadows: [Shadow(color: Colors.black38, blurRadius: 4)])),
                                          ),
                                        ]),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(p.nombre,
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                      color: AppColors.textPrimary),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis),
                                              Row(children: [
                                                const Icon(Icons.star_rounded,
                                                    color: Colors.amber, size: 12),
                                                const SizedBox(width: 3),
                                                Text(
                                                  p.rating > 0 ? p.rating.toStringAsFixed(1) : '5.0',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey[600],
                                                      fontWeight: FontWeight.w600),
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
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8, offset: const Offset(0, 2),
            )],
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

  Widget _reviewItem(String name, double rating, String comment, String date) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.pierDorado.withValues(alpha: 0.15),
                child: Text(
                  name.length >= 2 ? name.substring(0, 2).toUpperCase() : name[0],
                  style: const TextStyle(
                      color: AppColors.pierDoradoOscuro,
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14,
                        color: AppColors.textPrimary)),
                Text(date, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ]),
            ]),
            Row(children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 15),
              const SizedBox(width: 3),
              Text(rating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13,
                      color: AppColors.textPrimary)),
            ]),
          ],
        ),
        const SizedBox(height: 10),
        Text(comment,
            style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5)),
      ]);
}