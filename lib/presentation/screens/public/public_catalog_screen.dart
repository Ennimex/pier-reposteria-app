import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/product_model.dart';
import '../../widgets/product/product_card.dart';
import '../auth/login_screen.dart';
import '../client/products/product_detail_screen.dart';

class PublicCatalogScreen extends StatefulWidget {
  final String? initialCategory;

  const PublicCatalogScreen({
    Key? key,
    this.initialCategory,
  }) : super(key: key);

  @override
  State<PublicCatalogScreen> createState() => _PublicCatalogScreenState();
}

class _PublicCatalogScreenState extends State<PublicCatalogScreen> {
  // Datos
  final List<Product> allProducts = ProductData.getSampleProducts();
  
  // Estado de filtros
  String selectedCategory = 'Todos';
  String searchQuery = '';
  
  final List<String> categories = [
    'Todos', 'Pasteles', 'Roscas', 'Pays', 'Postres', 'Cafetería',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null && categories.contains(widget.initialCategory)) {
      selectedCategory = widget.initialCategory!;
    }
  }

  List<Product> get filteredProducts {
    return allProducts.where((p) {
      final matchesCategory = selectedCategory == 'Todos' || p.category == selectedCategory;
      final matchesSearch = p.name.toLowerCase().contains(searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _redirectToLogin() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Inicia sesión para acceder a esta función'),
        backgroundColor: AppColors.pierVerde,
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('Catálogo'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => const LoginScreen())
            ),
            icon: const Icon(Icons.person, color: AppColors.pierVerde),
            label: const Text('Ingresar', style: TextStyle(color: AppColors.pierVerde, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Barra de Búsqueda
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Buscar delicias...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          // 2. Filtros de Categoría
          Container(
            height: 50,
            color: Colors.white,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = selectedCategory == category;
                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  selectedColor: AppColors.pierVerde,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (bool selected) {
                    if (selected) {
                      setState(() => selectedCategory = category);
                    }
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // 3. Grid de Productos
          Expanded(
            child: filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        const Text('No encontramos productos', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.68,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                    ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      // Usamos un Stack para interceptar el botón de carrito
                      return Stack(
                        children: [
                          ProductCard(
                            product: product,
                            onTap: () {
                              // Ver detalle sí está permitido (Zona pública)
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductDetailScreen(product: product),
                                ),
                              );
                            },
                          ),
                          // Capa invisible sobre el botón de carrito del ProductCard
                          // para redirigir al login en lugar de agregar al carrito
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: GestureDetector(
                              onTap: _redirectToLogin,
                              child: Container(
                                width: 40,
                                height: 40,
                                color: Colors.transparent, // Zona táctil invisible sobre el icono
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}