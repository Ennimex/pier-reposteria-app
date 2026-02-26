import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/product_model.dart';
import '../../../../data/providers/cart_provider.dart';
import '../../../widgets/product/product_card.dart'; // Asegúrate de que este widget exista
import 'product_detail_screen.dart';

enum SortOption {
  priceAsc,
  priceDesc,
  nameAsc,
  nameDesc,
  popular,
}

class ProductsScreen extends StatefulWidget {
  final String? initialCategory;

  const ProductsScreen({
    super.key, // Corregido super.key
    this.initialCategory,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Product> allProducts = ProductData.getSampleProducts();
  
  SortOption selectedSort = SortOption.popular;
  bool isGridView = true; // Estado para alternar vista

  final List<String> categories = [
    'Todos', 'Pasteles', 'Roscas', 'Pays', 'Postres', 'Cafetería',
  ];

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    if (widget.initialCategory != null) {
      initialIndex = categories.indexOf(widget.initialCategory!);
      if (initialIndex == -1) initialIndex = 0;
    }
    
    _tabController = TabController(
      length: categories.length,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Product> _getProductsByCategory(String category) {
    List<Product> products = category == 'Todos'
        ? List.from(allProducts)
        : allProducts.where((p) => p.category == category).toList();

    switch (selectedSort) {
      case SortOption.priceAsc:
        products.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SortOption.priceDesc:
        products.sort((a, b) => b.price.compareTo(a.price));
        break;
      case SortOption.nameAsc:
        products.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortOption.nameDesc:
        products.sort((a, b) => b.name.compareTo(a.name));
        break;
      case SortOption.popular:
        products.sort((a, b) {
          if (a.popular && !b.popular) return -1;
          if (!a.popular && b.popular) return 1;
          return 0;
        });
        break;
    }
    return products;
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.sort, color: AppColors.pierVerde),
                  SizedBox(width: 10),
                  Text(
                    'Ordenar productos',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSortOption('Más populares', SortOption.popular, Icons.star_outline),
              _buildSortOption('Precio: Menor a Mayor', SortOption.priceAsc, Icons.arrow_upward),
              _buildSortOption('Precio: Mayor a Menor', SortOption.priceDesc, Icons.arrow_downward),
              _buildSortOption('Nombre: A-Z', SortOption.nameAsc, Icons.sort_by_alpha),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String label, SortOption option, IconData icon) {
    final isSelected = selectedSort == option;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        // Corregido withOpacity
        color: isSelected ? AppColors.pierVerde.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? AppColors.pierVerde : Colors.grey),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.pierVerde : AppColors.textPrimary,
          ),
        ),
        trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.pierVerde) : null,
        onTap: () {
          setState(() => selectedSort = option);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9), // Fondo gris suave
      appBar: AppBar(
        backgroundColor: AppColors.pierVerde,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Nuestro Menú',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
            tooltip: 'Cambiar vista',
            onPressed: () => setState(() => isGridView = !isGridView),
          ),
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Ordenar',
            onPressed: _showSortOptions,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.pierDorado, // Indicador dorado elegante
          indicatorWeight: 4,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: categories.map((category) => Tab(text: category)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: categories.map((category) => _buildProductList(category)).toList(),
      ),
    );
  }

  Widget _buildProductList(String category) {
    final products = _getProductsByCategory(category);

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cake_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No hay productos aquí por ahora',
              style: TextStyle(fontSize: 18, color: Colors.grey[500], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return isGridView ? _buildGridView(products) : _buildListView(products);
  }

  Widget _buildGridView(List<Product> products) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68, // Tarjetas un poco más altas
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return ProductCard(
          product: products[index],
          onTap: () => _goToDetail(products[index]),
        );
      },
    );
  }

  Widget _buildListView(List<Product> products) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _buildProductListTile(products[index]),
    );
  }

  // --- DISEÑO DE TARJETA EN LISTA (NUEVO) ---
  Widget _buildProductListTile(Product product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06), // Corregido withOpacity
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _goToDetail(product),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 1. Imagen Grande
                Hero(
                  tag: 'list_${product.id}', // Tag único
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      product.imageUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 100, height: 100,
                        color: Colors.grey[200],
                        child: const Icon(Icons.cake, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // 2. Información
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (product.popular)
                            const Icon(Icons.star, color: Colors.amber, size: 18),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.description,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\$${product.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.pierDorado,
                            ),
                          ),
                          // Botón de carrito pequeño
                          Consumer<CartProvider>(
                            builder: (context, cart, _) {
                              final isInCart = cart.isInCart(product.id);
                              return InkWell(
                                onTap: () {
                                  cart.addItem(product);
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${product.name} agregado'),
                                      backgroundColor: AppColors.pierVerde,
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isInCart ? AppColors.pierVerde : Colors.grey[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isInCart ? Icons.shopping_bag : Icons.add_shopping_cart,
                                    size: 20,
                                    color: isInCart ? Colors.white : AppColors.pierVerde,
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

  void _goToDetail(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(product: product),
      ),
    );
  }
}