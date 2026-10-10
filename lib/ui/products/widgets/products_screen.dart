// lib/ui/products/widgets/products_screen.dart
//
// Catálogo (MVVM, Fase 4): la vista pinta lo que expone ProductsViewModel
// (categoría, búsqueda, filtros, orden, favoritos) sobre el catálogo que
// carga ProductProvider. Aquí solo queda lo que es de la interfaz: el texto
// del buscador, cuadrícula/lista, el rebote del botón de carrito, mandar a
// iniciar sesión y los avisos (SnackBar).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/auth/widgets/login_screen.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/state/product_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/skeletons.dart';
import 'package:pier_pasteleria/ui/products/view_model/products_view_model.dart';
import 'package:pier_pasteleria/ui/products/widgets/catalogo_secciones.dart';
import 'package:pier_pasteleria/ui/products/widgets/product_detail_screen.dart';
import 'package:pier_pasteleria/ui/products/widgets/producto_catalogo_card.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:provider/provider.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, this.initialCategory, this.viewModel});

  final String? initialCategory;

  /// Para pruebas; si es null la pantalla crea el suyo.
  final ProductsViewModel? viewModel;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with TickerProviderStateMixin {
  // El State es dueño del ViewModel (lo crea, lo carga y lo libera).
  late final ProductsViewModel _vm = widget.viewModel ??
      ProductsViewModel(
        productosRepo: context.read(),
        favoritosRepo: context.read(),
        demandaRepo: context.read(),
        catalogo: () => context.read<ProductProvider>().productos,
        categoriaInicial: widget.initialCategory ?? ProductsViewModel.todas,
      );
  final TextEditingController _searchController = TextEditingController();
  bool _isGridView = true;

  final Map<String, AnimationController> _cartControllers = {};
  final Map<String, Animation<double>> _cartAnims = {};

  // Escucha de sesión: al cerrar sesión se limpian los corazones y al
  // iniciar (o cambiar de cuenta) se recargan. La pestaña vive en el
  // IndexedStack, por eso no basta con cargar en initState.
  AuthProvider? _authRef;
  String? _lastAuthEmail;
  NavigationProvider? _navRef;

  bool get _autenticado => context.read<AuthProvider>().isAuthenticated;

  @override
  void initState() {
    super.initState();
    PierLog.nav('ProductsScreen abierto — categoría inicial: ${_vm.categoria}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<ProductProvider>().cargarProductos());
      unawaited(_vm.cargar(autenticado: _autenticado));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (!identical(auth, _authRef)) {
      _authRef?.removeListener(_onAuthChanged);
      _authRef = auth;
      _lastAuthEmail = auth.currentUser?['email']?.toString();
      _authRef!.addListener(_onAuthChanged);
    }
    final nav = context.read<NavigationProvider>();
    if (!identical(nav, _navRef)) {
      _navRef?.removeListener(_onNavChanged);
      _navRef = nav;
      _navRef!.addListener(_onNavChanged);
    }
  }

  // Categoría pedida desde el home (chips de Categorías): al entrar a la
  // pestaña del catálogo con una pendiente, se cierra lo que hubiera quedado
  // abierto encima en esta pestaña (p. ej. un detalle) y se aplica igual que
  // si se hubiera tocado su chip.
  void _onNavChanged() {
    if (!mounted) return;
    if (_navRef?.selectedIndex != 1) return;
    final cat = _navRef?.consumirCategoriaPendiente();
    if (cat == null) return;
    Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    if (cat == _vm.categoria) return;
    unawaited(_vm.seleccionarCategoria(cat));
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final email = _authRef?.currentUser?['email']?.toString();
    if (email != _lastAuthEmail) {
      _lastAuthEmail = email;
      unawaited(_vm.cargarFavoritos(autenticado: _autenticado));
    }
  }

  @override
  void dispose() {
    _authRef?.removeListener(_onAuthChanged);
    _navRef?.removeListener(_onNavChanged);
    _searchController.dispose();
    for (final c in _cartControllers.values) {
      c.dispose();
    }
    _vm.dispose();
    super.dispose();
  }

  Future<void> _goToDetail(Product p) async {
    PierLog.nav('→ ProductDetailScreen: ${p.nombre}');
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ProductDetailScreen(product: p)),
    );
    if (mounted) await _vm.cargarFavoritos(autenticado: _autenticado);
  }

  void _irALogin() => Navigator.push(
      context, MaterialPageRoute<void>(builder: (_) => const LoginScreen()));

  AnimationController _getCartController(String id) {
    return _cartControllers.putIfAbsent(id, () {
      final c = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 500));
      _cartAnims[id] = Tween<double>(begin: 1, end: 1.3).animate(
          CurvedAnimation(parent: c, curve: Curves.elasticOut));
      return c;
    });
  }

  void _limpiarTodo() {
    _searchController.clear();
    _vm.limpiarTodo();
  }

  void _aviso(String texto,
      {required IconData icono, required Color color, int segundos = 2}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(icono, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(texto)),
        ]),
        backgroundColor: color,
        duration: Duration(seconds: segundos),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  void _addToCart(Product p) {
    // Agotado: el botón es "Avísame" (registra interés; sin sesión, como web)
    if (p.agotado) {
      _vm.avisarme(p);
      _aviso('Anotamos tu interés en "${p.nombre}". Te avisaremos cuando vuelva.',
          icono: LucideIcons.bellRing, color: AppColors.pierDoradoOscuro, segundos: 3);
      return;
    }
    if (!_autenticado) {
      _irALogin();
      return;
    }
    PierLog.info('🛒 Agregando al carrito desde catálogo: ${p.nombre}');
    context.read<CartProvider>().addItem(p);
    _getCartController(p.id).forward(from: 0);
    _aviso('${p.nombre} agregado',
        icono: Icons.check_circle_rounded, color: AppColors.pierVerde);
  }

  Future<void> _toggleFavorito(String id) async {
    if (!_autenticado) {
      _irALogin();
      return;
    }
    final error = await _vm.alternarFavorito(id);
    if (error == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error),
      backgroundColor: AppColors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final productProvider = context.watch<ProductProvider>();
    final cartCount = context.watch<CartProvider>().totalQuantity;

    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final products = _vm.filtrar(productProvider.productos);
        return Scaffold(
          backgroundColor: AppColors.pierArena,
          body: Column(
            children: [
              CatalogoHeader(
                viewModel: _vm,
                buscador: _searchController,
                cantidadCarrito: cartCount,
              ),
              CatalogoCategorias(viewModel: _vm),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    // No se limpia el imageCache global: recargar los datos
                    // basta y evita que TODA la app vuelva a descargar imágenes.
                    await context.read<ProductProvider>().refrescar();
                    await _vm.cargarCategorias();
                    await _vm.cargarFiltros();
                  },
                  color: AppColors.pierVerde,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _tituloYVista()),
                      if (_vm.hayFiltros)
                        SliverToBoxAdapter(child: _quitarFiltros()),
                      if (productProvider.isLoading)
                        _grid((context, i) => const ProductSkeletonCard(), 6)
                      else if (products.isEmpty)
                        SliverFillRemaining(
                            child: CatalogoVacio(onLimpiar: _limpiarTodo))
                      else
                        _grid(
                          (context, i) => _card(products[i], productProvider)
                              // Entrada escalonada: cada tarjeta entra un pelín
                              // después que la anterior (tope a 6 para no
                              // demorar listas largas), con fade + leve
                              // deslizamiento.
                              .animate()
                              .fadeIn(
                                duration: 350.ms,
                                delay: (40 * (i % 6)).ms,
                                curve: Curves.easeOut,
                              )
                              .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
                          products.length,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _card(Product p, ProductProvider promociones) => ProductoCatalogoCard(
        producto: p,
        promociones: promociones,
        enCuadricula: _isGridView,
        esFavorito: _vm.esFavorito(p.id),
        animacionCarrito: _cartAnims[p.id],
        onTap: () => _goToDetail(p),
        onToggleFavorito: () => _toggleFavorito(p.id),
        onAgregar: () => _addToCart(p),
      );

  Widget _grid(NullableIndexedWidgetBuilder builder, int cantidad) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(builder, childCount: cantidad),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _isGridView ? 2 : 1,
          childAspectRatio: _isGridView ? 0.63 : 3.2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
      ),
    );
  }

  Widget _tituloYVista() {
    return Padding(
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
                Icon(_isGridView ? LucideIcons.grid2x2 : LucideIcons.list,
                    color: AppColors.pierVerde, size: 16),
                const SizedBox(width: 5),
                Text(_isGridView ? 'Cuadrícula' : 'Lista',
                    style: TextStyle(fontSize: 12, color: AppColors.pierVerde,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quitarFiltros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: GestureDetector(
        onTap: _limpiarTodo,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.filterX, size: 14, color: Colors.red.shade400),
              const SizedBox(width: 6),
              Text('Quitar filtros',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade400, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
