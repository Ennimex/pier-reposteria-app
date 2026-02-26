import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/product_model.dart';
import '../../widgets/product/product_card.dart';
import '../auth/login_screen.dart';
import '../client/products/product_detail_screen.dart';
import 'public_catalog_screen.dart';
import 'about_us_screen.dart';
import 'contact_screen.dart';
import 'faq_screen.dart';
import 'legal_screen.dart';

// Asegúrate de tener esta imagen en tus assets o usa el logo como placeholder
class AppAssets {
  static const logo = 'assets/images/logo.png';
  static const splashBackground = 'assets/images/fondo_splash_verde_pier.png';
}

class HomePublicScreen extends StatefulWidget {
  const HomePublicScreen({super.key});

  @override
  State<HomePublicScreen> createState() => _HomePublicScreenState();
}

class _HomePublicScreenState extends State<HomePublicScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  // Datos del Carrusel 
  final List<Map<String, String>> _heroSlides = [
    {
      'title': 'Pier Repostería',
      'subtitle': 'Endulzamos tus momentos',
      'button': 'Ver Catálogo',
    },
    {
      'title': 'Calidad Artesanal',
      'subtitle': 'Ingredientes 100% naturales',
      'button': 'Conócenos',
    },
    {
      'title': 'Haz tu Pedido',
      'subtitle': 'Recoge en tu sucursal favorita',
      'button': 'Ver Sucursales',
    },
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_currentPage < _heroSlides.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filtro de populares [cite: 57]
    final popularProducts = ProductData.getSampleProducts().where((p) => p.popular).toList();

    return Scaffold(
      // CORRECCIÓN: Fondo pier-arena (#F5F1ED) según 
      backgroundColor: const Color(0xFFF5F1ED),
      
      // 1. APPBAR CON LOGO [cite: 30]
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.pierVerde),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Image.asset(
                AppAssets.logo,
                height: 35,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.cake, color: AppColors.pierVerde, size: 24);
                },
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Pier Repostería',
              style: TextStyle(
                color: AppColors.pierVerde,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                fontFamily: 'Playfair Display', // Tipografía Heading [cite: 17]
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pierVerde,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Ingresar', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
      
      // 2. MENÚ LATERAL (DRAWER)
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.pierVerde),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(AppAssets.logo, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pier Repostería',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Playfair Display'),
                  ),
                  Text(
                    'Menú Principal',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(context, Icons.home, 'Inicio', null),
            _buildDrawerItem(context, Icons.storefront, 'Catálogo', const PublicCatalogScreen()),
            const Divider(),
            _buildDrawerItem(context, Icons.info_outline, 'Nosotros', const AboutUsScreen()),
            _buildDrawerItem(context, Icons.help_outline, 'Preguntas Frecuentes', const FAQScreen()),
            _buildDrawerItem(context, Icons.mail_outline, 'Contacto', const ContactScreen()),
            const Divider(),
            _buildDrawerItem(context, Icons.gavel, 'Legales y Privacidad', const LegalScreen()),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.login, color: AppColors.pierDorado),
              title: const Text('Iniciar Sesión', style: TextStyle(color: AppColors.pierDorado, fontWeight: FontWeight.bold)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
            ),
          ],
        ),
      ),

      // 3. WHATSAPP FAB [cite: 60]
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF25D366), // Verde WhatsApp exacto
        child: const Icon(Icons.message, color: Colors.white),
      ),
      
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 4. HERO SECTION CON IMAGEN DE FONDO 
            _buildHeroCarousel(context),
            
            const SizedBox(height: 24),
            
            // 5. CATEGORÍAS [cite: 55]
            _buildSectionTitle('Nuestras Categorías'),
            _buildCategoriesList(context),
            
            const SizedBox(height: 24),
            
            // 6. POPULARES [cite: 57]
            _buildSectionTitle('Los más populares'),
            SizedBox(
              height: 280, // Altura ajustada para evitar overflow
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: popularProducts.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final product = popularProducts[index];
                  return SizedBox(
                    width: 180,
                    child: ProductCard(
                      product: product,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailScreen(product: product))),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 7. SUCURSALES 
            _buildSectionTitle('Visítanos'),
            _buildBranchCard(
              'Sucursal Principal', 
              'Av. Revolución 123, Centro', 
              'Lun - Sáb: 9am - 9pm' // Horario exacto documento
            ),
            _buildBranchCard(
              'Plaza Las Flores', 
              'Blvd. Central km 2, Local 4', 
              'Lun - Sáb: 9am - 9pm'
            ),
            
            const SizedBox(height: 40),
            
            // Footer de navegación rápida
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white, // Fondo blanco para separar del pier-arena
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AboutUsScreen())), child: const Text("Nosotros")),
                  TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ContactScreen())), child: const Text("Contacto")),
                  TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const FAQScreen())), child: const Text("Ayuda")),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildDrawerItem(BuildContext context, IconData icon, String title, Widget? page) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: () {
        Navigator.pop(context); 
        if (page != null) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => page));
        }
      },
    );
  }

  // CORRECCIÓN: Carrusel con Imagen de Fondo real 
  Widget _buildHeroCarousel(BuildContext context) {
    return SizedBox(
      height: 250,
      width: double.infinity,
      child: Stack(
        children: [
          // Imagen de fondo fija para todo el carrusel (o podrías cambiarla por slide)
          Positioned.fill(
            child: Image.asset(
              AppAssets.splashBackground,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(color: AppColors.pierVerdeOscuro),
            ),
          ),
          // Capa oscura para legibilidad del texto
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),

          PageView.builder(
            controller: _pageController,
            itemCount: _heroSlides.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final slide = _heroSlides[index];
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      slide['title']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Playfair Display', // [cite: 17]
                        shadows: [Shadow(color: Colors.black45, offset: Offset(0, 2), blurRadius: 4)],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      slide['subtitle']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        shadows: [Shadow(color: Colors.black45, offset: Offset(0, 1), blurRadius: 2)],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        if (index == 0) Navigator.push(context, MaterialPageRoute(builder: (context) => const PublicCatalogScreen()));
                        else if (index == 1) Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutUsScreen()));
                        else Navigator.push(context, MaterialPageRoute(builder: (context) => const ContactScreen()));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pierDorado, // 
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Text(
                        slide['button']!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Indicadores (Dots)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_heroSlides.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: _currentPage == index ? 24 : 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? AppColors.pierDorado : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.pierVerdeOscuro, // 
          fontFamily: 'Playfair Display', // [cite: 17]
        ),
      ),
    );
  }

  Widget _buildCategoriesList(BuildContext context) {
    final categories = [
      {'name': 'Pasteles', 'icon': Icons.cake},
      {'name': 'Cheesecakes', 'icon': Icons.pie_chart},
      {'name': 'Postres', 'icon': Icons.cookie},
      {'name': 'Cafetería', 'icon': Icons.coffee},
    ];
    return SizedBox(
      height: 100,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PublicCatalogScreen(initialCategory: categories[index]['name'] as String))),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: Icon(categories[index]['icon'] as IconData, color: AppColors.pierVerde),
                ),
                const SizedBox(height: 8),
                Text(categories[index]['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBranchCard(String name, String address, String hours) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.pierVerde.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.store, color: AppColors.pierVerde),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Row(children: [const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey), const SizedBox(width: 4), Expanded(child: Text(address, style: const TextStyle(color: Colors.grey, fontSize: 13)))]),
                const SizedBox(height: 4),
                Row(children: [const Icon(Icons.access_time, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(hours, style: const TextStyle(color: Colors.grey, fontSize: 13))])
              ],
            ),
          ),
        ],
      ),
    );
  }
}