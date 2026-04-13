// lib/presentation/screens/client/products/products_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/services/api_service.dart';
import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/utils/logger.dart';
import '../../../../../data/providers/auth_provider.dart';
import '../../../../../data/providers/cart_provider.dart';
import '../../../../../data/providers/product_provider.dart';
import '../../../../../data/providers/navigation_provider.dart';
import '../../../../../data/models/product_model.dart';
import '../../auth/login_screen.dart';
import 'product_detail_screen.dart';

enum SortOption { popular, priceAsc, priceDesc, nameAsc, nameDesc }

IconData _iconForCategoria(String nombre) {
  switch (nombre.toLowerCase()) {
    case 'pasteles': return Icons.cake_outlined;
    case 'roscas': return Icons.donut_large_outlined;
    case 'pays': return Icons.pie_chart_outline;
    case 'postres': return Icons.cookie_outlined;
    case 'cafetería':
    case 'cafeteria': return Icons.coffee_outlined;
    case 'bebidas': return Icons.local_drink_outlined;
    case 'panes': return Icons.breakfast_dining_outlined;
    default: return Icons.fastfood_outlined;
  }
}

class ProductsScreen extends StatefulWidget {
  final String? initialCategory;
  const ProductsScreen({super.key, this.initialCategory});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _api = ApiService();

  SortOption _sort = SortOption.popular;
  String _category = 'Todos';
  String _searchQuery = '';
  bool _isGridView = true;

  final Map<String, AnimationController> _cartControllers = {};
  final Map<String, Animation<double>> _cartAnims = {};
  final Set<String> _favoritos = {};

  List<String> _sabores = [];
  List<String> _tamanos = [];
  List<String> _tipos = [];
  String? _filtroSabor;
  String? _filtroTamano;
  String? _filtroTipo;
  bool _filtrosLoaded = false;

  List<Map<String, dynamic>> _categoriasApi = [];
  final List<Map<String, dynamic>> _categoriasFallback = [
    {'name': 'Todos',     'icon': Icons.apps_rounded},
    {'name': 'Pasteles',  'icon': Icons.cake_outlined},
    {'name': 'Roscas',   'icon': Icons.donut_large_outlined},
    {'name': 'Pays',     'icon': Icons.pie_chart_outline},
    {'name': 'Postres',  'icon': Icons.cookie_outlined},
    {'name': 'Cafetería','icon': Icons.coffee_outlined},
  ];

  List<Map<String, dynamic>> get _categories {
    if (_categoriasApi.isEmpty) return _categoriasFallback;
    return [
      {'name': 'Todos', 'icon': Icons.apps_rounded},
      ..._categoriasApi.map((c) => {
        'name': (c['nombre'] ?? c['name'] ?? '').toString(),
        'icon': _iconForCategoria((c['nombre'] ?? c['name'] ?? '').toString()),
      }),
    ];
  }

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? 'Todos';
    PierLog.nav('ProductsScreen abierto — categoría inicial: $_category');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<ProductProvider>().cargarProductos();
      _cargarCategorias();
      _cargarFiltros();
      await _cargarFavoritosIds();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final c in _cartControllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    PierLog.api('GET ${ApiConstants.categorias}');
    final result = await _api.get(ApiConstants.categorias);
    if (!mounted) return;
    if (result['success'] == true) {
      final lista = List<Map<String, dynamic>>.from(
          result['categorias'] ?? result['data'] ?? []);
      if (lista.isNotEmpty) {
        PierLog.info('✅ Categorías cargadas: ${lista.length}');
        setState(() => _categoriasApi = lista);
      }
    } else {
      PierLog.error('Error al cargar categorías: ${result['message']}');
    }
  }

  Future<void> _cargarFiltros() async {
    PierLog.api('GET ${ApiConstants.filtros}');
    final result = await _api.get(ApiConstants.filtros);
    if (!mounted) return;
    if (result['success'] == true) {
      final filtros = result['filtros'] as Map<String, dynamic>? ?? {};
      setState(() {
        _sabores = List<String>.from(filtros['sabores'] ?? []);
        _tamanos = List<String>.from(filtros['tamanos'] ?? []);
        _tipos   = List<String>.from(filtros['tipos'] ?? []);
        _filtrosLoaded = true;
      });
      PierLog.info('✅ Filtros cargados — sabores:${_sabores.length} tamaños:${_tamanos.length} tipos:${_tipos.length}');
    } else {
      PierLog.error('Error al cargar filtros: ${result['message']}');
    }
  }

  Future<void> _cargarFavoritosIds() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;
    PierLog.api('GET ${ApiConstants.favoritosIds}');
    final result = await _api.getAuth(ApiConstants.favoritosIds);
    if (!mounted) return;
    if (result['success'] == true) {
      final ids = List<String>.from(
          (result['ids'] ?? []).map((e) => e.toString()));
      setState(() {
        _favoritos.clear();
        _favoritos.addAll(ids);
      });
      PierLog.info('✅ Favoritos cargados: ${ids.length}');
    } else {
      PierLog.error('Error al cargar favoritos: ${result['message']}');
    }
  }

  Future<void> _goToDetail(Product p) async {
    PierLog.nav('→ ProductDetailScreen: ${p.nombre}');
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)),
    );
    if (mounted) await _cargarFavoritosIds();
  }

  AnimationController _getCartController(String id) {
    if (!_cartControllers.containsKey(id)) {
      final c = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 500));
      _cartControllers[id] = c;
      _cartAnims[id] = Tween<double>(begin: 1.0, end: 1.3).animate(
          CurvedAnimation(parent: c, curve: Curves.elasticOut));
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

    if (_filtroSabor != null && _filtroSabor != 'Todos') {
      list = list.where((p) => p.sabor == _filtroSabor).toList();
    }
    if (_filtroTamano != null && _filtroTamano != 'Todos') {
      list = list.where((p) => p.tamano == _filtroTamano).toList();
    }
    if (_filtroTipo != null && _filtroTipo != 'Todos') {
      list = list.where((p) => p.tipo == _filtroTipo).toList();
    }

    switch (_sort) {
      case SortOption.priceAsc:
        list.sort((a, b) => a.precio.compareTo(b.precio));
      case SortOption.priceDesc:
        list.sort((a, b) => b.precio.compareTo(a.precio));
      case SortOption.nameAsc:
        list.sort((a, b) => a.nombre.compareTo(b.nombre));
      case SortOption.nameDesc:
        list.sort((a, b) => b.nombre.compareTo(a.nombre));
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
      _searchQuery.isNotEmpty || _category != 'Todos' ||
      _filtroSabor != null || _filtroTamano != null || _filtroTipo != null;

  void _clearFilters() {
    PierLog.debug('Filtros limpiados');
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _category = 'Todos';
      _sort = SortOption.popular;
      _filtroSabor = null;
      _filtroTamano = null;
      _filtroTipo = null;
    });
  }

  void _addToCart(Product p, CartProvider cart) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    PierLog.info('🛒 Agregando al carrito desde catálogo: ${p.nombre}');
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

  Future<void> _toggleFavorito(String id) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    final yaEsFav = _favoritos.contains(id);
    setState(() {
      if (yaEsFav) { _favoritos.remove(id); } else { _favoritos.add(id); }
    });
    PierLog.api(yaEsFav
        ? 'DELETE ${ApiConstants.favoritoById(id)}'
        : 'POST /favoritos/$id');
    final result = yaEsFav
        ? await _api.deleteAuth(ApiConstants.favoritoById(id))
        : await _api.postAuth('/favoritos/$id', {});
    if (!mounted) return;
    if (result['success'] != true) {
      PierLog.error('Error al ${yaEsFav ? 'quitar' : 'agregar'} favorito $id');
      setState(() {
        if (yaEsFav) { _favoritos.add(id); } else { _favoritos.remove(id); }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Error al actualizar favorito'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filtros',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    if (_filtroSabor != null ||
                        _filtroTamano != null ||
                        _filtroTipo != null)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _filtroSabor = null;
                            _filtroTamano = null;
                            _filtroTipo = null;
                          });
                          setSheetState(() {});
                        },
                        child: Text('Limpiar',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.red.shade400,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_sabores.isNotEmpty) ...[
                  const Text('Sabor',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _sabores.where((s) => s != 'Todos').map((s) {
                      final sel = _filtroSabor == s;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _filtroSabor = sel ? null : s);
                          setSheetState(() {});
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.pierVerde : Colors.grey.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? AppColors.pierVerde : Colors.grey.shade200),
                          ),
                          child: Text(s,
                              style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.w500, color: sel ? Colors.white : Colors.grey[700])),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                if (_tamanos.isNotEmpty) ...[
                  const Text('Tamaño',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _tamanos.where((t) => t != 'Todos').map((t) {
                      final sel = _filtroTamano == t;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _filtroTamano = sel ? null : t);
                          setSheetState(() {});
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.pierVerde : Colors.grey.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? AppColors.pierVerde : Colors.grey.shade200),
                          ),
                          child: Text(t,
                              style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.w500, color: sel ? Colors.white : Colors.grey[700])),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                if (_tipos.isNotEmpty) ...[
                  const Text('Tipo',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _tipos.where((t) => t != 'Todos').map((t) {
                      final sel = _filtroTipo == t;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _filtroTipo = sel ? null : t);
                          setSheetState(() {});
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.pierVerde : Colors.grey.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? AppColors.pierVerde : Colors.grey.shade200),
                          ),
                          child: Text(t,
                              style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.w500, color: sel ? Colors.white : Colors.grey[700])),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                if (!_filtrosLoaded)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: AppColors.pierVerde),
                    ),
                  ),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pierVerde,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Aplicar filtros',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Ordenar por',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.pierVerde.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: sel ? Border.all(color: AppColors.pierVerde.withValues(alpha: 0.3)) : null,
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.pierVerde : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(t.$3, size: 18, color: sel ? Colors.white : Colors.grey),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Text(t.$1,
                          style: TextStyle(fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                              color: sel ? AppColors.pierVerde : AppColors.textPrimary, fontSize: 15))),
                      if (sel) const Icon(Icons.check_circle_rounded, color: AppColors.pierVerde, size: 20),
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
    final cartCount = context.watch<CartProvider>().totalQuantity;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      body: Column(
        children: [
          _buildHeaderBackground(cartCount),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, i) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  final sel = _category == cat['name'];
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat['name'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.pierVerde : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? AppColors.pierVerde : Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat['icon'] as IconData, size: 13, color: sel ? Colors.white : Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(cat['name'] as String,
                              style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                                  color: sel ? Colors.white : Colors.grey[700])),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                PaintingBinding.instance.imageCache.clear();
                PaintingBinding.instance.imageCache.clearLiveImages();
                await context.read<ProductProvider>().refrescar();
                await _cargarCategorias();
                await _cargarFiltros();
              },
              color: AppColors.pierVerde,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Nuestro Menú',
                              style: TextStyle(fontFamily: 'Playfair Display', fontSize: 22,
                                  fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          GestureDetector(
                            onTap: () => setState(() => _isGridView = !_isGridView),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.pierVerde.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.pierVerde.withValues(alpha: 0.2)),
                              ),
                              child: Row(children: [
                                Icon(_isGridView ? Icons.grid_view_rounded : Icons.view_list_rounded,
                                    color: AppColors.pierVerde, size: 16),
                                const SizedBox(width: 5),
                                Text(_isGridView ? 'Cuadrícula' : 'Lista',
                                    style: const TextStyle(fontSize: 12, color: AppColors.pierVerde,
                                        fontWeight: FontWeight.w600)),
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.filter_alt_off_rounded, size: 14, color: Colors.red.shade400),
                                const SizedBox(width: 6),
                                Text('Quitar filtros',
                                    style: TextStyle(fontSize: 12, color: Colors.red.shade400, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (productProvider.isLoading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: AppColors.pierVerde)),
                    )
                  else if (products.isEmpty)
                    SliverFillRemaining(child: _buildEmptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _buildCard(products[i], productProvider),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBackground(int cartCount) {
    return Container(
      color: AppColors.pierVerde,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20, right: 20, bottom: 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Pier Repostería',
                      style: TextStyle(fontFamily: 'Playfair Display', fontSize: 28,
                          fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Artesanal & Gourmet',
                      style: TextStyle(fontSize: 13, color: Colors.white70)),
                ],
              ),
              GestureDetector(
                onTap: () => context.read<NavigationProvider>().setSelectedIndex(2),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 22),
                    ),
                    if (cartCount > 0)
                      Positioned(
                        right: -6, top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: AppColors.pierDorado, shape: BoxShape.circle),
                          child: Text('$cartCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Busca tu antojo...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  })
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.sort_rounded, color: Colors.grey, size: 20),
                        onPressed: _showSortSheet, tooltip: 'Ordenar'),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: Icon(Icons.tune_rounded,
                              color: _filtroSabor != null || _filtroTamano != null || _filtroTipo != null
                                  ? AppColors.pierVerde : Colors.grey, size: 20),
                          onPressed: _showFilterSheet, tooltip: 'Filtrar'),
                        if (_filtroSabor != null || _filtroTamano != null || _filtroTipo != null)
                          Positioned(right: 8, top: 8,
                              child: Container(width: 8, height: 8,
                                  decoration: const BoxDecoration(color: AppColors.pierVerde, shape: BoxShape.circle))),
                      ],
                    ),
                  ],
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ✅ ACTUALIZADO: recibe productProvider para consultar promociones
  Widget _buildCard(Product p, ProductProvider provider) {
    return GestureDetector(
      onTap: () => _goToDetail(p),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: _isGridView
              ? _buildGridCard(p, provider)
              : _buildListCard(p, provider),
        ),
      ),
    );
  }

  Widget _buildGridCard(Product p, ProductProvider provider) {
    // ✅ NUEVO: obtener precio con descuento si hay promo
    final tienePromo = provider.tieneDescuento(p.id);
    final precioFinal = provider.precioConDescuento(p.id, p.precio);
    final promo = provider.promocionDeProducto(p.id);
    final badge = promo?['badge_destacado']?.toString() ??
        (promo?['descuento_porcentaje'] != null
            ? '${promo!['descuento_porcentaje']}% OFF'
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 55,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(p.imagenUrl, fit: BoxFit.cover,
                  errorBuilder: (_, e, __) => Container(
                    color: AppColors.pierArena,
                    child: const Icon(Icons.cake_outlined, color: AppColors.pierVerde, size: 40),
                  )),
              // Badge popular
              if (p.popular && !tienePromo)
                Positioned(
                  top: 10, left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.pierDorado, borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, color: Colors.white, size: 10),
                        SizedBox(width: 3),
                        Text('POPULAR', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),
              // ✅ NUEVO: badge de descuento (reemplaza popular si hay promo)
              if (tienePromo && badge != null)
                Positioned(
                  top: 10, left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red.shade500, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_offer_rounded, color: Colors.white, size: 10),
                        const SizedBox(width: 3),
                        Text(badge, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              // Favorito
              Positioned(
                top: 8, right: 8,
                child: GestureDetector(
                  onTap: () => _toggleFavorito(p.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _favoritos.contains(p.id) ? Colors.red : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
                    ),
                    child: Icon(
                      _favoritos.contains(p.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _favoritos.contains(p.id) ? Colors.white : Colors.grey[500],
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
                // ✅ NUEVO: precio con tachado si hay descuento
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
                          style: TextStyle(fontSize: 11, color: Colors.grey[400], decoration: TextDecoration.lineThrough)),
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
                        style: const TextStyle(fontSize: 9, color: AppColors.pierVerde, fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(height: 3),
                Text(p.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(p.descripcion,
                    style: TextStyle(fontSize: 10, color: Colors.grey[500], height: 1.3),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 13),
                      const SizedBox(width: 3),
                      Text(p.rating > 0 ? p.rating.toStringAsFixed(1) : '5.0',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
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
                            decoration: BoxDecoration(color: AppColors.pierVerde, borderRadius: BorderRadius.circular(10)),
                            child: Icon(inCart ? Icons.check_rounded : Icons.add_rounded, color: Colors.white, size: 20),
                          ),
                        );
                        if (anim != null) btn = ScaleTransition(scale: anim, child: btn);
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

  Widget _buildListCard(Product p, ProductProvider provider) {
    final tienePromo = provider.tieneDescuento(p.id);
    final precioFinal = provider.precioConDescuento(p.id, p.precio);
    final promo = provider.promocionDeProducto(p.id);
    final badge = promo?['badge_destacado']?.toString() ??
        (promo?['descuento_porcentaje'] != null
            ? '${promo!['descuento_porcentaje']}% OFF'
            : null);

    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(p.imagenUrl, fit: BoxFit.cover,
                  errorBuilder: (_, e, __) => Container(
                    color: AppColors.pierArena,
                    child: const Icon(Icons.cake_outlined, color: AppColors.pierVerde, size: 36),
                  )),
              if (tienePromo && badge != null)
                Positioned(
                  top: 8, left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: Colors.red.shade500, borderRadius: BorderRadius.circular(6)),
                    child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
                )
              else if (p.popular)
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.pierDorado, borderRadius: BorderRadius.circular(6)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.star_rounded, color: Colors.white, size: 9),
                      SizedBox(width: 2),
                      Text('POP', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
                    ]),
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
                      color: _favoritos.contains(p.id) ? Colors.red : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
                    ),
                    child: Icon(
                      _favoritos.contains(p.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _favoritos.contains(p.id) ? Colors.white : Colors.grey[500],
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(p.descripcion,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500], height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ NUEVO: precio con tachado en lista
                        Row(children: [
                          Text('\$${precioFinal.toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800,
                                  color: tienePromo ? Colors.red.shade600 : AppColors.pierDoradoOscuro)),
                          if (tienePromo) ...[
                            const SizedBox(width: 6),
                            Text('\$${p.precio.toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[400],
                                    decoration: TextDecoration.lineThrough)),
                          ],
                        ]),
                        Row(children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                          const SizedBox(width: 3),
                          Text(p.rating > 0 ? p.rating.toStringAsFixed(1) : '5.0',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
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
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(color: AppColors.pierVerde, borderRadius: BorderRadius.circular(12)),
                            child: Icon(inCart ? Icons.check_rounded : Icons.add_rounded, color: Colors.white, size: 20),
                          ),
                        );
                        if (anim != null) btn = ScaleTransition(scale: anim, child: btn);
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
            decoration: BoxDecoration(color: AppColors.pierVerde.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: const Icon(Icons.search_off_rounded, size: 48, color: AppColors.pierVerde),
          ),
          const SizedBox(height: 20),
          const Text('Sin resultados',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('Intenta con otros términos\no ajusta los filtros',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.grey[500])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            label: const Text('Limpiar filtros', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pierVerde,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}