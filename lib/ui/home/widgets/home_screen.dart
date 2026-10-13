// lib/ui/home/widgets/home_screen.dart
//
// Inicio (MVVM, Fase 4): la vista arma las secciones con lo que expone
// HomeViewModel (categorías, promociones, reseñas, sucursales, slides y,
// con sesión, pide de nuevo y el pedido activo) y los productos de
// ProductProvider. Al final, con sesión de cliente, «Novedades de Pier»
// (#132: FeedViewModel), que carga más al acercarse al final. Aquí solo queda
// escuchar la sesión, el refresco y la entrada animada de las secciones.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/notification_provider.dart';
import 'package:pier_pasteleria/ui/core/state/product_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/feed/view_model/feed_view_model.dart';
import 'package:pier_pasteleria/ui/feed/widgets/feed_sliver.dart';
import 'package:pier_pasteleria/ui/home/view_model/home_view_model.dart';
import 'package:pier_pasteleria/ui/home/widgets/home_carrusel.dart';
import 'package:pier_pasteleria/ui/home/widgets/home_encabezado.dart';
import 'package:pier_pasteleria/ui/home/widgets/home_promociones.dart';
import 'package:pier_pasteleria/ui/home/widgets/home_secciones.dart';
import 'package:pier_pasteleria/ui/home/widgets/home_sucursal.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.viewModel, this.feedViewModel});

  /// Para pruebas; si son null la pantalla crea los suyos.
  final HomeViewModel? viewModel;
  final FeedViewModel? feedViewModel;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // El State es dueño del ViewModel (lo crea, lo carga y lo libera).
  late final HomeViewModel _vm = widget.viewModel ??
      HomeViewModel(
        productosRepo: context.read(),
        resenasRepo: context.read(),
        configRepo: context.read(),
        pedidosRepo: context.read(),
      );
  late final FeedViewModel _feed;
  String? _lastUserEmail;

  /// Margen (px) antes del final en el que se pide la siguiente página.
  static const _margenCargarMas = 1500.0;

  @override
  void initState() {
    super.initState();
    _feed = widget.feedViewModel ?? FeedViewModel(repo: context.read());
    PierLog.nav('→ HomeScreen');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<ProductProvider>().cargarProductos());
      unawaited(_vm.cargar());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    final userEmail = auth.currentUser?['email']?.toString();
    if (userEmail == _lastUserEmail) return;
    _lastUserEmail = userEmail;
    if (auth.isAuthenticated && userEmail != null) {
      unawaited(_cargarDatosUsuario());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _vm.limpiarDatosUsuario();
      });
    }
    // Las publicaciones son solo para el cliente con sesión
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (auth.esCliente) {
        unawaited(_feed.cargar());
      } else {
        _feed.limpiar();
      }
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    _feed.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosUsuario() async {
    if (!context.read<AuthProvider>().isAuthenticated) return;
    context.read<NotificationProvider>().startPolling();
    await _vm.cargarDatosUsuario();
  }

  Future<void> _refrescar() async {
    PierLog.info('Refresh HomeScreen');
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    if (context.read<AuthProvider>().esCliente) unawaited(_feed.recargar());
    await context.read<ProductProvider>().refrescar();
    unawaited(_vm.cargar());
    await _cargarDatosUsuario();
  }

  /// Agrega desde una promoción o sugerencia del feed y lo avisa.
  Future<void> _agregarAlCarrito(Product producto, double precio) async {
    final avisos = ScaffoldMessenger.of(context);
    final error = await context
        .read<CartProvider>()
        .addItem(producto, 1, 'chico', precio);
    avisos.showSnackBar(SnackBar(
      content: Text(error ?? 'Se agregó al carrito'),
      backgroundColor: error == null ? AppColors.pierVerde : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Pide la siguiente página del feed al acercarse al final.
  bool _alDesplazar(ScrollNotification n) {
    if (n.metrics.axis == Axis.vertical &&
        n.metrics.extentAfter < _margenCargarMas &&
        context.read<AuthProvider>().esCliente) {
      unawaited(_feed.cargarMas());
    }
    return false;
  }

  // Entrada en cascada de las secciones superiores: fade + slide sutil
  // escalonado por orden. Solo anima la primera vez que la sección se monta.
  Widget _entrada(int orden, Widget child) {
    return child
        .animate()
        .fadeIn(delay: (70 * orden).ms, duration: 350.ms)
        .slideY(
            begin: 0.05,
            end: 0,
            delay: (70 * orden).ms,
            duration: 350.ms,
            curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final auth = context.watch<AuthProvider>();
    final productos = context.watch<ProductProvider>();

    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final promos = _vm.promociones;
        final pedido = _vm.pedidoActivo;
        return Scaffold(
          backgroundColor: AppColors.pierArena,
          body: RefreshIndicator(
            onRefresh: _refrescar,
            color: AppColors.pierVerde,
            child: NotificationListener<ScrollNotification>(
              onNotification: _alDesplazar,
              child: CustomScrollView(
              slivers: [
                _sliver(_entrada(0, HomeEncabezado(
                  auth: auth,
                  onVolverDeNotificaciones: () => unawaited(_cargarDatosUsuario()),
                ))),
                if (pedido != null)
                  _sliver(_entrada(1, PedidoActivoBanner(
                    pedido: pedido,
                    alCambiar: (_) => unawaited(_vm.actualizarPedidoActivo()),
                  ))),
                _sliver(_entrada(1, const HomeBuscador())),
                _sliver(_entrada(2, HomeCarrusel(slides: _vm.slides))),
                if (promos.banner != null)
                  _sliver(_entrada(3, HomePromoBanner(promociones: promos))),
                if (promos.relampago.isNotEmpty)
                  _sliver(_entrada(3, HomeOfertasRelampago(promociones: promos))),
                if (promos.temporada.isNotEmpty)
                  _sliver(_entrada(3, HomeOfertasTemporada(promociones: promos))),
                if (promos.destacado.isNotEmpty)
                  _sliver(_entrada(3, HomePromoDestacado(promociones: promos))),
                _sliver(_entrada(3, HomeCategorias(nombres: _vm.nombresCategorias))),
                // Destacados arriba de "Pide de nuevo" para mayor visibilidad
                if (productos.isLoading)
                  _sliver(Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                        child: CircularProgressIndicator(color: AppColors.pierVerde)),
                  ))
                else if (productos.populares.isNotEmpty)
                  _sliver(HomeSeccionProductos(
                    title: 'Destacados',
                    titleIcon: Icons.star_rounded,
                    productos: productos.populares,
                  )),
                if (auth.isAuthenticated && _vm.hayCompras)
                  _sliver(HomeSeccionProductos(
                    title: 'Pide de nuevo',
                    titleIcon: LucideIcons.rotateCcw,
                    productos: _vm.pideDeNuevo(productos.productos),
                  )),
                if (productos.mejorCalificados.isNotEmpty)
                  _sliver(HomeSeccionProductos(
                    title: 'Mejor calificados',
                    titleIcon: Icons.star_rounded,
                    productos: productos.mejorCalificados,
                  )),
                if (productos.nuevos.isNotEmpty)
                  _sliver(HomeSeccionProductos(
                    title: 'Recién llegados',
                    titleIcon: LucideIcons.badgeCheck,
                    productos: productos.nuevos,
                  )),
                if (_vm.resenasDestacadas.isNotEmpty)
                  _sliver(HomeResenasDestacadas(resenas: _vm.resenasDestacadas)),
                _sliver(HomeSucursal(
                  contacto: _vm.contacto,
                  sucursales: _vm.sucursales,
                )),
                _sliver(const HomePorQueElegirnos()),
                if (auth.esCliente)
                  FeedSliver(viewModel: _feed, alAgregar: _agregarAlCarrito),
                _sliver(const SizedBox(height: 32)),
              ],
            ),
            ),
          ),
        );
      },
    );
  }

  Widget _sliver(Widget child) => SliverToBoxAdapter(child: child);
}
