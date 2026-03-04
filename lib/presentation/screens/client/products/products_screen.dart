import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/product_model.dart';
import '../../../../data/providers/cart_provider.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../widgets/product/product_card.dart';
import 'product_detail_screen.dart';
import '../../auth/login_screen.dart';

enum SortOption { priceAsc, priceDesc, nameAsc, nameDesc, popular }

class ProductsScreen extends StatefulWidget {
  final String? initialCategory;
  const ProductsScreen({super.key, this.initialCategory});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final List<Product> allProducts = ProductData.getSampleProducts();
  final TextEditingController _searchController = TextEditingController();

  SortOption selectedSort = SortOption.popular;
  String selectedCategory = 'Todos';
  String _searchQuery = '';
  
  late RangeValues priceRange;
  bool showOnlyPopular = false;
  bool isGridView = true;

  double get maxPrice {
    // price is non-nullable in Product model so we can compute directly
    if (allProducts.isEmpty) return 1000;
    return allProducts
        .map((p) => p.price)
        .reduce((a, b) => a > b ? a : b);
  }

  final List<String> categories = [
    'Todos', 'Pasteles', 'Roscas', 'Pays', 'Postres', 'Cafetería',
  ];

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.initialCategory ?? 'Todos';
    priceRange = RangeValues(0, maxPrice);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _s(String v) { try { return v.isEmpty ? '' : v; } catch (_) { return ''; } }
  double _d(double v) { try { return v; } catch (_) { return 0.0; } }
  bool _b(bool v)     { try { return v; } catch (_) { return false; } }

  List<Product> get filteredProducts {
    final safe = allProducts.where((p) {
      try { _s(p.id); return true; } catch (_) { return false; }
    }).toList();

    List<Product> products = selectedCategory == 'Todos'
        ? List.from(safe)
        : safe.where((p) => _s(p.category) == selectedCategory).toList();

    final q = _searchQuery.toLowerCase();
    if (q.isNotEmpty) {
      products = products
          .where((p) =>
              _s(p.name).toLowerCase().contains(q) ||
              _s(p.description).toLowerCase().contains(q) ||
              _s(p.category).toLowerCase().contains(q))
          .toList();
    }

    products = products
        .where((p) => _d(p.price) >= priceRange.start && _d(p.price) <= priceRange.end)
        .toList();

    if (showOnlyPopular) {
      products = products.where((p) => _b(p.popular)).toList();
    }

    switch (selectedSort) {
      case SortOption.priceAsc:
        products.sort((a, b) => _d(a.price).compareTo(_d(b.price)));
        break;
      case SortOption.priceDesc:
        products.sort((a, b) => _d(b.price).compareTo(_d(a.price)));
        break;
      case SortOption.nameAsc:
        products.sort((a, b) => _s(a.name).compareTo(_s(b.name)));
        break;
      case SortOption.nameDesc:
        products.sort((a, b) => _s(b.name).compareTo(_s(a.name)));
        break;
      case SortOption.popular:
        products.sort((a, b) {
          if (_b(a.popular) && !_b(b.popular)) return -1;
          if (!_b(a.popular) && _b(b.popular)) return 1;
          return 0;
        });
    }

    return products;
  }

  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      selectedCategory != 'Todos' ||
      showOnlyPopular ||
      priceRange.start > 0 ||
      priceRange.end < maxPrice;

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      selectedCategory = 'Todos';
      showOnlyPopular = false;
      priceRange = RangeValues(0, maxPrice);
      selectedSort = SortOption.popular;
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filtros Avanzados',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      if (hasActiveFilters)
                        TextButton.icon(
                          onPressed: () {
                            setModalState(() {
                              _clearAllFilters();
                            });
                            setState(() {}); 
                          },
                          icon: const Icon(Icons.refresh, size: 16, color: Colors.red),
                          label: const Text('Limpiar', style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                  const Divider(height: 30),
                  const Text('Rango de Precio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildPriceRangeChip('Cualquiera', 0, maxPrice, setModalState),
                      _buildPriceRangeChip('Menos de \$100', 0, 100, setModalState),
                      _buildPriceRangeChip('\$100 - \$300', 100, 300, setModalState),
                      _buildPriceRangeChip('Más de \$300', 300, maxPrice, setModalState),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.pierVerde.withValues(alpha: 0.05 * 255),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Solo productos populares', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            Text('Lo más vendido de Pier', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        Switch(
                          value: showOnlyPopular,
                          onChanged: (val) {
                            setModalState(() {
                              showOnlyPopular = val;
                            });
                            setState(() {}); 
                          },
                          activeThumbColor: AppColors.pierVerde,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pierVerde,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Aplicar Filtros', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPriceRangeChip(String label, double min, double max, StateSetter setModalState) {
    bool isActive = priceRange.start == min && priceRange.end == max;

    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      selectedColor: AppColors.pierVerde,
      backgroundColor: Colors.grey[100], // Fondo más suave
      labelStyle: TextStyle(
        color: isActive ? Colors.white : AppColors.textPrimary,
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isActive ? AppColors.pierVerde : Colors.transparent), // Borde dinámico
      ),
      showCheckmark: false,
      onSelected: (bool selected) {
        setModalState(() {
          if (selected) {
             priceRange = RangeValues(min, max);
          } else {
             priceRange = RangeValues(0, maxPrice);
          }
        });
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = filteredProducts;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EE), // Fondo corporativo
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildSearchBar()),
          SliverToBoxAdapter(child: _buildCategoryChips()),
          SliverToBoxAdapter(child: _buildResultsHeader(products.length)),
          products.isEmpty
              ? SliverFillRemaining(child: _buildEmptyState())
              : isGridView
                  ? _buildSliverGrid(products)
                  : _buildSliverList(products),
        ],
      ),
    );
  }

  // --- REDISEÑO DEL SLIVER APP BAR ---
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: AppColors.pierVerde,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.tune, color: Colors.white),
              tooltip: 'Filtros avanzados',
              onPressed: _showFilterSheet,
            ),
            if (hasActiveFilters)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.pierVerde, width: 2),
                  ),
                ),
              ),
          ],
        ),
        IconButton(
          icon: Icon(
            isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            color: Colors.white,
          ),
          onPressed: () => setState(() => isGridView = !isGridView),
        ),
        IconButton(
          icon: const Icon(Icons.sort_rounded, color: Colors.white),
          onPressed: _showSortSheet,
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nuestro Menú',
              style: TextStyle(
                fontFamily: 'Playfair Display', // Tipografía oficial
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.pierVerdeOscuro, AppColors.pierVerde], // Gradiente Premium
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05 * 255),
                  ),
                ),
              ),
              Positioned(
                right: 40,
                bottom: -20,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.pierDorado.withValues(alpha: 0.15 * 255),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- REDISEÑO DEL BUSCADOR ---
  Widget _buildSearchBar() {
    return Container(
      color: AppColors.pierVerde, // Para que se fusione con el AppBar
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16), // Más redondeado
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08 * 255),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Buscar pasteles, pays, postres...',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.pierVerde),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  // --- REDISEÑO DE CHIPS DE CATEGORÍAS ---
  Widget _buildCategoryChips() {
    return Container(
      height: 45, // Un poco más bajos
      margin: const EdgeInsets.only(top: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20), // Alineado con el buscador
        itemCount: categories.length,
        separatorBuilder: (context, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final isSelected = selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.pierVerde : Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected ? AppColors.pierVerde : Colors.transparent, // Borde invisible si no está seleccionado
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: AppColors.pierVerde.withValues(alpha: 0.3 * 255), blurRadius: 8, offset: const Offset(0, 3))]
                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.03 * 255), blurRadius: 4, offset: const Offset(0, 2))], // Sombra suave siempre
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResultsHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$count ',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.pierVerde),
                ),
                TextSpan(
                  text: count == 1 ? 'producto' : 'productos',
                  style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (hasActiveFilters)
            GestureDetector(
              onTap: _clearAllFilters,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.filter_alt_off_rounded, size: 14, color: Colors.red.shade400),
                    const SizedBox(width: 4),
                    Text('Quitar filtros', style: TextStyle(fontSize: 12, color: Colors.red.shade400, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  SliverGrid _buildSliverGrid(List<Product> products) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: EdgeInsets.only(
            left: index % 2 == 0 ? 20 : 8,
            right: index % 2 == 0 ? 8 : 20,
            bottom: 16,
          ),
          child: ProductCard(
            product: products[index],
            onTap: () => _goToDetail(products[index]),
          ),
        ),
        childCount: products.length,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        mainAxisSpacing: 0,
      ),
    );
  }

  SliverList _buildSliverList(List<Product> products) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: _buildProductListTile(products[index]),
        ),
        childCount: products.length,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(color: AppColors.pierVerde.withValues(alpha: 0.08 * 255), shape: BoxShape.circle),
            child: const Icon(Icons.search_off_rounded, size: 48, color: AppColors.pierVerde),
          ),
          const SizedBox(height: 20),
          const Text('Sin resultados', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('Intenta con otros términos\no ajusta los filtros', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.grey[500])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _clearAllFilters,
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

  // --- REDISEÑO DE LA TARJETA EN LISTA ---
  Widget _buildProductListTile(Product product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // Más redondeado
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04 * 255), // Sombra más suave
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _goToDetail(product),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Stack(
                  children: [
                    Hero(
                      tag: 'list_${product.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16), // Coincide con la tarjeta
                        child: Image.network(
                          product.imageUrl,
                          width: 100, // Un poco más grande
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 100, height: 100,
                            color: AppColors.pierArena,
                            child: const Icon(Icons.cake_outlined, color: AppColors.pierVerde, size: 36),
                          ),
                        ),
                      ),
                    ),
                    if (_b(product.popular))
                      Positioned(
                        top: 6, left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.pierDorado,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('★ TOP', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _s(product.name),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _s(product.category),
                        style: const TextStyle(fontSize: 12, color: AppColors.pierVerde, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _s(product.description),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500], height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\$${_d(product.price).toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.pierDoradoOscuro),
                          ),
                          Consumer<CartProvider>(
                            builder: (context, cart, _) {
                              final isInCart = cart.isInCart(product.id);
                              return GestureDetector(
                                onTap: () => _handleAddToCart(product, cart),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isInCart ? AppColors.pierVerde : AppColors.pierArena, // Uso de pierArena
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isInCart ? Icons.check_rounded : Icons.add_shopping_cart_rounded,
                                        size: 16,
                                        color: isInCart ? Colors.white : AppColors.pierVerde,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              const Text('Ordenar productos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              _buildSortTile('Más populares', SortOption.popular, Icons.star_rounded),
              _buildSortTile('Precio: Menor a Mayor', SortOption.priceAsc, Icons.trending_up_rounded),
              _buildSortTile('Precio: Mayor a Menor', SortOption.priceDesc, Icons.trending_down_rounded),
              _buildSortTile('Nombre: A–Z', SortOption.nameAsc, Icons.sort_by_alpha_rounded),
              _buildSortTile('Nombre: Z–A', SortOption.nameDesc, Icons.sort_by_alpha_rounded),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortTile(String label, SortOption option, IconData icon) {
    final isSelected = selectedSort == option;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.pierVerde.withValues(alpha: 0.08 * 255) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.pierVerde.withValues(alpha: 0.15 * 255) : Colors.grey.withValues(alpha: 0.1 * 255),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: isSelected ? AppColors.pierVerde : Colors.grey),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.pierVerde : AppColors.textPrimary,
            fontSize: 15,
          ),
        ),
        trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.pierVerde, size: 22) : null,
        onTap: () {
          setState(() => selectedSort = option);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _handleAddToCart(Product product, CartProvider cart) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    cart.addItem(product);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('${product.name} agregado'),
            ],
          ),
          backgroundColor: AppColors.pierVerde,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  void _goToDetail(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProductDetailScreen(product: product)),
    );
  }
}