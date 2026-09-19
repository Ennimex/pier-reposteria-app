// lib/ui/favorites/widgets/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/skeletons.dart';
import 'package:pier_pasteleria/data/repositories/productos_repository.dart';
import 'package:pier_pasteleria/data/repositories/favoritos_repository.dart';
import 'package:pier_pasteleria/data/services/demanda_service.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/product_provider.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/auth/widgets/login_screen.dart';
import 'package:pier_pasteleria/ui/products/widgets/product_detail_screen.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

// Icono de fallback según nombre de categoría
IconData _iconForCategoria(String nombre) {
  switch (nombre.toLowerCase()) {
    case 'pasteles': return LucideIcons.cake;
    case 'roscas': return LucideIcons.donut;
    case 'pays': return LucideIcons.chartPie;
    case 'postres': return LucideIcons.cookie;
    case 'cafetería':
    case 'cafeteria': return LucideIcons.coffee;
    case 'bebidas': return LucideIcons.cupSoda;
    case 'panes': return LucideIcons.croissant;
    default: return LucideIcons.sandwich;
  }
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _productosRepo = ProductosRepository();
  final _favoritosRepo = FavoritosRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Product> _favoritos = [];
  String _searchQuery = '';
  bool _isLoading = true;

  // ✅ FIX: categorías cargadas del backend en vez de hardcodeadas
  List<Map<String, dynamic>> _categoriasApi = [];

  // Fallback si el API no responde
  final List<Map<String, dynamic>> _categoriasFallback = [
    {'nombre': 'Pasteles', 'icon': LucideIcons.cake},
    {'nombre': 'Roscas',   'icon': LucideIcons.donut},
    {'nombre': 'Pays',     'icon': LucideIcons.chartPie},
    {'nombre': 'Cafetería', 'icon': LucideIcons.coffee},
  ];

  List<Product> get _filtered {
    if (_searchQuery.isEmpty) return _favoritos;
    final q = _searchQuery.toLowerCase();
    return _favoritos.where((p) =>
        p.nombre.toLowerCase().contains(q) ||
        p.categoria.toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    _cargarFavoritos();
    _cargarCategorias();
    // Asegura que promociones estén disponibles para mostrar precios con descuento.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProductProvider>().cargarProductos();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    final result = await _productosRepo.categorias();
    if (!mounted) return;
    if (result['success'] == true) {
      final lista = List<Map<String, dynamic>>.from(
          result['categorias'] ?? result['data'] ?? []);
      if (lista.isNotEmpty) {
        setState(() => _categoriasApi = lista);
      }
    }
  }

  Future<void> _cargarFavoritos() async {
    setState(() => _isLoading = true);
    final result = await _favoritosRepo.listar();
    if (!mounted) return;
    if (result['success'] == true) {
      final data = result['favoritos'] ?? result['data'] ?? [];
      setState(() {
        _favoritos = (data as List).map((json) {
          final map = Map<String, dynamic>.from(json as Map<String, dynamic>);
          map['activo'] = true;
          return Product.fromJson(map);
        }).toList();
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _quitarFavorito(Product product) async {
    setState(() => _favoritos.remove(product));
    final result = await _favoritosRepo.quitar(product.id);
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() => _favoritos.add(product));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error al quitar de favoritos'),
            backgroundColor: Colors.red),
      );
    }
  }

  /// "Avísame": registra el interés en un producto agotado (demanda no
  /// atendida) y lo confirma. Espejo del botón Avísame de la web.
  void _avisarme(Product p) {
    DemandaService.registrarClicAgotado(p.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(LucideIcons.bellRing, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  'Anotamos tu interés en "${p.nombre}". Te avisaremos cuando vuelva.')),
        ]),
        backgroundColor: AppColors.pierDoradoOscuro,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
  }

  void _addToCart(Product p) {
    // Agotado: el botón es "Avísame" (registra interés)
    if (p.agotado) {
      _avisarme(p);
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    final cart = Provider.of<CartProvider>(context, listen: false);
    cart.addItem(p);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${p.nombre} agregado al carrito'),
        backgroundColor: AppColors.pierVerde,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final filtered = _filtered;
    final prov = context.watch<ProductProvider>();

    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        child: _isLoading
            ? GridView.count(
                padding: const EdgeInsets.fromLTRB(16, 80, 16, 40),
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                children: List.generate(
                    4, (_) => const ProductSkeletonCard()),
              )
            : CustomScrollView(
                slivers: [
                  // ── HEADER ──────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2))
                                ],
                              ),
                              child: const Icon(LucideIcons.chevronLeft,
                                  size: 16, color: AppColors.textPrimary),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text('Mis Favoritos',
                                style: TextStyle(
                                    fontFamily: 'Playfair Display',
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── BARRA DE BÚSQUEDA ────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 3))
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'Buscar en favoritos...',
                            hintStyle: TextStyle(
                                color: Colors.grey[400], fontSize: 14),
                            prefixIcon: Icon(LucideIcons.search,
                                color: AppColors.pierVerde, size: 22),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(LucideIcons.x,
                                        color: Colors.grey, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    })
                                : null,
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── CONTADOR ────────────────────────────────────
                  if (_favoritos.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                        child: Row(children: [
                          Icon(Icons.favorite,
                              size: 13, color: AppColors.pierVerde),
                          const SizedBox(width: 6),
                          Text(
                            _searchQuery.isEmpty
                                ? '${_favoritos.length} producto${_favoritos.length == 1 ? '' : 's'} guardado${_favoritos.length == 1 ? '' : 's'}'
                                : '${filtered.length} resultado${filtered.length == 1 ? '' : 's'}',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500),
                          ),
                        ]),
                      ),
                    ),

                  // ── GRID ────────────────────────────────────────
                  if (_favoritos.isEmpty)
                    SliverFillRemaining(child: _buildEmptyState())
                  else if (filtered.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.searchX,
                                size: 56, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('Sin resultados para "$_searchQuery"',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 15)),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildCard(filtered[index], prov)
                              .animate()
                              .fadeIn(
                                duration: 350.ms,
                                delay: (40 * (index % 6)).ms,
                                curve: Curves.easeOut,
                              )
                              .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
                          childCount: filtered.length,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  // ── CARD ──────────────────────────────────────────────────────────
  Widget _buildCard(Product p, ProductProvider prov) {
    final tienePromo = prov.tieneDescuento(p.id);
    final precioFinal = prov.precioConDescuento(p.id, p.precio);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)),
      ).then((_) => _cargarFavoritos()),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 58,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                    child: Hero(
                      tag: 'producto-img-${p.id}',
                      child: Image.network(
                        p.imagenUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: AppColors.pierArena,
                          child: Icon(LucideIcons.cake,
                              color: AppColors.pierVerde, size: 36),
                        ),
                      ),
                    ),
                  ),
                  if (p.agotado)
                    Positioned(
                      top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.ban,
                                color: Colors.white, size: 9),
                            SizedBox(width: 3),
                            Text('Agotado',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.2)),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    top: 10, right: 10,
                    child: GestureDetector(
                      onTap: () => _quitarFavorito(p),
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 6)
                          ],
                        ),
                        child: const Icon(Icons.favorite_rounded,
                            color: Colors.red, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 42,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.pierVerde.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(p.categoria,
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.pierVerde,
                              fontWeight: FontWeight.w600)),
                    ),
                    Text(p.nombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Flexible(
                                child: Text(
                                  '\$${precioFinal.toStringAsFixed(0)}',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: tienePromo
                                          ? Colors.red.shade600
                                          : AppColors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (tienePromo) ...[
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    '\$${p.precio.toStringAsFixed(0)}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.5),
                                        decoration:
                                            TextDecoration.lineThrough),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _addToCart(p),
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: p.agotado
                                  ? AppColors.pierDorado
                                  : AppColors.pierVerde,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                                p.agotado
                                    ? LucideIcons.bellRing
                                    : LucideIcons.plus,
                                color: Colors.white, size: 22),
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
    );
  }

  // ── EMPTY STATE ───────────────────────────────────────────────────
  Widget _buildEmptyState() {
    // ✅ FIX: usar categorías del backend, fallback si no hay
    final cats = _categoriasApi.isNotEmpty
        ? _categoriasApi.take(4).toList()
        : _categoriasFallback;

    return Column(
      children: [
        const Spacer(),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                color: AppColors.pierVerde.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                color: AppColors.pierVerde.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.favorite_rounded,
                  size: 34,
                  color: AppColors.pierVerde.withValues(alpha: 0.5)),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Text('Sin favoritos aún',
            style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Explora nuestro menú y guarda tus postres preferidos para pedirlos después.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: Colors.grey[500], height: 1.5),
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                try {
                  context.read<NavigationProvider>().goCatalogo();
                } catch (_) {}
              },
              icon: const Icon(LucideIcons.utensilsCrossed,
                  color: Colors.white, size: 18),
              label: const Text('Ver Menú',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pierVerde,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ),
        const Spacer(),

        // ── EXPLORA POR CATEGORÍA ──────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, -4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Explora por categoría',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: cats.map((cat) {
                  final nombre =
                      (cat['nombre'] ?? cat['name'] ?? '').toString();
                  final IconData icon = cat['icon'] != null
                      ? cat['icon'] as IconData
                      : _iconForCategoria(nombre);

                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      try {
                        context.read<NavigationProvider>().goCatalogo();
                      } catch (_) {}
                    },
                    child: Column(children: [
                      Container(
                        width: 62, height: 62,
                        decoration: BoxDecoration(
                          color: AppColors.pierArena,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: Icon(icon,
                            color: AppColors.pierVerde, size: 26),
                      ),
                      const SizedBox(height: 6),
                      Text(nombre,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500)),
                    ]),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}