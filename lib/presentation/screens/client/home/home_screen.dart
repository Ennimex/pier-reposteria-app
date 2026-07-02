// lib/presentation/screens/client/home/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/utils/config_format.dart';
import '../../../../core/utils/logger.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/product_provider.dart';
import '../../../../data/providers/navigation_provider.dart';
import '../../../../data/providers/notification_provider.dart';
import '../../../../data/models/product_model.dart';
import '../products/product_detail_screen.dart';
import '../orders/order_detail_screen.dart';
import '../../../../data/models/order_model.dart';
import '../../public/contact_screen.dart';
import '../notifications/notifications_screen.dart';

IconData _iconForCategoria(String nombre) {
  switch (nombre.toLowerCase()) {
    case 'pasteles':  return Icons.cake_outlined;
    case 'roscas':    return Icons.donut_large_outlined;
    case 'pays':      return Icons.pie_chart_outline;
    case 'postres':   return Icons.cookie_outlined;
    case 'cafetería':
    case 'cafeteria': return Icons.coffee_outlined;
    case 'bebidas':   return Icons.local_drink_outlined;
    case 'panes':     return Icons.breakfast_dining_outlined;
    default:          return Icons.fastfood_outlined;
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final ApiService _api = ApiService();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  List<Map<String, dynamic>> _productosComprados = [];
  Map<String, dynamic>? _pedidoActivo;
  List<Map<String, dynamic>> _categoriasApi = [];
  List<Map<String, dynamic>> _resenasDestacadas = [];

  // ── Promociones separadas por tipo (igual que el web) ──
  Map<String, dynamic>? _promoBanner;           // tipo == 'banner'
  List<Map<String, dynamic>> _promoRelampago = []; // tipo == 'relampago'
  List<Map<String, dynamic>> _promoTemporada = []; // tipo == 'temporada'
  List<Map<String, dynamic>> _promoDestacado = []; // tipo == 'destacado'

  Map<String, dynamic> _configContacto = {};
  Map<String, dynamic> _configHorarios = {};

  String? _lastUserEmail;

  final List<Map<String, dynamic>> _categoriasFallback = [
    {'nombre': 'Pasteles',  'icon': Icons.cake_outlined},
    {'nombre': 'Roscas',    'icon': Icons.donut_large_outlined},
    {'nombre': 'Pays',      'icon': Icons.pie_chart_outline},
    {'nombre': 'Postres',   'icon': Icons.cookie_outlined},
    {'nombre': 'Cafetería', 'icon': Icons.coffee_outlined},
  ];

  // Sin fallbacks — si no hay datos del backend no se muestra la sección

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

  @override
  void initState() {
    super.initState();
    PierLog.nav('→ HomeScreen');
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
      _cargarResenasDestacadas();
      _cargarConfiguracion();
      _cargarPromociones();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userEmail = auth.currentUser?['email']?.toString();
    if (userEmail != _lastUserEmail) {
      _lastUserEmail = userEmail;
      if (auth.isAuthenticated && userEmail != null) {
        _cargarDatosUsuario();
        context.read<NotificationProvider>().startPolling();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() { _productosComprados = []; _pedidoActivo = null; });
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
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
        PierLog.info('✅ Categorías: ${lista.length}');
        setState(() => _categoriasApi = lista);
      }
    } else {
      PierLog.error('Error categorías: ${result['message']}');
    }
  }

  Future<void> _cargarResenasDestacadas() async {
    PierLog.api('GET ${ApiConstants.resenasDestacadas}');
    final result = await _api.get(ApiConstants.resenasDestacadas);
    if (!mounted) return;
    if (result['success'] == true) {
      final lista = List<Map<String, dynamic>>.from(result['resenas'] ?? []);
      if (lista.isNotEmpty) {
        PierLog.info('✅ Reseñas destacadas: ${lista.length}');
        setState(() => _resenasDestacadas = lista);
      }
    } else {
      PierLog.error('Error reseñas: ${result['message']}');
    }
  }

  /// ✅ FIX: ahora separa por campo `tipo` igual que el web
  Future<void> _cargarPromociones() async {
    PierLog.api('GET ${ApiConstants.promocionesActivas}');
    final result = await _api.get(ApiConstants.promocionesActivas);
    if (!mounted) return;
    if (result['success'] == true) {
      final lista = List<Map<String, dynamic>>.from(
          result['promociones'] ?? []);

      Map<String, dynamic>? banner;
      final relampago = <Map<String, dynamic>>[];
      final temporada = <Map<String, dynamic>>[];
      final destacado = <Map<String, dynamic>>[];

      for (final p in lista) {
        final tipo = p['tipo']?.toString() ?? '';
        switch (tipo) {
          case 'banner':
            banner ??= p; // tomar solo el primero
            break;
          case 'relampago':
            if (p['producto_id'] != null) relampago.add(p);
            break;
          case 'temporada':
            if (p['producto_id'] != null) temporada.add(p);
            break;
          case 'destacado':
            if (p['producto_id'] != null) destacado.add(p);
            break;
        }
      }

      setState(() {
        _promoBanner   = banner;
        _promoRelampago = relampago;
        _promoTemporada = temporada;
        _promoDestacado = destacado;
      });

      PierLog.info(
          '✅ Promociones → banner:${banner != null ? 1 : 0} '
          'relámpago:${relampago.length} '
          'temporada:${temporada.length} '
          'destacado:${destacado.length}');
    } else {
      PierLog.error('Error promociones: ${result['message']}');
    }
  }

  Future<void> _cargarConfiguracion() async {
    PierLog.api('GET configuracion/contacto + horarios');
    final results = await Future.wait([
      _api.get(ApiConstants.configuracionSeccion('contacto')),
      _api.get(ApiConstants.configuracionSeccion('horarios')),
    ]);
    if (!mounted) return;
    setState(() {
      if (results[0]['success'] == true) {
        _configContacto = Map<String, dynamic>.from(results[0]['config'] ?? {});
      }
      if (results[1]['success'] == true) {
        _configHorarios = Map<String, dynamic>.from(results[1]['config'] ?? {});
      }
    });
    PierLog.info('✅ Configuración cargada');
  }

  Future<void> _cargarDatosUsuario() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;
    PierLog.info('Cargando datos usuario...');
    final results = await Future.wait([
      _api.getAuth(ApiConstants.productosComprados),
      _api.getAuth(ApiConstants.misPedidos),
    ]);
    if (!mounted) return;
    if (results[0]['success'] == true) {
      setState(() {
        _productosComprados = List<Map<String, dynamic>>.from(
            results[0]['productos'] ?? []);
      });
      PierLog.debug('Productos comprados: ${_productosComprados.length}');
    }
    if (results[1]['success'] == true) {
      final pedidos = List<Map<String, dynamic>>.from(
          results[1]['pedidos'] ?? []);
      final activo = pedidos.firstWhere(
        (p) => ['pendiente', 'en_preparacion', 'listo'].contains(p['estado']),
        orElse: () => {},
      );
      setState(() => _pedidoActivo = activo.isNotEmpty ? activo : null);
      if (_pedidoActivo != null) {
        PierLog.info(
            'Pedido activo: ${_pedidoActivo!['numero']} — ${_pedidoActivo!['estado']}');
      }
    }
    context.read<NotificationProvider>().startPolling();
  }

  String _tiempoRestante(String? fechaFinStr) {
    if (fechaFinStr == null) return '';
    try {
      final diff = DateTime.parse(fechaFinStr).difference(DateTime.now());
      if (diff.isNegative) return 'Expirada';
      if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h';
      if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
      return '${diff.inMinutes}m';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: RefreshIndicator(
        onRefresh: () async {
          PierLog.info('Refresh HomeScreen');
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
          await context.read<ProductProvider>().refrescar();
          _cargarCategorias();
          _cargarResenasDestacadas();
          _cargarConfiguracion();
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

            // ✅ NUEVO: banner de tipo 'banner'
            if (_promoBanner != null)
              SliverToBoxAdapter(child: _buildPromoBanner()),

            // Relámpago — solo si hay datos del backend
            if (_promoRelampago.isNotEmpty)
              SliverToBoxAdapter(child: _buildOfertasRelampago()),

            // Temporada — solo si hay datos del backend
            if (_promoTemporada.isNotEmpty)
              SliverToBoxAdapter(child: _buildOfertasTemporada()),

            // ✅ NUEVO: destacado — filtrado por tipo == 'destacado'
            if (_promoDestacado.isNotEmpty)
              SliverToBoxAdapter(child: _buildPromoDestacado()),

            SliverToBoxAdapter(child: _buildCategories()),

            // Destacados (productos populares) — arriba de "Pide de nuevo" para mayor visibilidad
            if (productProvider.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(
                      color: AppColors.pierVerde)),
                ),
              )
            else if (productProvider.populares.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildProductSection(
                  title: 'Destacados',
                  titleIcon: Icons.star_rounded,
                  productos: productProvider.populares,
                ),
              ),

            if (auth.isAuthenticated && _productosComprados.isNotEmpty)
              SliverToBoxAdapter(child: _buildPideDeNuevo()),

            if (productProvider.mejorCalificados.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildProductSection(
                  title: 'Mejor calificados',
                  titleIcon: Icons.star_rounded,
                  productos: productProvider.mejorCalificados,
                ),
              ),

            if (productProvider.nuevos.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildProductSection(
                  title: 'Recién llegados',
                  titleIcon: Icons.new_releases_rounded,
                  productos: productProvider.nuevos,
                ),
              ),

            if (_resenasDestacadas.isNotEmpty)
              SliverToBoxAdapter(child: _buildResenasDestacadas()),

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
    final nombre =
        auth.currentUser?['nombre']?.toString().split(' ').first ?? '';
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20, right: 20, bottom: 16,
      ),
      color: AppColors.pierArena,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.isAuthenticated && nombre.isNotEmpty
                      ? 'Hola, $nombre'
                      : 'Bienvenido',
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text('Descubre algo dulce hoy',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (auth.isAuthenticated)
            GestureDetector(
              onTap: () {
                PierLog.nav('→ NotificationsScreen');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()),
                ).then((_) => _cargarDatosUsuario());
              },
              child: Builder(builder: (context) {
                final count =
                    context.watch<NotificationProvider>().noLeidas;
                return Stack(
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
                        count > 0
                            ? Icons.notifications_rounded
                            : Icons.notifications_outlined,
                        color: AppColors.textPrimary, size: 20,
                      ),
                    ),
                    if (count > 0)
                      Positioned(
                        right: -2, top: -2,
                        child: Container(
                          width: 16, height: 16,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                          child: Center(
                            child: Text(
                              count > 9 ? '9+' : '$count',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              }),
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
        mensaje = 'Pedido #$numero en preparación';
        color = AppColors.estadoPreparacion;
        break;
      case 'listo':
        icon = Icons.check_circle_outline_rounded;
        mensaje = 'Pedido #$numero listo para recoger';
        color = AppColors.pierVerde;
        break;
      default:
        icon = Icons.hourglass_empty_rounded;
        mensaje = 'Pedido #$numero recibido, en cola';
        color = AppColors.estadoPendiente;
    }
    return GestureDetector(
      onTap: () {
        PierLog.nav('→ OrderDetailScreen');
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
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                    height: 1.3)),
          ),
          Icon(Icons.chevron_right_rounded, color: color, size: 20),
        ]),
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
            border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.2)),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3))],
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: AppColors.textSecondary.withValues(alpha: 0.5), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Busca tu pastel favorit...',
                    style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.pierVerde,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Text('Buscar',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
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
          blurRadius: 20,
          offset: const Offset(0, 8),
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
                        errorBuilder: (_, __, ___) => Container(
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
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 1)),
                          ),
                          const SizedBox(height: 8),
                          Text(slide['title']!,
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.15,
                                  letterSpacing: -0.3)),
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
                                Navigator.push(context,
                                    MaterialPageRoute(
                                        builder: (_) => const ContactScreen()));
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

  // ✅ NUEVO: Banner tipo 'banner' — mismo concepto que el web
  Widget _buildPromoBanner() {
    final p = _promoBanner!;
    final titulo = p['titulo_banner']?.toString() ?? 'Promoción especial';
    final subtitulo = p['subtitulo_banner']?.toString() ?? '';
    final descripcion = p['descripcion_banner']?.toString() ?? '';
    final codigo = p['codigo_descuento']?.toString();
    final fechaFin = p['fecha_fin']?.toString();
    final tiempo = _tiempoRestante(fechaFin);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.pierVerdeOscuro, AppColors.pierVerde],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
              color: AppColors.pierVerdeOscuro.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header badge
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Oferta activa',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
              if (tiempo.isNotEmpty) ...[
                const Spacer(),
                Row(children: [
                  const Icon(Icons.timer_outlined,
                      color: Colors.white70, size: 13),
                  const SizedBox(width: 4),
                  Text(tiempo,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500)),
                ]),
              ],
            ]),
            const SizedBox(height: 14),

            // Título
            Text(titulo,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.2)),
            if (subtitulo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitulo,
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.pierDorado,
                      fontWeight: FontWeight.w600)),
            ],
            if (descripcion.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(descripcion,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],

            const SizedBox(height: 16),

            // Código de descuento
            if (codigo != null && codigo.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.pierDorado.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.pierDorado.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.card_giftcard_rounded,
                        color: AppColors.pierDorado, size: 16),
                    const SizedBox(width: 8),
                    Text(codigo,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Botón CTA
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => context.read<NavigationProvider>().goCatalogo(),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Ver productos',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.pierVerdeOscuro)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded,
                          color: AppColors.pierVerdeOscuro, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── OFERTAS RELÁMPAGO (tipo == 'relampago') ───────────────────────
  // Solo se llama cuando _promoRelampago.isNotEmpty
  Widget _buildOfertasRelampago() {
    final fuente = _promoRelampago.take(2).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.bolt_rounded,
                  color: Colors.amber.shade700, size: 18),
            ),
            const SizedBox(width: 8),
            const Text('Ofertas Relámpago',
                style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 12),
          Row(
            children: List.generate(fuente.length, (idx) {
              final promo = fuente[idx];
              final imagenUrl = promo['producto_imagen']?.toString() ?? '';
              final porcentaje = promo['descuento_porcentaje']?.toString() ?? '';
              final tag = promo['badge_destacado']?.toString() ??
                  (porcentaje.isNotEmpty ? '$porcentaje% OFF' : 'OFERTA');
              final titulo = promo['titulo_banner']?.toString() ??
                  promo['producto_nombre']?.toString() ??
                  'Oferta especial';
              final precioOferta = promo['precio_oferta']?.toString();
              final subtitulo = promo['subtitulo_banner']?.toString() ??
                  (precioOferta != null
                      ? 'Desde \$${double.tryParse(precioOferta)?.toStringAsFixed(0) ?? ''} MXN'
                      : '');
              final tiempo = _tiempoRestante(promo['fecha_fin']?.toString());
              final gradientColor =
                  idx == 0 ? AppColors.pierVerdeOscuro : AppColors.pierDoradoOscuro;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    final productoId = promo['producto_id']?.toString();
                    if (productoId != null && productoId.isNotEmpty) {
                      final pp =
                          Provider.of<ProductProvider>(context, listen: false);
                      final producto = pp.productos.firstWhere(
                        (p) => p.id.toString() == productoId,
                        orElse: () => Product(
                            id: '', nombre: '', descripcion: '',
                            precio: 0, categoria: '', imagenUrl: ''),
                      );
                      if (producto.id.isNotEmpty) {
                        PierLog.nav('→ ProductDetailScreen desde relámpago');
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) =>
                                ProductDetailScreen(product: producto)));
                        return;
                      }
                    }
                    context.read<NavigationProvider>().goCatalogo();
                  },
                  child: Container(
                    margin: EdgeInsets.only(
                        left: idx == 0 ? 0 : 8, right: idx == 0 ? 8 : 0),
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                          color: gradientColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(fit: StackFit.expand, children: [
                        imagenUrl.isNotEmpty
                            ? Image.network(imagenUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
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
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(tag,
                                      style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                ),
                                if (tiempo.isNotEmpty) ...[
                                  const Spacer(),
                                  Row(children: [
                                    const Icon(Icons.timer_outlined,
                                        color: Colors.white70, size: 11),
                                    const SizedBox(width: 2),
                                    Text(tiempo,
                                        style: const TextStyle(
                                            fontSize: 9,
                                            color: Colors.white70)),
                                  ]),
                                ],
                              ]),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(titulo,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  if (subtitulo.isNotEmpty)
                                    Text(subtitulo,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white
                                                .withValues(alpha: 0.85))),
                                  const SizedBox(height: 2),
                                  Row(children: [
                                    const Text('Ver detalle',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 2),
                                    Icon(Icons.arrow_forward_ios_rounded,
                                        size: 9,
                                        color:
                                            Colors.white.withValues(alpha: 0.9)),
                                  ]),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }


  // ── OFERTAS DE TEMPORADA (tipo == 'temporada') ────────────────────
  // Solo se llama cuando _promoTemporada.isNotEmpty
  Widget _buildOfertasTemporada() {
    const accentColors = [
      AppColors.pierVerde, AppColors.pierDorado,
      AppColors.estadoCancelado, AppColors.pierDoradoOscuro,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 28, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAE3D0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 13, color: AppColors.estadoCancelado),
                  SizedBox(width: 4),
                  Text('Temporada',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.estadoCancelado)),
                ]),
              ),
              const SizedBox(width: 10),
              const Text('De Temporada',
                  style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
            ]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 230,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _promoTemporada.length,
              itemBuilder: (context, idx) {
                final promo = _promoTemporada[idx];
                final accent = accentColors[idx % accentColors.length];
                final imagenUrl = promo['producto_imagen']?.toString() ?? '';
                final titulo = promo['nombre_temporada']?.toString() ??
                    promo['titulo_banner']?.toString() ??
                    promo['producto_nombre']?.toString() ?? 'Temporada';
                final subtitulo = promo['subtitulo_banner']?.toString() ?? '';
                final precioBruto =
                    double.tryParse(promo['precio_chico']?.toString() ?? '0') ?? 0;
                final porcentaje = double.tryParse(
                        promo['descuento_porcentaje']?.toString() ?? '0') ??
                    0;
                final precioFinal = porcentaje > 0
                    ? (precioBruto * (1 - porcentaje / 100))
                    : (double.tryParse(
                            promo['precio_oferta']?.toString() ?? '0') ??
                        precioBruto);
                final precioStr =
                    precioFinal > 0 ? '\$${precioFinal.toStringAsFixed(0)}' : '';
                final tiempo =
                    _tiempoRestante(promo['fecha_fin']?.toString());
                return _buildTemporadaCard(
                  idx: idx,
                  imagenUrl: imagenUrl,
                  titulo: titulo,
                  subtitulo: subtitulo.isNotEmpty
                      ? subtitulo
                      : (tiempo.isNotEmpty ? 'Hasta $tiempo' : ''),
                  precio: precioStr,
                  precioOriginal:
                      porcentaje > 0 ? '\$${precioBruto.toStringAsFixed(0)}' : null,
                  accent: accent,
                  onTap: () {
                    final productoId = promo['producto_id']?.toString();
                    if (productoId != null && productoId.isNotEmpty) {
                      final pp =
                          Provider.of<ProductProvider>(context, listen: false);
                      final producto = pp.productos.firstWhere(
                        (p) => p.id.toString() == productoId,
                        orElse: () => Product(
                            id: '', nombre: '', descripcion: '',
                            precio: 0, categoria: '', imagenUrl: ''),
                      );
                      if (producto.id.isNotEmpty) {
                        PierLog.nav('→ ProductDetailScreen desde temporada');
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    ProductDetailScreen(product: producto)));
                        return;
                      }
                    }
                    context.read<NavigationProvider>().goCatalogo();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemporadaCard({
    required int idx,
    required String imagenUrl,
    required String titulo,
    required String subtitulo,
    required String precio,
    String? precioOriginal,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 155,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          )],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 115,
                width: double.infinity,
                child: Stack(fit: StackFit.expand, children: [
                  imagenUrl.isNotEmpty
                      ? Image.network(imagenUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: accent.withValues(alpha: 0.12),
                            child: Icon(Icons.cake_outlined,
                                color: accent, size: 40),
                          ))
                      : Container(
                          color: accent.withValues(alpha: 0.12),
                          child: Icon(Icons.cake_outlined,
                              color: accent, size: 40),
                        ),
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              size: 8, color: Colors.white),
                          SizedBox(width: 3),
                          Text('Temporada',
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titulo,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  height: 1.2),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          if (subtitulo.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(subtitulo,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (precio.isNotEmpty)
                                Text(precio,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: accent)),
                              // ✅ Precio tachado si hay descuento
                              if (precioOriginal != null)
                                Text(precioOriginal,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                                        decoration:
                                            TextDecoration.lineThrough)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Ver',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: accent)),
                                const SizedBox(width: 2),
                                Icon(Icons.arrow_forward_ios_rounded,
                                    size: 8, color: accent),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ NUEVO: Productos Destacados (tipo == 'destacado')
  Widget _buildPromoDestacado() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.pierDorado, AppColors.pierDoradoOscuro]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('Productos Destacados',
                style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 4),
          Text('Seleccionados especialmente para ti',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          ...(_promoDestacado.map((promo) {
            final imagenUrl = promo['producto_imagen']?.toString() ?? '';
            final nombre =
                promo['producto_nombre']?.toString() ?? 'Producto';
            final badge = promo['badge_destacado']?.toString() ?? 'Destacado';
            final precioOferta =
                double.tryParse(promo['precio_oferta']?.toString() ?? '0') ??
                    0;
            final precioOriginal =
                double.tryParse(promo['precio_original']?.toString() ??
                        promo['precio_chico']?.toString() ?? '0') ??
                    0;
            final porcentaje =
                double.tryParse(promo['descuento_porcentaje']?.toString() ?? '0') ??
                    0;
            final fechaFin = promo['fecha_fin']?.toString();
            final tiempo = _tiempoRestante(fechaFin);

            return GestureDetector(
              onTap: () {
                final productoId = promo['producto_id']?.toString();
                if (productoId != null && productoId.isNotEmpty) {
                  final pp =
                      Provider.of<ProductProvider>(context, listen: false);
                  final producto = pp.productos.firstWhere(
                    (p) => p.id.toString() == productoId,
                    orElse: () => Product(
                        id: '', nombre: '', descripcion: '',
                        precio: 0, categoria: '', imagenUrl: ''),
                  );
                  if (producto.id.isNotEmpty) {
                    PierLog.nav('→ ProductDetailScreen desde destacado');
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) =>
                            ProductDetailScreen(product: producto)));
                    return;
                  }
                }
                context.read<NavigationProvider>().goCatalogo();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                      color: AppColors.pierDorado.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: [
                      // Imagen
                      SizedBox(
                        width: 110,
                        child: Stack(fit: StackFit.expand, children: [
                          imagenUrl.isNotEmpty
                              ? Image.network(imagenUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: AppColors.pierArena,
                                    child: const Icon(Icons.cake_outlined,
                                        color: AppColors.pierDorado, size: 36),
                                  ))
                              : Container(
                                  color: AppColors.pierArena,
                                  child: const Icon(Icons.cake_outlined,
                                      color: AppColors.pierDorado, size: 36),
                                ),
                          // Badge dorado
                          Positioned(
                            top: 8, left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [
                                      AppColors.pierDorado,
                                      AppColors.pierDoradoOscuro
                                    ]),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome_rounded,
                                      size: 8, color: Colors.white),
                                  const SizedBox(width: 3),
                                  Text(badge,
                                      style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                          // Badge descuento
                          if (porcentaje > 0)
                            Positioned(
                              bottom: 8, right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade500,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                    '-${porcentaje.round()}%',
                                    style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                              ),
                            ),
                        ]),
                      ),
                      // Info
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(nombre,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.textPrimary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Precio final
                                      Text(
                                        '\$${precioOferta > 0 ? precioOferta.toStringAsFixed(0) : precioOriginal.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.pierDorado),
                                      ),
                                      // Precio tachado
                                      if (precioOferta > 0 &&
                                          precioOriginal > 0)
                                        Text(
                                          '\$${precioOriginal.toStringAsFixed(0)}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary.withValues(alpha: 0.5),
                                              decoration:
                                                  TextDecoration.lineThrough),
                                        ),
                                    ],
                                  ),
                                  // Tiempo restante
                                  if (tiempo.isNotEmpty)
                                    Row(children: [
                                      const Icon(Icons.timer_outlined,
                                          size: 12,
                                          color: AppColors.pierDorado),
                                      const SizedBox(width: 3),
                                      Text(tiempo,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.pierDorado,
                                              fontWeight: FontWeight.w600)),
                                    ]),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          })),
        ],
      ),
    );
  }

  // ── CATEGORÍAS ────────────────────────────────────────────────────
  Widget _buildCategories() {
    final cats = _categoriasApi.isNotEmpty ? _categoriasApi : _categoriasFallback;
    final display = cats.take(5).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Categorías',
              style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: display.map((cat) {
              final nombre = (cat['nombre'] ?? cat['name'] ?? '').toString();
              final IconData icon = cat['icon'] != null
                  ? cat['icon'] as IconData
                  : _iconForCategoria(nombre);
              return GestureDetector(
                onTap: () =>
                    context.read<NavigationProvider>().goCatalogo(),
                child: Column(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.07),
                            blurRadius: 10,
                            offset: const Offset(0, 4))],
                      ),
                      child: Icon(icon,
                          color: AppColors.pierVerde, size: 26),
                    ),
                    const SizedBox(height: 6),
                    Text(nombre,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── PIDE DE NUEVO ─────────────────────────────────────────────────
  Widget _buildPideDeNuevo() {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    final listaProductos = _productosComprados.map((p) {
      final precio = double.tryParse(
              p['precio_unitario']?.toString() ??
              p['precio_chico']?.toString() ?? '0') ??
          0.0;
      return provider.productos.firstWhere(
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
    }).toList();

    return _buildProductSection(
      title: 'Pide de nuevo',
      titleIcon: Icons.replay_rounded,
      productos: listaProductos,
    );
  }

  // ── RESEÑAS DESTACADAS ────────────────────────────────────────────
  Widget _buildResenasDestacadas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.star_rounded, color: AppColors.pierDorado, size: 20),
            SizedBox(width: 6),
            Text('Lo que dicen nuestros clientes',
                style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 14),
          ..._resenasDestacadas.map((r) {
            final nombre =
                '${r['autor_nombre'] ?? ''} ${r['autor_apellido'] ?? ''}'.trim();
            final iniciales = nombre.length >= 2
                ? nombre.substring(0, 2).toUpperCase()
                : nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
            final rating =
                double.tryParse(r['rating']?.toString() ?? '5') ?? 5.0;
            final comentario = r['comentario']?.toString() ?? '';
            final producto = r['producto_nombre']?.toString() ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          AppColors.pierDorado.withValues(alpha: 0.15),
                      child: Text(iniciales,
                          style: const TextStyle(
                              color: AppColors.pierDoradoOscuro,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nombre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if (producto.isNotEmpty)
                            Text(producto,
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Row(
                        children: List.generate(
                            5,
                            (i) => Icon(
                                  i < rating.floor()
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: Colors.amber,
                                  size: 14))),
                  ]),
                  const SizedBox(height: 10),
                  Text(comentario,
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── SUCURSAL ──────────────────────────────────────────────────────
  Widget _buildSucursal() {
    final direccion = formatearDireccion(_configContacto['direccion']);
    final horario = formatearHorario(_configHorarios);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Encuéntranos',
              style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ContactScreen())),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.pierVerdeOscuro,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                    color: AppColors.pierVerdeOscuro.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6))],
              ),
              child: Column(
                children: [
                  Row(children: [
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
                          const Text('Sucursal Principal',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                          const SizedBox(height: 3),
                          Text(direccion,
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
                  ]),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Divider(
                        color: Colors.white.withValues(alpha: 0.15),
                        height: 1),
                  ),
                  Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.access_time_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Horario',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                          const SizedBox(height: 3),
                          Text(horario,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SECCIÓN DE PRODUCTOS ──────────────────────────────────────────
  Widget _buildProductSection({
    required String title,
    IconData? titleIcon,
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
                Row(
                  children: [
                    if (titleIcon != null) ...[
                      Icon(titleIcon, color: AppColors.pierVerde, size: 20),
                      const SizedBox(width: 6),
                    ],
                    Text(title,
                        style: const TextStyle(
                            fontFamily: 'Playfair Display',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                  ],
                ),
                GestureDetector(
                  onTap: () =>
                      context.read<NavigationProvider>().goCatalogo(),
                  child: const Text('Ver más',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.pierVerde,
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
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final p = productos[i];
                return GestureDetector(
                  onTap: () {
                    PierLog.nav('→ ProductDetailScreen: ${p.nombre}');
                    Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(product: p)));
                  },
                  child: Container(
                    width: 165,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 16,
                          offset: const Offset(0, 6))],
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
                                    errorBuilder: (_, __, ___) => Container(
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
                                          color: Colors.black
                                              .withValues(alpha: 0.15),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.pierVerde
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
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
                                              color: AppColors.textSecondary,
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
                                          ? p.rating.toStringAsFixed(1)
                                          : '5.0',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    if (p.totalResenas > 0) ...[
                                      const SizedBox(width: 3),
                                      Text('(${p.totalResenas})',
                                          style: TextStyle(
                                              fontSize: 9,
                                              color: AppColors.textSecondary.withValues(alpha: 0.5))),
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
                  fontFamily: 'Playfair Display',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
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
                      blurRadius: 10,
                      offset: const Offset(0, 4))],
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
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary)),
                          Text(f['desc'] as String,
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.textSecondary)),
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