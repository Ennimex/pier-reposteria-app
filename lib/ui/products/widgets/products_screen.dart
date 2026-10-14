// lib/ui/products/widgets/products_screen.dart
//
// Catálogo (MVVM, Fase 4): la vista pinta lo que expone ProductsViewModel
// (categoría, búsqueda, filtros, orden, favoritos) sobre el catálogo que
// carga ProductProvider. Aquí solo queda lo que es de la interfaz: el texto
// del buscador, cuadrícula/lista, el rebote del botón de carrito, el vuelo de
// la miniatura al carrito, la entrada en cascada de las tarjetas, mandar a
// iniciar sesión y los avisos (SnackBar).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/auth/widgets/login_screen.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/state/product_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_pasteleria/ui/core/ui/skeletons.dart';
import 'package:pier_pasteleria/ui/products/view_model/products_view_model.dart';
import 'package:pier_pasteleria/ui/products/widgets/catalogo_secciones.dart';
import 'package:pier_pasteleria/ui/products/widgets/movimiento_catalogo.dart';
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

  // La pestaña se está abriendo con una categoría pedida desde el inicio:
  // la tanda de tarjetas que llega en ese cuadro espera a que la pestaña
  // empiece a verse.
  bool _abriendoPestana = false;

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
    _abriendoPestana = true;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _abriendoPestana = false);
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
      // Hunde, rebota y asienta en 1 (antes el botón se quedaba al 130 %).
      final c = AnimationController(
          vsync: this, duration: AppMovimiento.enfasis);
      _cartAnims[id] = c.drive(AppMovimiento.pulso);
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

  /// [boton] es el botón tocado: de ahí sale la miniatura que vuela al
  /// carrito si el backend acepta el alta.
  Future<void> _addToCart(Product p, BuildContext boton) async {
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
    // El botón responde al toque; con «reducir movimiento» no rebota (como
    // el «+» de favoritos).
    if (!AppMovimiento.reducido(context)) {
      _getCartController(p.id).forward(from: 0).ignore();
    }
    // Solo se confirma «agregado» si el backend acepta el alta; mientras
    // responde, la insignia de la barra espera a la miniatura en vez de
    // rebotar, y si lo rechaza no sale ninguna.
    final error = await VueloAlCarrito.lanzarAlConfirmar(
      boton,
      context.read<CartProvider>().addItem(p),
      imagenUrl: p.imagenUrl,
    );
    if (!mounted) return;
    if (error != null) {
      _error(error);
      return;
    }
    _aviso('${p.nombre} agregado',
        icono: Icons.check_circle_rounded, color: AppColors.pierVerde);
  }

  Future<void> _toggleFavorito(String id) async {
    if (!_autenticado) {
      _irALogin();
      return;
    }
    final error = await _vm.alternarFavorito(id);
    if (error != null && mounted) _error(error);
  }

  void _error(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensaje),
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
        // Tanda de entrada de las tarjetas: cambia con lo que decide «qué se
        // ve» (categoría, filtros, orden, vista) y entonces todas entran otra
        // vez en cascada. Escribir en el buscador no la cambia: las tarjetas
        // que siguen no se mueven.
        final generacion = [
          _vm.categoria,
          _vm.filtroSabor,
          _vm.filtroTamano,
          _vm.filtroTipo,
          _vm.orden.name,
          _isGridView,
        ].join('|');
        // Las tarjetas que se construyen con la pestaña oculta (la primera
        // carga, antes de abrir el catálogo) o mientras se abre esperan a
        // que la pestaña empiece a verse; las que llegan con la pantalla a la
        // vista entran ya.
        final retraso = _abriendoPestana ||
                !TickerMode.getValuesNotifier(context).value.enabled
            ? AppMovimiento.trasPestana
            : Duration.zero;
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
                      // "Quitar filtros" abre su espacio y aparece (o se
                      // apaga y lo cierra): la cuadrícula se desliza en vez
                      // de saltar.
                      SliverToBoxAdapter(
                        child: Aparicion(
                          visible: _vm.hayFiltros,
                          child: _quitarFiltros(),
                        ),
                      ),
                      if (productProvider.isLoading)
                        _grid((context, i) => const ProductSkeletonCard(), 6)
                      else if (products.isEmpty)
                        SliverFillRemaining(
                            child: CatalogoVacio(onLimpiar: _limpiarTodo))
                      else
                        // Entrada en cascada: cada tarjeta sube y aparece un
                        // escalón después de la anterior (las del séptimo
                        // escalón en adelante entran juntas). Cada producto
                        // entra una sola vez por tanda: volver con scroll,
                        // regresar del detalle o recargar favoritos no repite
                        // nada, y las que aparecen al hacer scroll llegan
                        // quietas.
                        AmbitoEntradas(
                          generacion: generacion,
                          child: _grid(
                            (context, i) => EntradaSuave(
                              key: ValueKey<String>(products[i].id),
                              id: products[i].id,
                              retraso: retraso,
                              child: _card(products[i], productProvider),
                            ),
                            products.length,
                            clave: ValueKey<String>(generacion),
                            // Al buscar, la tarjeta de un producto que sigue
                            // en la lista conserva su lugar en el árbol.
                            indicePorClave: (clave) {
                              if (clave is! ValueKey<String>) return null;
                              final i = products
                                  .indexWhere((p) => p.id == clave.value);
                              return i < 0 ? null : i;
                            },
                          ),
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
        onAgregar: (boton) => _addToCart(p, boton),
      );

  Widget _grid(NullableIndexedWidgetBuilder builder, int cantidad,
      {Key? clave, ChildIndexGetter? indicePorClave}) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      sliver: SliverGrid(
        key: clave,
        delegate: SliverChildBuilderDelegate(builder,
            childCount: cantidad, findChildIndexCallback: indicePorClave),
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
          PresionEscala(
            escala: AppMovimiento.escalaPresionChica,
            child: GestureDetector(
              onTap: () => setState(() => _isGridView = !_isGridView),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.pierVerde.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.pierVerde.withValues(alpha: 0.2)),
                ),
                // El ícono cambia con un rebote, la etiqueta rueda y la
                // píldora ajusta su ancho con suavidad.
                child: TamanoAnimado(
                  alineacion: AlignmentDirectional.centerStart,
                  child: Row(children: [
                    CambioAnimado(
                      tipo: TipoCambio.escalar,
                      alineacion: Alignment.center,
                      child: Icon(_isGridView ? LucideIcons.grid2x2 : LucideIcons.list,
                          key: ValueKey<bool>(_isGridView),
                          color: AppColors.pierVerde, size: 16),
                    ),
                    const SizedBox(width: 5),
                    ClipRect(
                      child: CambioAnimado(
                        tipo: TipoCambio.subir,
                        direccion: _isGridView ? -1 : 1,
                        soloEntrada: true,
                        child: Text(_isGridView ? 'Cuadrícula' : 'Lista',
                            key: ValueKey<bool>(_isGridView),
                            style: TextStyle(fontSize: 12, color: AppColors.pierVerde,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quitarFiltros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      // Píldora: se hunde como los chips.
      child: PresionEscala(
        escala: AppMovimiento.escalaPresionChica,
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
      ),
    );
  }
}
