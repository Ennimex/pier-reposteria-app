// lib/presentation/screens/client/home/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/product_provider.dart';
import '../../../../data/providers/navigation_provider.dart';
import '../../../../data/models/product_model.dart';
import '../products/product_detail_screen.dart';
import '../orders/order_detail_screen.dart';
import '../../../../data/models/order_model.dart';
import '../../public/contact_screen.dart';
import '../notifications/notifications_screen.dart';

// Icono de fallback según nombre de categoría
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ApiService _api = ApiService();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  // ── DATOS DINÁMICOS ──────────────────────────────────────────────
  List<Map<String, dynamic>> _productosComprados = [];
  Map<String, dynamic>? _pedidoActivo;
  int _notificacionesNoLeidas = 0;
  List<Map<String, dynamic>> _promociones = [];
  List<Map<String, dynamic>> _categoriasApi = []; // ← categorías del backend

  // Fallback si el API no responde
  final List<Map<String, dynamic>> _categoriasFallback = [
    {'nombre': 'Pasteles',  'icon': Icons.cake_outlined},
    {'nombre': 'Roscas',   'icon': Icons.donut_large_outlined},
    {'nombre': 'Pays',     'icon': Icons.pie_chart_outline},
    {'nombre': 'Postres',  'icon': Icons.cookie_outlined},
    {'nombre': 'Cafetería','icon': Icons.coffee_outlined},
  ];

  final List<Map<String, String>> _heroSlides = [
    {
      'tag': 'ARTESANAL',
      'title': 'Tradición en cada\nRebanada',
      'subtitle': 'Nuevos sabores de temporada disponibles',
      'cta': 'Ver Catálogo',
      'route': 'catalog',
      'image': 'https://images.unsplash.com/photo-1464349095431-e9a21285b5f3?w=600&fit=crop',
    },
    {
      'tag': 'PERSONALIZADOS',
      'title': 'Pasteles\nde Autor',
      'subtitle': 'Diseñados para tu momento especial',
      'cta': 'Contáctanos',
      'route': 'contact',
      'image': 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=600&fit=crop',
    },
    {
      'tag': 'PREMIUM',
      'title': 'Cafetería\nArtesanal',
      'subtitle': 'Bebidas especiales para acompañar',
      'cta': 'Descubrir',
      'route': 'catalog',
      'image': 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=600&fit=crop',
    },
  ];

  final List<Map<String, dynamic>> _promos = [
    {
      'tag': '🎂 OFERTA',
      'title': '2x1 Postres',
      'subtitle': 'Solo hoy martes',
      'image': 'https://images.unsplash.com/photo-1551404973-761c83cd8339?w=300&fit=crop',
      'gradient': [const Color(0xFF4A5A2B), AppColors.pierVerde],
    },
    {
      'tag': '☕ COMBO',
      'title': 'Combo Café',
      'subtitle': 'Desde \$85 MXN',
      'image': 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=300&fit=crop',
      'gradient': [AppColors.pierDoradoOscuro, const Color(0xFFD4A574)],
    },
  ];

  final Map<String, String> _sucursal = {
    'nombre': 'Sucursal Principal',
    'direccion': 'Calle Allende, Col. Tahuizán • Abierto hasta 9:00 PM',
  };

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % _heroSlides.length;
      setState(() => _currentPage = next);
      if (_pageController.hasClients) {
        _pageController.animateToPage(next,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().cargarProductos();
      _cargarCategorias();
      _cargarPromociones();
      _cargarDatosUsuario();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    final result = await _api.get('/categorias');
    if (!mounted) return;
    if (result['success'] == true) {
      final lista = List<Map<String, dynamic>>.from(
          result['categorias'] ?? result['data'] ?? []);
      if (lista.isNotEmpty) {
        setState(() => _categoriasApi = lista);
      }
    }
  }

  Future<void> _cargarPromociones() async {
    final result = await _api.get('/promociones/activas');
    if (!mounted) return;
    if (result['success'] == true) {
      final lista = List<Map<String, dynamic>>.from(
          result['promociones'] ?? []);
      if (lista.isNotEmpty) {
        setState(() => _promociones = lista);
      }
    }
  }

  Future<void> _cargarDatosUsuario() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;

    final results = await Future.wait([
      _api.getAuth('/pedidos/productos-comprados'),
      _api.getAuth(ApiConstants.misPedidos),
      _api.getAuth(ApiConstants.notificaciones),
    ]);

    if (!mounted) return;

    if (results[0]['success'] == true) {
      setState(() {
        _productosComprados = List<Map<String, dynamic>>.from(
            results[0]['productos'] ?? []);
      });
    }

    if (results[1]['success'] == true) {
      final pedidos = List<Map<String, dynamic>>.from(
          results[1]['pedidos'] ?? []);
      final activo = pedidos.firstWhere(
        (p) => ['pendiente', 'en_preparacion', 'listo'].contains(p['estado']),
        orElse: () => {},
      );
      setState(() => _pedidoActivo = activo.isNotEmpty ? activo : null);
    }

    if (results[2]['success'] == true) {
      setState(() {
        _notificacionesNoLeidas =
            int.tryParse(results[2]['no_leidas']?.toString() ?? '0') ?? 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      body: RefreshIndicator(
        onRefresh: () async {
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
          await context.read<ProductProvider>().refrescar();
          _cargarCategorias();
          _cargarPromociones();
          await _cargarDatosUsuario();
        },
        color: AppColors.pierVerde,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(auth)),

            if (_pedidoActivo != null)
              SliverToBoxAdapter(child: _buildBannerPedidoActivo()),

            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildHeroCarousel()),
            SliverToBoxAdapter(child: _buildPromos()),
            SliverToBoxAdapter(child: _buildCategories()),

            if (auth.isAuthenticated && _productosComprados.isNotEmpty)
              SliverToBoxAdapter(child: _buildPideDeNuevo()),

            if (productProvider.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.pierVerde)),
                ),
              )
            else if (productProvider.populares.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildProductSection(
                  title: 'Algunos de nuestros productos',
                  productos: productProvider.populares,
                ),
              ),

            // ── MEJOR CALIFICADOS ──────────────────────────────
            if (productProvider.mejorCalificados.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildProductSection(
                  title: 'Mejor calificados ⭐',
                  productos: productProvider.mejorCalificados,
                ),
              ),

            // ── PRODUCTOS NUEVOS ────────────────────────────────
            if (productProvider.nuevos.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildProductSection(
                  title: 'Recién llegados 🆕',
                  productos: productProvider.nuevos,
                ),
              ),

            SliverToBoxAdapter(child: _buildSucursal()),
            SliverToBoxAdapter(child: _buildWhyUs()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────
  Widget _buildHeader(AuthProvider auth) {
    final nombre = auth.currentUser?['nombre']?.toString().split(' ').first ?? '';
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20, right: 20, bottom: 16,
      ),
      color: const Color(0xFFF5F2ED),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.isAuthenticated && nombre.isNotEmpty
                      ? '¡Hola, $nombre! 👋'
                      : '¡Bienvenido! 👋',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text('Descubre algo dulce hoy',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              ],
            ),
          ),
          if (auth.isAuthenticated)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ).then((_) => _cargarDatosUsuario()),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2))],
                      ),
                      child: Icon(
                        _notificacionesNoLeidas > 0
                            ? Icons.notifications_rounded
                            : Icons.notifications_outlined,
                        color: AppColors.textPrimary, size: 20,
                      ),
                    ),
                    if (_notificacionesNoLeidas > 0)
                      Positioned(
                        right: -2, top: -2,
                        child: Container(
                          width: 16, height: 16,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                          child: Center(
                            child: Text(
                              _notificacionesNoLeidas > 9
                                  ? '9+' : '$_notificacionesNoLeidas',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.pierVerde, AppColors.pierVerdeOscuro],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [BoxShadow(
                color: AppColors.pierVerde.withValues(alpha: 0.3),
                blurRadius: 10, offset: const Offset(0, 4),
              )],
            ),
            child: Center(
              child: auth.isAuthenticated && nombre.isNotEmpty
                  ? Text(nombre[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.bold))
                  : const Icon(Icons.person_rounded,
                      color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  // ── BANNER PEDIDO ACTIVO ──────────────────────────────────────────
  Widget _buildBannerPedidoActivo() {
    final estado = _pedidoActivo!['estado']?.toString() ?? 'pendiente';
    final numero = _pedidoActivo!['numero']?.toString() ?? '';
    IconData icon;
    String mensaje;
    Color color;
    switch (estado) {
      case 'en_preparacion':
        icon = Icons.blender_outlined;
        mensaje = 'Tu pedido #$numero está en preparación 👨‍🍳';
        color = Colors.blue.shade600;
        break;
      case 'listo':
        icon = Icons.check_circle_outline_rounded;
        mensaje = '¡Tu pedido #$numero está listo! Pasa a recogerlo 🎉';
        color = AppColors.pierVerde;
        break;
      default:
        icon = Icons.hourglass_empty_rounded;
        mensaje = 'Tu pedido #$numero fue recibido y está en cola ⏳';
        color = Colors.orange.shade600;
    }
    return GestureDetector(
      onTap: () {
        final order = Order.fromJson(_pedidoActivo!);
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)));
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(mensaje,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: color, height: 1.3)),
          ),
          Icon(Icons.chevron_right_rounded, color: color, size: 20),
        ]),
      ),
    );
  }

  // ── PIDE DE NUEVO ─────────────────────────────────────────────────
  Widget _buildPideDeNuevo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Pide de nuevo',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary)),
                GestureDetector(
                  onTap: () => context.read<NavigationProvider>().goCatalogo(),
                  child: const Text('Ver todo',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.pierVerde,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 310,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _productosComprados.length,
              separatorBuilder: (_, i) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final p = _productosComprados[i];
                final precio = double.tryParse(
                    p['precio_unitario']?.toString() ??
                    p['precio_chico']?.toString() ?? '0') ?? 0.0;
                final provider = Provider.of<ProductProvider>(context, listen: false);
                final producto = provider.productos.firstWhere(
                  (prod) => prod.id.toString() == p['id']?.toString(),
                  orElse: () => Product(
                    id: p['id']?.toString() ?? '',
                    nombre: p['nombre'] ?? '',
                    descripcion: '',
                    precio: precio,
                    categoria: p['categoria'] ?? '',
                    imagenUrl: p['imagen_url'] ?? '',
                  ),
                );
                return GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: producto))),
                  child: Container(
                    width: 165,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 55,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(p['imagen_url'] ?? '',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, e, __) => Container(
                                      color: AppColors.pierArena,
                                      child: const Icon(Icons.cake_outlined,
                                          color: AppColors.pierVerde, size: 40),
                                    )),
                                Positioned(
                                  bottom: 0, left: 0, right: 0, height: 70,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.6),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 10, left: 10,
                                  child: Text('\$${precio.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          shadows: [Shadow(
                                              color: Colors.black38,
                                              blurRadius: 4)])),
                                ),
                                Positioned(
                                  top: 8, left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.pierVerdeOscuro,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.replay_rounded,
                                            color: Colors.white, size: 9),
                                        SizedBox(width: 3),
                                        Text('DE NUEVO',
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
                                  bottom: 8, right: 8,
                                  child: Container(
                                    width: 30, height: 30,
                                    decoration: BoxDecoration(
                                      color: AppColors.pierVerde,
                                      borderRadius: BorderRadius.circular(9),
                                      boxShadow: [BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 6)],
                                    ),
                                    child: const Icon(Icons.add_rounded,
                                        color: Colors.white, size: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 45,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.pierVerde.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(p['categoria'] ?? '',
                                            style: const TextStyle(
                                                fontSize: 9,
                                                color: AppColors.pierVerde,
                                                fontWeight: FontWeight.w700)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(p['nombre'] ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: AppColors.textPrimary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                  Row(children: [
                                    const Icon(Icons.replay_rounded,
                                        color: AppColors.pierVerde, size: 11),
                                    const SizedBox(width: 3),
                                    Text('Pedido anteriormente',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[500],
                                            fontWeight: FontWeight.w500)),
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
      ),
    );
  }

  // ── BUSCADOR ──────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: GestureDetector(
        onTap: () => context.read<NavigationProvider>().goCatalogo(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Busca tu pastel favorit...',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.pierVerde,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Text('Buscar',
                    style: TextStyle(
                        color: Colors.white, fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── HERO CARRUSEL ─────────────────────────────────────────────────
  Widget _buildHeroCarousel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 20, offset: const Offset(0, 8),
        )],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _heroSlides.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, i) {
                final slide = _heroSlides[i];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(slide['image']!, fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.pierVerdeOscuro,
                          child: const Icon(Icons.cake_outlined,
                              color: Colors.white, size: 60),
                        )),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.pierDorado,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(slide['tag']!,
                                style: const TextStyle(
                                    fontSize: 9, fontWeight: FontWeight.w800,
                                    color: Colors.white, letterSpacing: 1)),
                          ),
                          const SizedBox(height: 8),
                          Text(slide['title']!,
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.15, letterSpacing: -0.3)),
                          const SizedBox(height: 5),
                          Text(slide['subtitle']!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.85))),
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: () {
                              if (slide['route'] == 'catalog') {
                                context.read<NavigationProvider>().goCatalogo();
                              } else {
                                Navigator.push(context, MaterialPageRoute(
                                    builder: (context) => const ContactScreen()));
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.pierVerde,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(slide['cta']!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            Positioned(
              bottom: 12, right: 16,
              child: Row(
                children: List.generate(_heroSlides.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(left: 4),
                    width: _currentPage == i ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
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

  // ── OFERTAS RELÁMPAGO ─────────────────────────────────────────────
  Widget _buildPromos() {
    final usarBackend = _promociones.isNotEmpty;
    final count = usarBackend
        ? (_promociones.length > 2 ? 2 : _promociones.length)
        : _promos.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Text('Ofertas Relámpago',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary)),
            SizedBox(width: 6),
            Text('⚡', style: TextStyle(fontSize: 16)),
          ]),
          const SizedBox(height: 12),
          Row(
            children: List.generate(count, (idx) {
              if (usarBackend) {
                final p = _promociones[idx];
                final imagenUrl = p['producto_imagen']?.toString() ?? '';
                final tag = p['badge_destacado']?.toString() ??
                    (p['descuento_porcentaje'] != null
                        ? '🔥 ${p['descuento_porcentaje']}% OFF' : '🎂 OFERTA');
                final titulo = p['titulo_banner']?.toString() ??
                    p['nombre_temporada']?.toString() ?? 'Oferta especial';
                final subtitulo = p['subtitulo_banner']?.toString() ??
                    (p['precio_oferta'] != null
                        ? 'Desde \$${double.tryParse(p['precio_oferta'].toString())?.toStringAsFixed(0) ?? ''} MXN'
                        : '');
                final gradientColor = idx == 0
                    ? AppColors.pierVerdeOscuro : AppColors.pierDoradoOscuro;

                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(
                        left: idx == 0 ? 0 : 8, right: idx == 0 ? 8 : 0),
                    height: 130,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                          color: gradientColor.withValues(alpha: 0.3),
                          blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(fit: StackFit.expand, children: [
                        imagenUrl.isNotEmpty
                            ? Image.network(imagenUrl, fit: BoxFit.cover,
                                errorBuilder: (_, e, __) =>
                                    Container(color: gradientColor))
                            : Container(color: gradientColor),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                gradientColor.withValues(alpha: 0.5),
                                gradientColor.withValues(alpha: 0.88),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(tag,
                                    style: const TextStyle(
                                        fontSize: 9, fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(titulo,
                                      style: const TextStyle(
                                          fontSize: 15, fontWeight: FontWeight.w900,
                                          color: Colors.white),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  if (subtitulo.isNotEmpty)
                                    Text(subtitulo,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withValues(alpha: 0.85))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                );
              }

              final promo = _promos[idx];
              final gradient = promo['gradient'] as List<Color>;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                      left: idx == 0 ? 0 : 8, right: idx == 0 ? 8 : 0),
                  height: 130,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(
                        color: gradient[0].withValues(alpha: 0.3),
                        blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(fit: StackFit.expand, children: [
                      Image.network(promo['image'] as String,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, __) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: gradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight),
                            ),
                          )),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              gradient[0].withValues(alpha: 0.5),
                              gradient[0].withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(promo['tag'] as String,
                                  style: const TextStyle(
                                      fontSize: 9, fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(promo['title'] as String,
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w900,
                                        color: Colors.white)),
                                Text(promo['subtitle'] as String,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withValues(alpha: 0.85))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── CATEGORÍAS (dinámicas del API) ────────────────────────────────
  Widget _buildCategories() {
    // Usar categorías del backend; si están vacías usar fallback
    final cats = _categoriasApi.isNotEmpty ? _categoriasApi : _categoriasFallback;
    // Limitar a 5 para que quepan en la fila
    final display = cats.take(5).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Categorías',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: display.map((cat) {
              // Soportar tanto campo 'nombre' (API) como 'name' (fallback)
              final nombre = (cat['nombre'] ?? cat['name'] ?? '').toString();
              final IconData icon = cat['icon'] != null
                  ? cat['icon'] as IconData
                  : _iconForCategoria(nombre);

              return GestureDetector(
                onTap: () => context.read<NavigationProvider>().goCatalogo(),
                child: Column(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.07),
                            blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Icon(icon, color: AppColors.pierVerde, size: 26),
                    ),
                    const SizedBox(height: 6),
                    Text(nombre,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700])),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── SECCIÓN DE PRODUCTOS ──────────────────────────────────────────
  Widget _buildProductSection({
    required String title,
    required List<Product> productos,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary)),
                GestureDetector(
                  onTap: () => context.read<NavigationProvider>().goCatalogo(),
                  child: const Text('Ver más',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.pierVerde,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 310,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: productos.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final p = productos[i];
                return GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (context) =>
                          ProductDetailScreen(product: p))),
                  child: Container(
                    width: 165,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
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
                                      child: const Icon(Icons.cake_outlined,
                                          color: AppColors.pierVerde, size: 40),
                                    )),
                                Positioned(
                                  bottom: 0, left: 0, right: 0, height: 70,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.6),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 10, left: 10,
                                  child: Text('\$${p.precio.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          shadows: [Shadow(
                                              color: Colors.black38,
                                              blurRadius: 4)])),
                                ),
                                if (p.popular)
                                  Positioned(
                                    top: 8, left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.pierDorado,
                                        borderRadius: BorderRadius.circular(7),
                                        boxShadow: [BoxShadow(
                                            color: AppColors.pierDorado
                                                .withValues(alpha: 0.5),
                                            blurRadius: 6)],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.star_rounded,
                                              color: Colors.white, size: 9),
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
                                  bottom: 8, right: 8,
                                  child: Container(
                                    width: 30, height: 30,
                                    decoration: BoxDecoration(
                                      color: AppColors.pierVerde,
                                      borderRadius: BorderRadius.circular(9),
                                      boxShadow: [BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 6)],
                                    ),
                                    child: const Icon(Icons.add_rounded,
                                        color: Colors.white, size: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 45,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.pierVerde.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(p.categoria,
                                            style: const TextStyle(
                                                fontSize: 9,
                                                color: AppColors.pierVerde,
                                                fontWeight: FontWeight.w700)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(p.nombre,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: AppColors.textPrimary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 3),
                                      Text(p.descripcion,
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[500],
                                              height: 1.3),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                  Row(children: [
                                    const Icon(Icons.star_rounded,
                                        color: Colors.amber, size: 12),
                                    const SizedBox(width: 3),
                                    Text(
                                      p.rating > 0
                                          ? p.rating.toStringAsFixed(1) : '5.0',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w600),
                                    ),
                                    if (p.totalResenas > 0) ...[
                                      const SizedBox(width: 3),
                                      Text('(${p.totalResenas})',
                                          style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.grey[400])),
                                    ],
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
      ),
    );
  }

  // ── SUCURSAL ──────────────────────────────────────────────────────
  Widget _buildSucursal() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Encuéntranos',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.pierVerdeOscuro,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: AppColors.pierVerdeOscuro.withValues(alpha: 0.3),
                  blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_sucursal['nombre']!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(_sucursal['direccion']!,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_right_rounded,
                      color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── POR QUÉ ELEGIRNOS ─────────────────────────────────────────────
  Widget _buildWhyUs() {
    final features = [
      {'icon': Icons.eco_outlined,             'title': 'Natural',   'desc': 'Sin conservadores'},
      {'icon': Icons.handshake_outlined,       'title': 'Artesanal', 'desc': 'Hecho a mano'},
      {'icon': Icons.star_outline_rounded,     'title': 'Calidad',   'desc': 'Ingredientes Premium'},
      {'icon': Icons.favorite_outline_rounded, 'title': 'Amor',      'desc': 'Recetas de casa'},
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        children: [
          const Text('¿Por qué elegirnos?',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: features.map((f) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.pierVerde.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(f['icon'] as IconData,
                          color: AppColors.pierVerde, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(f['title'] as String,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary)),
                          Text(f['desc'] as String,
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}