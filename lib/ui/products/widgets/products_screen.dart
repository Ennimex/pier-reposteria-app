// lib/ui/products/widgets/products_screen.dart
//
// Catálogo (MVVM, Fase 4): la vista pinta lo que expone ProductsViewModel
// (categoría, búsqueda, filtros, orden, favoritos y los productos que pide
// por páginas, #37); de ProductProvider solo toma las promociones de las
// tarjetas. Aquí solo queda lo que es de la interfaz: el texto
// del buscador, cuadrícula/lista, pedir la siguiente página al acercarse al
// final (con su pie y los esqueletos de la primera), llevar la lista arriba
// al empezar otra consulta, el rebote del botón de carrito, el vuelo de la
// miniatura al carrito, la entrada en cascada de las tarjetas, mandar a
// iniciar sesión y los avisos (SnackBar). Cuando la primera página no llega y
// se ve la copia guardada en el teléfono, un aviso lo dice (#265).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/data/services/catalogo_guardado_service.dart';
import 'package:pier_reposteria/domain/models/consulta_catalogo.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/ui/auth/widgets/login_screen.dart';
import 'package:pier_reposteria/ui/core/state/auth_provider.dart';
import 'package:pier_reposteria/ui/core/state/cart_provider.dart';
import 'package:pier_reposteria/ui/core/state/navigation_provider.dart';
import 'package:pier_reposteria/ui/core/state/product_provider.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/core/ui/skeletons.dart';
import 'package:pier_reposteria/ui/products/view_model/products_view_model.dart';
import 'package:pier_reposteria/ui/products/widgets/catalogo_secciones.dart';
import 'package:pier_reposteria/ui/products/widgets/movimiento_catalogo.dart';
import 'package:pier_reposteria/ui/products/widgets/pie_catalogo.dart';
import 'package:pier_reposteria/ui/products/widgets/product_detail_screen.dart';
import 'package:pier_reposteria/ui/products/widgets/producto_catalogo_card.dart';
import 'package:pier_reposteria/utils/logger.dart';
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
        catalogoGuardado: context.read<CatalogoGuardadoService>(),
        categoriaInicial: widget.initialCategory ?? ProductsViewModel.todas,
      );
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _control = ScrollController();
  bool _isGridView = true;

  /// Margen (px) antes del final en el que se pide la siguiente página.
  static const _margenCargarMas = 600.0;

  // La consulta de la lista que se ve: cuando empieza a pedirse otra, la lista
  // vuelve arriba (_alCambiar).
  late ConsultaCatalogo _consultaVista;

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
    _consultaVista = _vm.consulta;
    _vm.addListener(_alCambiar);
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

  /// Cambió algo en el ViewModel. Cuando empieza a pedirse otra consulta (al
  /// teclear todavía no: hasta que se pregunta), la lista vuelve arriba antes
  /// de pintar sus esqueletos; si no, la nueva primera página se abriría donde
  /// quedó el scroll de la anterior. Después de pintar lo que llegó se revisa
  /// si ya se ve casi el final.
  void _alCambiar() {
    if (!mounted) return;
    if (_vm.cargando && _vm.consulta != _consultaVista) {
      _consultaVista = _vm.consulta;
      _llevarArriba();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _quizaCargarMas());
  }

  void _llevarArriba() {
    if (_control.hasClients && _control.position.pixels > 0) {
      _control.jumpTo(0);
    }
  }

  /// Pide la siguiente página si falta poco para el final, también cuando lo
  /// cargado no alcanza a llenar la pantalla. Tras un error espera a que la
  /// persona toque «Reintentar» (PieCatalogo).
  void _quizaCargarMas() {
    if (!mounted ||
        !_control.hasClients ||
        !_control.position.hasContentDimensions ||
        _vm.errorMas != null) {
      return;
    }
    if (_control.position.extentAfter < _margenCargarMas) {
      unawaited(_vm.cargarMas());
    }
  }

  bool _alDesplazar(ScrollNotification n) {
    if (n.metrics.axis == Axis.vertical) _quizaCargarMas();
    return false;
  }

  @override
  void dispose() {
    _authRef?.removeListener(_onAuthChanged);
    _navRef?.removeListener(_onNavChanged);
    _vm.removeListener(_alCambiar);
    _control.dispose();
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

  /// Deslizar para recargar y «Reintentar» (catálogo sin conexión, #160): las
  /// promociones de las tarjetas y la página 1 con categorías y filtros. No
  /// se limpia el imageCache global: recargar los datos basta y evita que
  /// TODA la app vuelva a descargar imágenes.
  Future<void> _recargar() => Future.wait([
        context.read<ProductProvider>().refrescar(),
        _vm.recargar(),
      ]);

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
      _aviso('Anotamos tu interés en "${p.nombre}".',
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
    // Solo por las promociones de las tarjetas; los productos son del VM.
    final productProvider = context.watch<ProductProvider>();
    final cartCount = context.watch<CartProvider>().totalQuantity;

    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final products = _vm.productos;
        final error = _vm.error;
        // Tanda de entrada de las tarjetas: cambia con lo que decide «qué se
        // ve» (categoría, filtros, orden, vista) y entonces todas entran otra
        // vez en cascada. Buscar no la cambia, pero tampoco la necesita: la
        // consulta nueva pasa por los esqueletos, el ámbito se crea de nuevo
        // y las tarjetas del resultado entran en cascada (solo si la respuesta
        // llega en el mismo cuadro, las que siguen no se mueven).
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
              // Se abre y se cierra con suavidad: la lista no salta.
              Aparicion(
                visible: _vm.sinConexion,
                child: _avisoSinConexion(),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _recargar,
                  color: AppColors.pierVerde,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _alDesplazar,
                    child: CustomScrollView(
                      controller: _control,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _tituloYVista()),
                        // "Quitar filtros" abre su espacio y aparece (o se
                        // apaga y lo cierra): la cuadrícula se desliza en
                        // vez de saltar.
                        SliverToBoxAdapter(
                          child: Aparicion(
                            visible: _vm.hayFiltros,
                            child: _quitarFiltros(),
                          ),
                        ),
                        // Esqueletos mientras llega la primera página: 6 en
                        // cuadrícula y 4 en lista.
                        if (_vm.cargando && products.isEmpty)
                          _grid((context, i) => const ProductSkeletonCard(),
                              _isGridView ? 6 : 4)
                        // La primera página no pudo llegar (p. ej. sin
                        // internet): no es «Sin resultados» de los filtros
                        // (#160).
                        else if (error != null && products.isEmpty)
                          SliverFillRemaining(
                            child: CatalogoVacio.sinConexion(
                              mensaje: error,
                              onReintentar: _recargar,
                            ),
                          )
                        // La primera página llegó vacía.
                        else if (_vm.fin && products.isEmpty)
                          SliverFillRemaining(
                              child: CatalogoVacio(onLimpiar: _limpiarTodo))
                        else ...[
                          // Entrada en cascada: cada tarjeta sube y aparece
                          // un escalón después de la anterior (las del
                          // séptimo escalón en adelante entran juntas). Cada
                          // producto entra una sola vez por tanda: volver con
                          // scroll, regresar del detalle o recargar favoritos
                          // no repite nada, y las que aparecen al hacer
                          // scroll llegan quietas.
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
                              abajo: 0,
                              // Si la lista cambia sin pasar por los
                              // esqueletos (al recargar la misma consulta o
                              // si la respuesta llega en el mismo cuadro), la
                              // tarjeta de un producto que sigue en ella
                              // conserva su lugar en el árbol.
                              indicePorClave: (clave) {
                                if (clave is! ValueKey<String>) return null;
                                final i = products
                                    .indexWhere((p) => p.id == clave.value);
                                return i < 0 ? null : i;
                              },
                            ),
                          ),
                          // Pie: cargando más o el aviso para reintentar.
                          // Va pegado a la última fila; el espacio de siempre
                          // al final de la lista (100 en total) queda
                          // después de él.
                          SliverPadding(
                            padding: const EdgeInsets.only(bottom: 76),
                            sliver: SliverToBoxAdapter(
                                child: PieCatalogo(viewModel: _vm)),
                          ),
                        ],
                      ],
                    ),
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

  /// La cuadrícula (o la lista) de [cantidad] elementos; [abajo] es el espacio
  /// que deja después de ella.
  Widget _grid(NullableIndexedWidgetBuilder builder, int cantidad,
      {Key? clave, ChildIndexGetter? indicePorClave, double abajo = 100}) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, abajo),
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

  /// La página 1 no llegó y lo que se ve es el catálogo guardado en el
  /// teléfono (#265): se dice, para que no se tome por lo más reciente.
  Widget _avisoSinConexion() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.pierDorado.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.wifiOff, size: 16, color: AppColors.aviso),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Sin conexión: es el último catálogo que viste',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
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
