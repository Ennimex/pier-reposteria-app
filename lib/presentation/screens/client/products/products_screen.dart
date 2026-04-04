import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../data/providers/auth_provider.dart';
import '../../../../../data/providers/cart_provider.dart';
import '../../../../../data/providers/product_provider.dart';
import '../../../../../data/models/product_model.dart';
import '../../auth/login_screen.dart';
import 'product_detail_screen.dart';

enum SortOption { popular, priceAsc, priceDesc, nameAsc, nameDesc }

class ProductsScreen extends StatefulWidget {
  final String? initialCategory;
  const ProductsScreen({super.key, this.initialCategory});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  SortOption _sort = SortOption.popular;
  String _category = 'Todos';
  String _searchQuery = '';
  bool _showOnlyPopular = false;
  bool _isGridView = true;

  final Map<String, AnimationController> _cartControllers = {};
  final Map<String, Animation<double>> _cartAnims = {};
  final Set<String> _favoritos = {};

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Todos',     'icon': Icons.apps_rounded},
    {'name': 'Pasteles',  'icon': Icons.cake_outlined},
    {'name': 'Roscas',   'icon': Icons.donut_large_outlined},
    {'name': 'Pays',     'icon': Icons.pie_chart_outline},
    {'name': 'Postres',  'icon': Icons.cookie_outlined},
    {'name': 'Cafetería','icon': Icons.coffee_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? 'Todos';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().cargarProductos();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final c in _cartControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  AnimationController _getCartController(String id) {
    if (!_cartControllers.containsKey(id)) {
      final c = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 500));
      _cartControllers[id] = c;
      _cartAnims[id] = Tween<double>(begin: 1.0, end: 1.3)
          .animate(CurvedAnimation(parent: c, curve: Curves.elasticOut));
    }
    return _cartControllers[id]!;
  }

  List<Product> _filtered(List<Product> all) {
    var list = _category == 'Todos'
        ? List<Product>.from(all)
        : all.where((p) => p.categoria == _category).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) =>
          p.nombre.toLowerCase().contains(q) ||
          p.descripcion.toLowerCase().contains(q) ||
          p.categoria.toLowerCase().contains(q)).toList();
    }

    if (_showOnlyPopular) list = list.where((p) => p.popular).toList();

    switch (_sort) {
      case SortOption.priceAsc:  list.sort((a, b) => a.precio.compareTo(b.precio));
      case SortOption.priceDesc: list.sort((a, b) => b.precio.compareTo(a.precio));
      case SortOption.nameAsc:   list.sort((a, b) => a.nombre.compareTo(b.nombre));
      case SortOption.nameDesc:  list.sort((a, b) => b.nombre.compareTo(a.nombre));
      case SortOption.popular:
        list.sort((a, b) {
          if (a.popular && !b.popular) return -1;
          if (!a.popular && b.popular) return 1;
          return 0;
        });
    }
    return list;
  }

  bool get _hasFilters =>
      _searchQuery.isNotEmpty || _category != 'Todos' || _showOnlyPopular;

  void _clearFilters() => setState(() {
        _searchQuery = '';
        _searchController.clear();
        _category = 'Todos';
        _showOnlyPopular = false;
        _sort = SortOption.popular;
      });

  void _addToCart(Product p, CartProvider cart) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    cart.addItem(p);
    _getCartController(p.id).forward(from: 0);
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

  void _toggleFavorito(String id) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    setState(() {
      if (_favoritos.contains(id)) {
        _favoritos.remove(id);
      } else {
        _favoritos.add(id);
      }
    });
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Ordenar por',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary))),
              const SizedBox(height: 16),
              ...[
                ('Más populares',         SortOption.popular,   Icons.star_rounded),
                ('Precio: Menor a Mayor', SortOption.priceAsc,  Icons.trending_up_rounded),
                ('Precio: Mayor a Menor', SortOption.priceDesc, Icons.trending_down_rounded),
                ('Nombre: A–Z',           SortOption.nameAsc,   Icons.sort_by_alpha_rounded),
                ('Nombre: Z–A',           SortOption.nameDesc,  Icons.sort_by_alpha_rounded),
              ].map((t) {
                final sel = _sort == t.$2;
                return GestureDetector(
                  onTap: () {
                    setState(() => _sort = t.$2);
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.pierVerde.withValues(alpha: 0.08)
                          : Colors.grey.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: sel
                          ? Border.all(
                              color: AppColors.pierVerde.withValues(alpha: 0.3))
                          : null,
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.pierVerde
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(t.$3,
                            size: 18,
                            color: sel ? Colors.white : Colors.grey),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Text(t.$1,
                              style: TextStyle(
                                  fontWeight: sel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: sel
                                      ? AppColors.pierVerde
                                      : AppColors.textPrimary,
                                  fontSize: 15))),
                      if (sel)
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.pierVerde, size: 20),
                    ]),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final products = _filtered(productProvider.productos);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      body: CustomScrollView(
        slivers: [

          // ── HEADER VERDE ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.pierVerde,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 20, right: 20, bottom: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pier Repostería',
                              style: TextStyle(
                                  fontFamily: 'Playfair Display',
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          Text('Artesanal & Gourmet',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.white70)),
                        ],
                      ),
                      Consumer<CartProvider>(
                        builder: (context, cart, child) => Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.shopping_bag_outlined,
                                  color: Colors.white, size: 22),
                            ),
                            if (cart.totalQuantity > 0)
                              Positioned(
                                right: -6, top: -6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                      color: AppColors.pierDorado,
                                      shape: BoxShape.circle),
                                  child: Text('${cart.totalQuantity}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Busca tu antojo...',
                        hintStyle: TextStyle(
                            color: Colors.grey[400], fontSize: 15),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Colors.grey, size: 22),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: Colors.grey, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                })
                            : IconButton(
                                icon: const Icon(Icons.tune_rounded,
                                    color: Colors.grey, size: 20),
                                onPressed: _showSortSheet,
                              ),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── CHIPS DE CATEGORÍA ────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final cat = _categories[i];
                    final sel = _category == cat['name'];
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _category = cat['name'] as String),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.pierVerde : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: sel
                                  ? AppColors.pierVerde
                                  : Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat['icon'] as IconData,
                                size: 13,
                                color:
                                    sel ? Colors.white : Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text(cat['name'] as String,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: sel
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: sel
                                        ? Colors.white
                                        : Colors.grey[700])),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // ── HEADER RESULTADOS ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nuestro Menú',
                      style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _isGridView = !_isGridView),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.pierVerde.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.pierVerde
                                .withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        Icon(
                          _isGridView
                              ? Icons.grid_view_rounded
                              : Icons.view_list_rounded,
                          color: AppColors.pierVerde,
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isGridView ? 'Cuadrícula' : 'Lista',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.pierVerde,
                              fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_hasFilters)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: GestureDetector(
                  onTap: _clearFilters,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.filter_alt_off_rounded,
                            size: 14, color: Colors.red.shade400),
                        const SizedBox(width: 6),
                        Text('Quitar filtros',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade400,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── CONTENIDO ─────────────────────────────────────────────
          if (productProvider.isLoading)
            const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.pierVerde)),
            )
          else if (products.isEmpty)
            SliverFillRemaining(child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _buildCard(products[i]),
                  childCount: products.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _isGridView ? 2 : 1,
                  childAspectRatio: _isGridView ? 0.63 : 3.2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(Product p) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: _isGridView ? _buildGridCard(p) : _buildListCard(p),
        ),
      ),
    );
  }

  // ── GRID CARD ─────────────────────────────────────────────────────
  Widget _buildGridCard(Product p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 55,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(p.imagenUrl, fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.pierArena,
                    child: const Icon(Icons.cake_outlined,
                        color: AppColors.pierVerde, size: 40),
                  )),
              if (p.popular)
                Positioned(
                  top: 10, left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.pierDorado,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, color: Colors.white, size: 10),
                        SizedBox(width: 3),
                        Text('POPULAR',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),
              Positioned(
                top: 8, right: 8,
                child: GestureDetector(
                  onTap: () => _toggleFavorito(p.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _favoritos.contains(p.id)
                          ? Colors.red
                          : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8)],
                    ),
                    child: Icon(
                      _favoritos.contains(p.id)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _favoritos.contains(p.id)
                          ? Colors.white
                          : Colors.grey[500],
                      size: 16,
                    ),
                  ),
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
                Text('\$${p.precio.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.pierDoradoOscuro)),
                Text(p.nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(p.descripcion,
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey[500], height: 1.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 13),
                      const SizedBox(width: 3),
                      Text(
                          p.rating > 0
                              ? p.rating.toStringAsFixed(1)
                              : '5.0',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600)),
                    ]),
                    Consumer<CartProvider>(
                      builder: (context, cart, child) {
                        final inCart = cart.isInCart(p.id);
                        final anim = _cartAnims[p.id];
                        Widget btn = GestureDetector(
                          onTap: () => _addToCart(p, cart),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                                color: AppColors.pierVerde,
                                borderRadius: BorderRadius.circular(10)),
                            child: Icon(
                              inCart
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              color: Colors.white, size: 20,
                            ),
                          ),
                        );
                        if (anim != null) {
                          btn = ScaleTransition(scale: anim, child: btn);
                        }
                        return btn;
                      },
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

  // ── LIST CARD ─────────────────────────────────────────────────────
  Widget _buildListCard(Product p) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(p.imagenUrl, fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.pierArena,
                    child: const Icon(Icons.cake_outlined,
                        color: AppColors.pierVerde, size: 36),
                  )),
              if (p.popular)
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppColors.pierDorado,
                        borderRadius: BorderRadius.circular(6)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                            color: Colors.white, size: 9),
                        SizedBox(width: 2),
                        Text('POP',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 7,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 8, right: 8,
                child: GestureDetector(
                  onTap: () => _toggleFavorito(p.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: _favoritos.contains(p.id)
                          ? Colors.red
                          : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6)],
                    ),
                    child: Icon(
                      _favoritos.contains(p.id)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _favoritos.contains(p.id)
                          ? Colors.white
                          : Colors.grey[500],
                      size: 14,
                    ),
                  ),
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
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(p.descripcion,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('\$${p.precio.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.pierDoradoOscuro)),
                        Row(children: [
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 12),
                          const SizedBox(width: 3),
                          Text(
                              p.rating > 0
                                  ? p.rating.toStringAsFixed(1)
                                  : '5.0',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ],
                    ),
                    Consumer<CartProvider>(
                      builder: (context, cart, child) {
                        final inCart = cart.isInCart(p.id);
                        final anim = _cartAnims[p.id];
                        Widget btn = GestureDetector(
                          onTap: () => _addToCart(p, cart),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                                color: AppColors.pierVerde,
                                borderRadius: BorderRadius.circular(12)),
                            child: Icon(
                              inCart
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              color: Colors.white, size: 20,
                            ),
                          ),
                        );
                        if (anim != null) {
                          btn = ScaleTransition(scale: anim, child: btn);
                        }
                        return btn;
                      },
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
                color: AppColors.pierVerde.withValues(alpha: 0.08),
                shape: BoxShape.circle),
            child: const Icon(Icons.search_off_rounded,
                size: 48, color: AppColors.pierVerde),
          ),
          const SizedBox(height: 20),
          const Text('Sin resultados',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('Intenta con otros términos\no ajusta los filtros',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey[500])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            label: const Text('Limpiar filtros',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pierVerde,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}