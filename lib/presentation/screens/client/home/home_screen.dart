import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/product_model.dart';
import '../../../../data/providers/cart_provider.dart';
import '../../../widgets/product/product_card.dart';
import '../products/product_detail_screen.dart';
import '../products/products_screen.dart';
import '../cart/cart_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Product> products = ProductData.getSampleProducts();
  String selectedCategory = 'Todos';
  
  // Categorías con iconos para hacerlo más visual
  final List<Map<String, dynamic>> categories = [
    {'name': 'Todos', 'icon': Icons.grid_view},
    {'name': 'Pasteles', 'icon': Icons.cake},
    {'name': 'Roscas', 'icon': Icons.donut_large},
    {'name': 'Pays', 'icon': Icons.pie_chart}, // Icono aproximado
    {'name': 'Postres', 'icon': Icons.cookie},
    {'name': 'Cafetería', 'icon': Icons.coffee},
  ];

  List<Product> get filteredProducts {
    return products.where((p) {
      return selectedCategory == 'Todos' || p.category == selectedCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Obtenemos el nombre del usuario (o usamos uno por defecto)
    // Asumimos que tienes un getter 'userName' en tu AuthProvider, si no, usa un string fijo o el email
    final String userName = "Alexander"; // authProvider.userName ?? "Alexander";

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Column(
          children: [
            // 1. HEADER PERSONALIZADO (Saludo + Carrito)
            _buildCustomHeader(context, userName),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. BANNER DE PROMOCIÓN O PEDIDO ACTIVO
                    _buildActiveStatusBanner(),
                    
                    const SizedBox(height: 20),

                    // 3. BARRA DE BÚSQUEDA FLOTANTE
                    _buildSearchBar(),

                    const SizedBox(height: 25),

                    // 4. CATEGORÍAS (Estilo visual mejorado)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Categorías',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen(initialCategory: 'Todos'))),
                            child: const Text('Ver todo', style: TextStyle(color: AppColors.pierVerde, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildCategoryList(),

                    const SizedBox(height: 25),

                    // 5. PRODUCTOS RECOMENDADOS
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Text(
                        'Recomendado para ti',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildProductGrid(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildCustomHeader(BuildContext context, String name) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola, $name 👋',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.pierVerde,
                ),
              ),
              const Text(
                '¿Qué se te antoja hoy?',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          // Botón de carrito con Badge
          _buildCartButton(context),
        ],
      ),
    );
  }

  Widget _buildActiveStatusBanner() {
    // Simulamos que hay una promoción o un estado interesante
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.pierVerde, AppColors.pierVerdeOscuro],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.pierVerde.withAlpha(77),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.pierDorado,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'NUEVO',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cheesecake de Frutos Rojos',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pruébalo con 15% de descuento',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.cake, color: Colors.white, size: 60),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) => setState(() => {}), // Aquí conectarías tu lógica de búsqueda real
        decoration: InputDecoration(
          hintText: 'Buscar pasteles, postres...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: AppColors.pierVerde),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 15),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = selectedCategory == cat['name'];
          
          return GestureDetector(
            onTap: () => setState(() => selectedCategory = cat['name']),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.pierVerde : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (!isSelected)
                        BoxShadow(
                          color: Colors.grey.withAlpha(26),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                    ],
                    border: isSelected ? null : Border.all(color: Colors.grey.shade200),
                  ),
                  child: Icon(
                    cat['icon'],
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  cat['name'],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.pierVerde : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid() {
    if (filteredProducts.isEmpty) {
      return const Center(child: Text("No hay productos disponibles"));
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shrinkWrap: true, // Importante para que funcione dentro del SingleChildScrollView
      physics: const NeverScrollableScrollPhysics(), // El scroll lo maneja el padre
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.70, // Ajuste para que se vea bien la tarjeta
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        return ProductCard(
          product: product,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProductDetailScreen(product: product)),
          ),
        );
      },
    );
  }

  Widget _buildCartButton(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(26),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.textPrimary),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CartScreen())),
          ),
        ),
        Consumer<CartProvider>(
          builder: (context, cart, child) {
            if (cart.totalQuantity == 0) return const SizedBox();
            return Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  '${cart.totalQuantity}',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}