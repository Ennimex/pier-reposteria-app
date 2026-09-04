// lib/ui/products/widgets/products_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/skeletons.dart';
import 'package:pier_pasteleria/data/repositories/productos_repository.dart';
import 'package:pier_pasteleria/data/repositories/favoritos_repository.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:pier_pasteleria/data/services/demanda_service.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/product_provider.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/auth/widgets/login_screen.dart';
import 'package:pier_pasteleria/ui/products/widgets/product_detail_screen.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

enum SortOption { popular, priceAsc, priceDesc, nameAsc, nameDesc }

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

class ProductsScreen extends StatefulWidget {
  final String? initialCategory;
  const ProductsScreen({super.key, this.initialCategory});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final _productosRepo = ProductosRepository();
  final _favoritosRepo = FavoritosRepository();

  SortOption _sort = SortOption.popular;
  String _category = 'Todos';
  String _searchQuery = '';
  Timer? _busquedaTimer; // registro diferido de la búsqueda (demanda no atendida)
  bool _isGridView = true;

  final Map<String, AnimationController> _cartControllers = {};
  final Map<String, Animation<double>> _cartAnims = {};
  final Set<String> _favoritos = {};

  List<String> _sabores = [];
  List<String> _tamanos = [];
  List<String> _tipos = [];
  String? _filtroSabor;
  String? _filtroTamano;
  String? _filtroTipo;
  bool _filtrosLoaded = false;

  // Opciones específicas de la categoría elegida (GET /categoria-opciones/:id).
  // Vacías = se usa el set global de /filtros como fallback.
  List<String> _saboresCategoria = [];
  List<String> _tiposCategoria = [];

  List<String> get _saboresActivos =>
      (_category != 'Todos' && _saboresCategoria.isNotEmpty)
          ? _saboresCategoria
          : _sabores;
  List<String> get _tiposActivos =>
      (_category != 'Todos' && _tiposCategoria.isNotEmpty)
          ? _tiposCategoria
          : _tipos;

  List<Map<String, dynamic>> _categoriasApi = [];
  final List<Map<String, dynamic>> _categoriasFallback = [
    {'name': 'Todos',     'icon': LucideIcons.layoutGrid},
    {'name': 'Pasteles',  'icon': LucideIcons.cake},
    {'name': 'Roscas',   'icon': LucideIcons.donut},
    {'name': 'Pays',     'icon': LucideIcons.chartPie},
    {'name': 'Postres',  'icon': LucideIcons.cookie},
    {'name': 'Cafetería','icon': LucideIcons.coffee},
  ];

  List<Map<String, dynamic>> get _categories {
    if (_categoriasApi.isEmpty) return _categoriasFallback;
    return [
      {'name': 'Todos', 'icon': LucideIcons.layoutGrid},
      ..._categoriasApi.map((c) => {
        'name': (c['nombre'] ?? c['name'] ?? '').toString(),
        'icon': _iconForCategoria((c['nombre'] ?? c['name'] ?? '').toString()),
      }),
    ];
  }

  // Escucha de sesión: al cerrar sesión se limpian los corazones y al
  // iniciar (o cambiar de cuenta) se recargan. La pestaña vive en el
  // IndexedStack, por eso no basta con cargar en initState.
  AuthProvider? _authRef;
  String? _lastAuthEmail;
  NavigationProvider? _navRef;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? 'Todos';
    PierLog.nav('ProductsScreen abierto — categoría inicial: $_category');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<ProductProvider>().cargarProductos();
      _cargarCategorias();
      _cargarFiltros();
      await _cargarFavoritosIds();
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
  // pestaña del catálogo con una pendiente, se aplica igual que si se
  // hubiera tocado su chip.
  void _onNavChanged() {
    if (!mounted) return;
    if (_navRef?.selectedIndex != 1) return;
    final cat = _navRef?.consumirCategoriaPendiente();
    if (cat == null || cat == _category) return;
    setState(() => _category = cat);
    _cargarOpcionesCategoria();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final email = _authRef?.currentUser?['email']?.toString();
    if (email != _lastAuthEmail) {
      _lastAuthEmail = email;
      _cargarFavoritosIds();
    }
  }

  @override
  void dispose() {
    _authRef?.removeListener(_onAuthChanged);
    _navRef?.removeListener(_onNavChanged);
    _busquedaTimer?.cancel();
    _searchController.dispose();
    for (final c in _cartControllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    final result = await _productosRepo.categorias();
    if (!mounted) return;
    if (result['success'] == true) {
      final lista = List<Map<String, dynamic>>.from(
          result['categorias'] ?? result['data'] ?? []);
      if (lista.isNotEmpty) {
        PierLog.info('✅ Categorías cargadas: ${lista.length}');
        setState(() => _categoriasApi = lista);
        // Con los ids ya disponibles, cargar opciones si se entró con
        // una categoría preseleccionada (p.ej. desde el home).
        if (_category != 'Todos') _cargarOpcionesCategoria();
      }
    } else {
      PierLog.error('Error al cargar categorías: ${result['message']}');
    }
  }

  /// Sabores/tipos específicos de la categoría seleccionada. Si la categoría
  /// no tiene opciones definidas (o falla la llamada), se queda el set global.
  Future<void> _cargarOpcionesCategoria() async {
    final solicitada = _category;
    if (solicitada == 'Todos') {
      setState(() {
        _saboresCategoria = [];
        _tiposCategoria = [];
      });
      return;
    }
    final match = _categoriasApi.where((c) =>
        (c['nombre'] ?? c['name'])?.toString() == solicitada);
    final id = match.isEmpty ? null : match.first['id']?.toString();
    if (id == null) return;

    final result = await _productosRepo.opcionesDeCategoria(id);
    // Si el usuario ya cambió de categoría, descartar esta respuesta.
    if (!mounted || _category != solicitada) return;

    if (result['success'] == true) {
      String nombreDe(dynamic o) =>
          (o is Map ? o['nombre'] : o)?.toString() ?? '';
      final sabores = List.from(result['sabores'] ?? [])
          .map(nombreDe).where((s) => s.isNotEmpty).toList();
      final tipos = List.from(result['tipos'] ?? [])
          .map(nombreDe).where((s) => s.isNotEmpty).toList();
      setState(() {
        _saboresCategoria = sabores;
        _tiposCategoria = tipos;
        // Filtros activos que ya no existen en esta categoría se limpian.
        if (_filtroSabor != null && !_saboresActivos.contains(_filtroSabor)) {
          _filtroSabor = null;
        }
        if (_filtroTipo != null && !_tiposActivos.contains(_filtroTipo)) {
          _filtroTipo = null;
        }
      });
      PierLog.info(
          '✅ Opciones de "$solicitada" — sabores:${sabores.length} tipos:${tipos.length}');
    }
  }

  Future<void> _cargarFiltros() async {
    final result = await _productosRepo.filtros();
    if (!mounted) return;
    if (result['success'] == true) {
      final filtros = result['filtros'] as Map<String, dynamic>? ?? {};
      setState(() {
        _sabores = List<String>.from(filtros['sabores'] ?? []);
        _tamanos = List<String>.from(filtros['tamanos'] ?? []);
        _tipos   = List<String>.from(filtros['tipos'] ?? []);
        _filtrosLoaded = true;
      });
      PierLog.info('✅ Filtros cargados — sabores:${_sabores.length} tamaños:${_tamanos.length} tipos:${_tipos.length}');
    } else {
      PierLog.error('Error al cargar filtros: ${result['message']}');
    }
  }

  Future<void> _cargarFavoritosIds() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      // Sin sesión: limpiar los corazones del usuario anterior (la
      // pestaña vive en el IndexedStack y conservaba el set viejo,
      // mostrando productos como "favoritos" siendo invitado).
      if (_favoritos.isNotEmpty) setState(() => _favoritos.clear());
      return;
    }
    final result = await _favoritosRepo.ids();
    if (!mounted) return;
    if (result['success'] == true) {
      final ids = List<String>.from(
          (result['ids'] ?? []).map((e) => e.toString()));
      setState(() {
        _favoritos.clear();
        _favoritos.addAll(ids);
      });
      PierLog.info('✅ Favoritos cargados: ${ids.length}');
    } else {
      PierLog.error('Error al cargar favoritos: ${result['message']}');
    }
  }

  Future<void> _goToDetail(Product p) async {
    PierLog.nav('→ ProductDetailScreen: ${p.nombre}');
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)),
    );
    if (mounted) await _cargarFavoritosIds();
  }

  AnimationController _getCartController(String id) {
    if (!_cartControllers.containsKey(id)) {
      final c = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 500));
      _cartControllers[id] = c;
      _cartAnims[id] = Tween<double>(begin: 1.0, end: 1.3).animate(
          CurvedAnimation(parent: c, curve: Curves.elasticOut));
    }
    return _cartControllers[id]!;
  }

  List<Product> _filtered(List<Product> all) {
    var list = _category == 'Todos'
        ? List<Product>.from(all)
        : all.where((p) => p.categoria == _category).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) =>
          p.nombre.toLowerCase().contains(q) ||
          p.descripcion.toLowerCase().contains(q) ||
          p.categoria.toLowerCase().contains(q)).toList();
    }

    if (_filtroSabor != null && _filtroSabor != 'Todos') {
      list = list.where((p) => p.sabor == _filtroSabor).toList();
    }
    if (_filtroTamano != null && _filtroTamano != 'Todos') {
      list = list.where((p) => p.tamano == _filtroTamano).toList();
    }
    if (_filtroTipo != null && _filtroTipo != 'Todos') {
      list = list.where((p) => p.tipo == _filtroTipo).toList();
    }

    switch (_sort) {
      case SortOption.priceAsc:
        list.sort((a, b) => a.precio.compareTo(b.precio));
      case SortOption.priceDesc:
        list.sort((a, b) => b.precio.compareTo(a.precio));
      case SortOption.nameAsc:
        list.sort((a, b) => a.nombre.compareTo(b.nombre));
      case SortOption.nameDesc:
        list.sort((a, b) => b.nombre.compareTo(a.nombre));
      case SortOption.popular:
        list.sort((a, b) {
          if (a.popular && !b.popular) return -1;
          if (!a.popular && b.popular) return 1;
          return 0;
        });
    }
    // Lo agotado siempre al final: se sigue viendo, pero sin estorbar (mismo
    // criterio que la web). Partición estable: conserva el orden elegido
    // dentro de cada grupo.
    return [
      ...list.where((p) => !p.agotado),
      ...list.where((p) => p.agotado),
    ];
  }

  bool get _hasFilters =>
      _searchQuery.isNotEmpty || _category != 'Todos' ||
      _filtroSabor != null || _filtroTamano != null || _filtroTipo != null;

  void _clearFilters() {
    PierLog.debug('Filtros limpiados');
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _category = 'Todos';
      _sort = SortOption.popular;
      _filtroSabor = null;
      _filtroTamano = null;
      _filtroTipo = null;
      _saboresCategoria = [];
      _tiposCategoria = [];
    });
  }

  /// "Avísame": registra el interés en un producto agotado (demanda no
  /// atendida) y lo confirma al cliente. Espejo del botón Avísame de la web.
  /// No requiere sesión.
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

  /// Registra lo que la gente busca (con cuántos resultados obtuvo) 1.2 s
  /// después de la última tecla, igual que la web. Nunca bloquea la búsqueda.
  void _programarRegistroBusqueda() {
    _busquedaTimer?.cancel();
    final termino = _searchQuery.trim();
    if (termino.length < 2) return;
    _busquedaTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted || _searchQuery.trim() != termino) return;
      final prov = Provider.of<ProductProvider>(context, listen: false);
      DemandaService.registrarBusqueda(
          termino, _filtered(prov.productos).length);
    });
  }

  void _addToCart(Product p, CartProvider cart) {
    // Agotado: el botón es "Avísame" (registra interés; sin sesión, como web)
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
    PierLog.info('🛒 Agregando al carrito desde catálogo: ${p.nombre}');
    cart.addItem(p);
    _getCartController(p.id).forward(from: 0);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('${p.nombre} agregado')),
        ]),
        backgroundColor: AppColors.pierVerde,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  Future<void> _toggleFavorito(String id) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    final yaEsFav = _favoritos.contains(id);
    setState(() {
      if (yaEsFav) { _favoritos.remove(id); } else { _favoritos.add(id); }
    });
    final result = yaEsFav
        ? await _favoritosRepo.quitar(id)
        : await _favoritosRepo.agregar(id);
    if (!mounted) return;
    if (result['success'] != true) {
      PierLog.error('Error al ${yaEsFav ? 'quitar' : 'agregar'} favorito $id');
      setState(() {
        if (yaEsFav) { _favoritos.add(id); } else { _favoritos.remove(id); }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Error al actualizar favorito'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filtros',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    if (_filtroSabor != null ||
                        _filtroTamano != null ||
                        _filtroTipo != null)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _filtroSabor = null;
                            _filtroTamano = null;
                            _filtroTipo = null;
                          });
                          setSheetState(() {});
                        },
                        child: Text('Limpiar',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.red.shade400,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_saboresActivos.isNotEmpty) ...[
                  const Text('Sabor',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _saboresActivos.where((s) => s != 'Todos').map((s) {
                      final sel = _filtroSabor == s;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _filtroSabor = sel ? null : s);
                          setSheetState(() {});
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.pierVerde : AppColors.textSecondary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? AppColors.pierVerde : AppColors.textSecondary.withValues(alpha: 0.2)),
                          ),
                          child: Text(s,
                              style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.w500, color: sel ? Colors.white : AppColors.textSecondary)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                if (_tamanos.isNotEmpty) ...[
                  const Text('Tamaño',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _tamanos.where((t) => t != 'Todos').map((t) {
                      final sel = _filtroTamano == t;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _filtroTamano = sel ? null : t);
                          setSheetState(() {});
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.pierVerde : AppColors.textSecondary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? AppColors.pierVerde : AppColors.textSecondary.withValues(alpha: 0.2)),
                          ),
                          child: Text(t,
                              style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.w500, color: sel ? Colors.white : AppColors.textSecondary)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                if (_tiposActivos.isNotEmpty) ...[
                  const Text('Tipo',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _tiposActivos.where((t) => t != 'Todos').map((t) {
                      final sel = _filtroTipo == t;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _filtroTipo = sel ? null : t);
                          setSheetState(() {});
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.pierVerde : AppColors.textSecondary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? AppColors.pierVerde : AppColors.textSecondary.withValues(alpha: 0.2)),
                          ),
                          child: Text(t,
                              style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.w500, color: sel ? Colors.white : AppColors.textSecondary)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                if (!_filtrosLoaded)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: AppColors.pierVerde),
                    ),
                  ),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pierVerde,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Aplicar filtros',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Ordenar por',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
              const SizedBox(height: 16),
              ...[
                ('Más populares',         SortOption.popular,   Icons.star_rounded),
                ('Precio: Menor a Mayor', SortOption.priceAsc,  LucideIcons.trendingUp),
                ('Precio: Mayor a Menor', SortOption.priceDesc, LucideIcons.trendingDown),
                ('Nombre: A–Z',           SortOption.nameAsc,   LucideIcons.arrowDownAZ),
                ('Nombre: Z–A',           SortOption.nameDesc,  LucideIcons.arrowDownAZ),
              ].map((t) {
                final sel = _sort == t.$2;
                return GestureDetector(
                  onTap: () {
                    setState(() => _sort = t.$2);
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.pierVerde.withValues(alpha: 0.08) : AppColors.textSecondary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: sel ? Border.all(color: AppColors.pierVerde.withValues(alpha: 0.3)) : null,
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.pierVerde : AppColors.textSecondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(t.$3, size: 18, color: sel ? Colors.white : AppColors.textSecondary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Text(t.$1,
                          style: TextStyle(fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                              color: sel ? AppColors.pierVerde : AppColors.textPrimary, fontSize: 15))),
                      if (sel) Icon(Icons.check_circle_rounded, color: AppColors.pierVerde, size: 20),
                    ]),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final productProvider = Provider.of<ProductProvider>(context);
    final products = _filtered(productProvider.productos);
    final cartCount = context.watch<CartProvider>().totalQuantity;

    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: Column(
        children: [
          _buildHeaderBackground(cartCount),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, i) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  final sel = _category == cat['name'];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _category = cat['name'] as String);
                      _cargarOpcionesCategoria();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.pierVerde : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? AppColors.pierVerde : AppColors.textSecondary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat['icon'] as IconData, size: 13, color: sel ? Colors.white : AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(cat['name'] as String,
                              style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                                  color: sel ? Colors.white : AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // No se limpia el imageCache global: recargar los datos basta y
                // evita que TODA la app tenga que volver a descargar imágenes.
                await context.read<ProductProvider>().refrescar();
                await _cargarCategorias();
                await _cargarFiltros();
              },
              color: AppColors.pierVerde,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
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
                    ),
                  ),
                  if (_hasFilters)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: GestureDetector(
                          onTap: _clearFilters,
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
                      ),
                    ),
                  if (productProvider.isLoading)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => const ProductSkeletonCard(),
                          childCount: 6,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _isGridView ? 2 : 1,
                          childAspectRatio: _isGridView ? 0.63 : 3.2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                      ),
                    )
                  else if (products.isEmpty)
                    SliverFillRemaining(child: _buildEmptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _buildCard(products[i], productProvider)
                              // Entrada escalonada: cada tarjeta entra un pelín
                              // después que la anterior (tope a 6 para no demorar
                              // listas largas), con fade + leve deslizamiento.
                              .animate()
                              .fadeIn(
                                duration: 350.ms,
                                delay: (40 * (i % 6)).ms,
                                curve: Curves.easeOut,
                              )
                              .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
                          childCount: products.length,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _isGridView ? 2 : 1,
                          childAspectRatio: _isGridView ? 0.63 : 3.2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBackground(int cartCount) {
    return Container(
      color: AppColors.pierVerde,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20, right: 20, bottom: 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Pier Repostería',
                      style: TextStyle(fontFamily: 'Playfair Display', fontSize: 28,
                          fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Artesanal & Gourmet',
                      style: TextStyle(fontSize: 13, color: Colors.white70)),
                ],
              ),
              GestureDetector(
                onTap: () => context.read<NavigationProvider>().setSelectedIndex(2),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.shoppingCart, color: Colors.white, size: 22),
                    ),
                    if (cartCount > 0)
                      Positioned(
                        right: -6, top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: AppColors.pierDorado, shape: BoxShape.circle),
                          child: Text('$cartCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) {
          setState(() => _searchQuery = v);
          _programarRegistroBusqueda();
        },
        decoration: InputDecoration(
          hintText: 'Busca tu antojo...',
          hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 15),
          prefixIcon: const Icon(LucideIcons.search, color: AppColors.textSecondary, size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(LucideIcons.x, color: AppColors.textSecondary, size: 18),
                  onPressed: () {
                    _busquedaTimer?.cancel();
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  })
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(LucideIcons.arrowUpDown, color: AppColors.textSecondary, size: 20),
                        onPressed: _showSortSheet, tooltip: 'Ordenar'),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: Icon(LucideIcons.slidersHorizontal,
                              color: _filtroSabor != null || _filtroTamano != null || _filtroTipo != null
                                  ? AppColors.pierVerde : Colors.grey, size: 20),
                          onPressed: _showFilterSheet, tooltip: 'Filtrar'),
                        if (_filtroSabor != null || _filtroTamano != null || _filtroTipo != null)
                          Positioned(right: 8, top: 8,
                              child: Container(width: 8, height: 8,
                                  decoration: BoxDecoration(color: AppColors.pierVerde, shape: BoxShape.circle))),
                      ],
                    ),
                  ],
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ✅ ACTUALIZADO: recibe productProvider para consultar promociones
  Widget _buildCard(Product p, ProductProvider provider) {
    return GestureDetector(
      onTap: () => _goToDetail(p),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: _isGridView
              ? _buildGridCard(p, provider)
              : _buildListCard(p, provider),
        ),
      ),
    );
  }

  Widget _buildGridCard(Product p, ProductProvider provider) {
    final tienePromo = provider.tieneDescuento(p.id);
    final precioFinal = provider.precioConDescuento(p.id, p.precio);
    final promo = provider.promocionDeProducto(p.id);
    final tipo = promo?['tipo']?.toString() ?? '';
    final porcentaje = promo?['descuento_porcentaje']?.toString();
    final badgeDestacado = promo?['badge_destacado']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 55,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'producto-img-${p.id}',
                child: Image.network(p.imagenUrl, fit: BoxFit.cover,
                    errorBuilder: (_, e, __) => Container(
                      color: AppColors.pierArena,
                      child: Icon(LucideIcons.cake, color: AppColors.pierVerde, size: 40),
                    )),
              ),
              // ✅ NUEVO: columna de badges por tipo (igual que el web)
              Positioned(
                top: 8, left: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Agotado (stock_online = 0) — el backend rechaza agregarlo
                    if (p.agotado)
                      _badge(AppColors.textSecondary,
                          icon: LucideIcons.ban, label: 'Agotado'),
                    // Popular — solo si no hay promo
                    if (p.popular && !tienePromo)
                      _badge(AppColors.pierDorado,
                          icon: Icons.star_rounded, label: 'Popular'),
                    if (tienePromo) ...[
                      // Descuento porcentaje
                      if (porcentaje != null)
                        _badge(Colors.red.shade500,
                            icon: LucideIcons.tag,
                            label: '-$porcentaje%'),
                      // Tipo relámpago
                      if (tipo == 'relampago')
                        _badge(Colors.orange.shade600,
                            icon: LucideIcons.zap, label: 'Flash'),
                      // Tipo temporada
                      if (tipo == 'temporada')
                        _badge(Colors.orange.shade700,
                            icon: LucideIcons.sparkles,
                            label: 'Temporada'),
                      // Tipo destacado con badge
                      if (tipo == 'destacado' && badgeDestacado != null)
                        _badge(Colors.purple.shade500,
                            icon: LucideIcons.sparkles,
                            label: badgeDestacado),
                      // Tipo nuevo
                      if (tipo == 'nuevo')
                        _badge(Colors.blue.shade500,
                            icon: LucideIcons.badgePlus, label: 'Nuevo'),
                    ],
                  ],
                ),
              ),
              // Favorito
              Positioned(
                top: 8, right: 8,
                child: GestureDetector(
                  onTap: () => _toggleFavorito(p.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _favoritos.contains(p.id) ? Colors.red : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
                    ),
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(_favoritos.contains(p.id)),
                      // Pop solo al marcar (al desmarcar entra sin rebote)
                      tween: Tween(
                          begin: _favoritos.contains(p.id) ? 1.6 : 1.0,
                          end: 1.0),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.elasticOut,
                      builder: (_, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Icon(
                        _favoritos.contains(p.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: _favoritos.contains(p.id) ? Colors.white : AppColors.textSecondary,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 45,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ✅ NUEVO: precio con tachado si hay descuento
                Row(
                  children: [
                    Text('\$${precioFinal.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: tienePromo ? Colors.red.shade600 : AppColors.pierDoradoOscuro)),
                    if (tienePromo) ...[
                      const SizedBox(width: 5),
                      Text('\$${p.precio.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.5), decoration: TextDecoration.lineThrough)),
                    ],
                  ],
                ),
                if (p.categoria.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.pierVerde.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(p.categoria,
                        style: TextStyle(fontSize: 9, color: AppColors.pierVerde, fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(height: 3),
                Text(p.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(p.descripcion,
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.3),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 13),
                      const SizedBox(width: 3),
                      Text(p.rating > 0 ? p.rating.toStringAsFixed(1) : '—',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    ]),
                    Consumer<CartProvider>(
                      builder: (context, cart, child) {
                        final inCart = cart.isInCart(p.id);
                        final anim = _cartAnims[p.id];
                        Widget btn = GestureDetector(
                          onTap: () => _addToCart(p, cart),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                                color: p.agotado
                                    ? AppColors.pierDorado
                                    : AppColors.pierVerde,
                                borderRadius: BorderRadius.circular(10)),
                            child: Icon(
                                p.agotado
                                    ? LucideIcons.bellRing
                                    : inCart ? LucideIcons.check : LucideIcons.plus,
                                color: Colors.white, size: 20),
                          ),
                        );
                        if (anim != null) btn = ScaleTransition(scale: anim, child: btn);
                        return btn;
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListCard(Product p, ProductProvider provider) {
    final tienePromo = provider.tieneDescuento(p.id);
    final precioFinal = provider.precioConDescuento(p.id, p.precio);
    final promo = provider.promocionDeProducto(p.id);
    final tipo = promo?['tipo']?.toString() ?? '';
    final porcentaje = promo?['descuento_porcentaje']?.toString();
    final badgeDestacado = promo?['badge_destacado']?.toString();

    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'producto-img-${p.id}',
                child: Image.network(p.imagenUrl, fit: BoxFit.cover,
                    errorBuilder: (_, e, __) => Container(
                      color: AppColors.pierArena,
                      child: Icon(LucideIcons.cake, color: AppColors.pierVerde, size: 36),
                    )),
              ),
              // ✅ Badges múltiples apilados igual que el web
              Positioned(
                top: 6, left: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.agotado)
                      _badge(AppColors.textSecondary,
                          icon: LucideIcons.ban, label: 'Agotado', small: true),
                    if (p.popular)
                      _badge(AppColors.pierDorado,
                          icon: Icons.star_rounded, label: 'Popular', small: true),
                    if (tienePromo) ...[
                      if (porcentaje != null)
                        _badge(Colors.red.shade500,
                            icon: LucideIcons.tag,
                            label: '-$porcentaje%', small: true),
                      if (tipo == 'relampago')
                        _badge(Colors.orange.shade600,
                            icon: LucideIcons.zap,
                            label: 'Flash', small: true),
                      if (tipo == 'temporada')
                        _badge(Colors.orange.shade700,
                            icon: LucideIcons.sparkles,
                            label: 'Temporada', small: true),
                      if (tipo == 'destacado' && badgeDestacado != null)
                        _badge(Colors.purple.shade500,
                            icon: LucideIcons.sparkles,
                            label: badgeDestacado, small: true),
                      if (tipo == 'nuevo')
                        _badge(Colors.blue.shade500,
                            icon: LucideIcons.badgePlus,
                            label: 'Nuevo', small: true),
                    ],
                  ],
                ),
              ),
              Positioned(
                bottom: 8, right: 8,
                child: GestureDetector(
                  onTap: () => _toggleFavorito(p.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: _favoritos.contains(p.id) ? Colors.red : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
                    ),
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(_favoritos.contains(p.id)),
                      tween: Tween(
                          begin: _favoritos.contains(p.id) ? 1.6 : 1.0,
                          end: 1.0),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.elasticOut,
                      builder: (_, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Icon(
                        _favoritos.contains(p.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: _favoritos.contains(p.id) ? Colors.white : AppColors.textSecondary,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(p.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(p.descripcion,
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ NUEVO: precio con tachado en lista
                        Row(children: [
                          Text('\$${precioFinal.toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800,
                                  color: tienePromo ? Colors.red.shade600 : AppColors.pierDoradoOscuro)),
                          if (tienePromo) ...[
                            const SizedBox(width: 6),
                            Text('\$${p.precio.toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.5),
                                    decoration: TextDecoration.lineThrough)),
                          ],
                        ]),
                        Row(children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                          const SizedBox(width: 3),
                          Text(p.rating > 0 ? p.rating.toStringAsFixed(1) : '—',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        ]),
                      ],
                    ),
                    Consumer<CartProvider>(
                      builder: (context, cart, child) {
                        final inCart = cart.isInCart(p.id);
                        final anim = _cartAnims[p.id];
                        Widget btn = GestureDetector(
                          onTap: () => _addToCart(p, cart),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                                color: p.agotado
                                    ? AppColors.pierDorado
                                    : AppColors.pierVerde,
                                borderRadius: BorderRadius.circular(12)),
                            child: p.agotado
                                ? const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.bellRing,
                                          color: Colors.white, size: 18),
                                      SizedBox(width: 6),
                                      Text('Avísame',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold)),
                                    ])
                                : Icon(
                                    inCart ? LucideIcons.check : LucideIcons.plus,
                                    color: Colors.white, size: 20),
                          ),
                        );
                        if (anim != null) btn = ScaleTransition(scale: anim, child: btn);
                        return btn;
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Helper: badge de promoción reutilizable para grid y lista
  /// [small] = true para vista lista (texto más compacto)
  Widget _badge(Color color, {required IconData icon, required String label, bool small = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: EdgeInsets.symmetric(
          horizontal: small ? 5 : 7, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: small ? 8 : 9),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: small ? 7 : 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2)),
        ],
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
            decoration: BoxDecoration(color: AppColors.pierVerde.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(LucideIcons.searchX, size: 48, color: AppColors.pierVerde),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack),
          const SizedBox(height: 20),
          const Text('Sin resultados',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('Intenta con otros términos\no ajusta los filtros',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(LucideIcons.refreshCw, color: Colors.white),
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
}