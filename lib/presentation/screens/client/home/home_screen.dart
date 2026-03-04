import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/product_model.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../widgets/product/product_card.dart';
import '../products/product_detail_screen.dart';
import '../products/products_screen.dart';
import '../../public/contact_screen.dart'; 

class AppAssets {
  static const splashBackground = 'assets/images/fondo_splash_verde_pier.png';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  final List<Product> products = ProductData.getSampleProducts();

  // Categorías
  final List<Map<String, dynamic>> categories = [
    {'name': 'Pasteles', 'icon': Icons.cake_outlined, 'color': const Color(0xFFE8D5C4)},
    {'name': 'Roscas', 'icon': Icons.donut_large_outlined, 'color': const Color(0xFFD4E8C4)},
    {'name': 'Pays', 'icon': Icons.pie_chart_outline, 'color': const Color(0xFFC4D4E8)},
    {'name': 'Postres', 'icon': Icons.cookie_outlined, 'color': const Color(0xFFE8C4D4)},
    {'name': 'Cafetería', 'icon': Icons.coffee_outlined, 'color': const Color(0xFFE8E4C4)},
  ];

  // Carrusel
  final List<Map<String, String>> _heroSlides = [
    {
      'tag': 'ARTESANAL',
      'title': 'Pier\nRepostería',
      'subtitle': 'Endulzamos cada momento especial',
      'cta': 'Ver Catálogo',
      'route': 'catalog', 
    },
    {
      'tag': 'PERSONALIZADOS',
      'title': 'Pasteles\nde Autor',
      'subtitle': 'Hacemos tu idea realidad',
      'cta': 'Cotizar ahora',
      'route': 'contact',
    },
    {
      'tag': 'NUEVO',
      'title': 'Cafetería\nPremium',
      'subtitle': 'Bebidas especiales para acompañar',
      'cta': 'Descubrir',
      'route': 'catalog',
    },
  ];

  // Banners
  final List<Map<String, dynamic>> _promos = [
    {
      'tag': '🎂 OFERTA',
      'title': '2x1 en Postres\nIndividuales',
      'subtitle': 'Solo este fin de semana',
      'color': AppColors.pierVerde,
      'accent': AppColors.pierDorado,
    },
    {
      'tag': '☕ COMBO',
      'title': 'Pastel +\nCafé del día',
      'subtitle': 'Ahorra \$45 pesos',
      'color': AppColors.pierDoradoOscuro,
      'accent': Colors.white,
    },
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        _currentPage = (_currentPage + 1) % _heroSlides.length;
      });
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isAuthenticated = auth.isAuthenticated;
    final popularProducts = products.where((p) => p.popular).toList();
    final newProducts = products.reversed.take(4).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EE),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(isAuthenticated)),
            SliverToBoxAdapter(child: _buildQuickSearchBar(context)),
            SliverToBoxAdapter(child: _buildHeroCarousel()),
            SliverToBoxAdapter(child: _buildPromoBanners()),
            SliverToBoxAdapter(
              child: _buildSection(
                title: 'Explora el menú',
                actionLabel: 'Ver todo',
                onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen())),
                child: _buildCategories(),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSection(
                title: 'Los más pedidos',
                actionLabel: 'Ver todos',
                onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen())),
                child: _buildProductsRow(popularProducts),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSection(
                title: 'Recién llegados',
                actionLabel: 'Ver catálogo',
                onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen())),
                child: _buildProductsRow(newProducts),
              ),
            ),
            SliverToBoxAdapter(child: _buildCustomOrderBanner(context)),
            SliverToBoxAdapter(child: _buildWhyUs()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isAuthenticated) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F3EE),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAuthenticated ? 'Hola, Alexander 👋' : '¡Bienvenido! 👋',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.pierVerdeOscuro,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '¿Qué se te antoja hoy?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.pierVerde,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.pierVerde.withValues(alpha: 0.3 * 255),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: isAuthenticated 
                ? const Text('A', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))
                : const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen(initialCategory: 'Todos'))),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04 * 255), blurRadius: 12, offset: const Offset(0, 4)),
            ],
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1 * 255)),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: AppColors.pierVerde.withValues(alpha: 0.8 * 255)),
              const SizedBox(width: 12),
              Text('Buscar pasteles, pays...', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCarousel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 240, // CORRECCIÓN: Aumentamos de 210 a 240
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.pierVerdeOscuro.withValues(alpha: 0.25 * 255),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              AppAssets.splashBackground,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.pierVerdeOscuro, AppColors.pierVerde],
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    Colors.black.withValues(alpha: 0.0 * 255),
                    Colors.black.withValues(alpha: 0.65 * 255),
                  ],
                ),
              ),
            ),
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.pierDorado.withValues(alpha: 0.15 * 255),
                ),
              ),
            ),
            PageView.builder(
              controller: _pageController,
              itemCount: _heroSlides.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (_, i) {
                final slide = _heroSlides[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.pierDorado,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          slide['tag']!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        slide['title']!,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                          fontFamily: 'Playfair Display',
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        slide['subtitle']!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9 * 255),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          if (slide['route'] == 'catalog') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen()));
                          } else {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactScreen()));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                slide['cta']!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.pierVerdeOscuro,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.pierVerdeOscuro),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              bottom: 14,
              right: 20,
              child: Row(
                children: List.generate(_heroSlides.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(left: 5),
                    width: _currentPage == i ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentPage == i ? AppColors.pierDorado : Colors.white.withValues(alpha: 0.4 * 255),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoBanners() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4, height: 20,
                decoration: BoxDecoration(color: AppColors.pierDorado, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              const Text('Ofertas especiales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: _promos.asMap().entries.map((e) {
              final i = e.key;
              final promo = e.value;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(left: i == 0 ? 0 : 10),
                  height: 135, // CORRECCIÓN: Aumentamos de 110 a 135
                  decoration: BoxDecoration(
                    color: promo['color'] as Color,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: (promo['color'] as Color).withValues(alpha: 0.35 * 255),
                        blurRadius: 16, offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20, bottom: -20,
                        child: Container(
                          width: 90, height: 90,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08 * 255)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribuye el espacio para no desbordar
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2 * 255),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                promo['tag'] as String,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  promo['title'] as String,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  promo['subtitle'] as String,
                                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8 * 255)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String actionLabel,
    required VoidCallback onAction,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(width: 4, height: 20, decoration: BoxDecoration(color: AppColors.pierDorado, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 10),
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                  ],
                ),
                GestureDetector(
                  onTap: onAction,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.pierVerde.withValues(alpha: 0.1 * 255),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(fontSize: 12, color: AppColors.pierVerde, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 110, // CORRECCIÓN: Aumentamos de 96 a 110
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final cat = categories[i];
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsScreen(initialCategory: cat['name']))),
            child: Column(
              children: [
                Container(
                  width: 62, height: 62,
                  decoration: BoxDecoration(
                    color: cat['color'] as Color,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(color: (cat['color'] as Color).withValues(alpha: 0.5 * 255), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Icon(cat['icon'] as IconData, color: AppColors.pierVerdeOscuro, size: 26),
                ),
                const SizedBox(height: 8),
                Text(cat['name'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductsRow(List<Product> items) {
    return SizedBox(
      height: 290, // CORRECCIÓN: Aumentamos de 270 a 290
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          return SizedBox(
            width: 170,
            child: ProductCard(
              product: items[i],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: items[i]))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomOrderBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pierDoradoOscuro, 
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.pierDoradoOscuro.withValues(alpha: 0.3 * 255), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('¿Buscas un diseño único?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 6),
                const Text('Hacemos realidad el pastel de tus sueños para ese evento especial.', style: TextStyle(color: Colors.white, fontSize: 12)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactScreen())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.pierDoradoOscuro,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cotizar ahora', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.cake_rounded, color: Colors.white, size: 60),
        ],
      ),
    );
  }

  Widget _buildWhyUs() {
    final features = [
      {'icon': Icons.eco_outlined, 'title': 'Natural', 'desc': '100% frescos', 'color': const Color(0xFFD4E8C4)},
      {'icon': Icons.handshake_outlined, 'title': 'Artesanal', 'desc': 'Con detalle', 'color': const Color(0xFFE8D5C4)},
      {'icon': Icons.local_shipping_outlined, 'title': 'Delivery', 'desc': 'A tu puerta', 'color': const Color(0xFFC4D4E8)},
      {'icon': Icons.star_outline_rounded, 'title': 'Calidad', 'desc': 'Exclusivo', 'color': const Color(0xFFE8E4C4)},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pierVerdeOscuro,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.pierVerdeOscuro.withValues(alpha: 0.3 * 255), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 20, decoration: BoxDecoration(color: AppColors.pierDorado, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              const Text('¿Por qué elegirnos?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: features.map((f) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08 * 255),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1 * 255)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(color: f['color'] as Color, borderRadius: BorderRadius.circular(12)),
                        child: Icon(f['icon'] as IconData, color: AppColors.pierVerdeOscuro, size: 20),
                      ),
                      const SizedBox(height: 8),
                      Text(f['title'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 3),
                      Text(f['desc'] as String, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.6 * 255), height: 1.3)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}