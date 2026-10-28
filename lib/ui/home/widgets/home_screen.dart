// lib/ui/home/widgets/home_screen.dart
//
// Inicio (MVVM, Fase 4): la vista arma las secciones con lo que expone
// HomeViewModel (categorías, promociones, reseñas, sucursales, slides y,
// con sesión, pide de nuevo y el pedido activo) y los productos de
// ProductProvider. Las publicaciones van primero (#175): justo después del
// carrusel y las categorías, con sesión de cliente, las 3 más recientes de
// «Novedades de Pier» (#132: FeedViewModel) con «Ver todo»; sin sesión, la
// invitación a entrar. Aquí solo queda escuchar la sesión, el refresco y el
// movimiento de las secciones: cada una
// entra una sola vez, en cascada (la que está más abajo espera a que el scroll
// la traiga), y las que llegan tarde (datos del backend, el pedido activo)
// abren su espacio sin saltos.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/config_testimonios.dart';
import 'package:pier_reposteria/ui/core/state/auth_provider.dart';
import 'package:pier_reposteria/ui/core/state/notification_provider.dart';
import 'package:pier_reposteria/ui/core/state/product_provider.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/feed/view_model/feed_view_model.dart';
import 'package:pier_reposteria/ui/feed/widgets/novedades_inicio.dart';
import 'package:pier_reposteria/ui/home/view_model/home_view_model.dart';
import 'package:pier_reposteria/ui/home/widgets/home_carrusel.dart';
import 'package:pier_reposteria/ui/home/widgets/home_encabezado.dart';
import 'package:pier_reposteria/ui/home/widgets/home_promociones.dart';
import 'package:pier_reposteria/ui/home/widgets/home_secciones.dart';
import 'package:pier_reposteria/ui/home/widgets/home_sucursal.dart';
import 'package:pier_reposteria/ui/home/widgets/movimiento_inicio.dart';
import 'package:pier_reposteria/utils/logger.dart';
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
            // Lo que ya está al llegar (con context.go) espera a que la
            // página empiece a verse.
            child: VistaInicio(
              retrasoLlegada: AppMovimiento.trasRaiz,
              child: CustomScrollView(
                slivers: [
                  _sliver('encabezado', EntradaInicio(
                    id: 'encabezado',
                    child: HomeEncabezado(
                      auth: auth,
                      onVolverDeNotificaciones: () =>
                          unawaited(_cargarDatosUsuario()),
                    ),
                  )),
                  // El aviso del pedido abre su espacio al llegar (sin
                  // empujar de golpe lo de abajo) y lo cierra al terminar.
                  _sliver('pedido', RanuraInicio(
                    child: pedido == null
                        ? null
                        : PedidoActivoBanner(
                            pedido: pedido,
                            alCambiar: (_) =>
                                unawaited(_vm.actualizarPedidoActivo()),
                          ),
                  )),
                  _sliver('buscador', const EntradaInicio(
                    id: 'buscador',
                    child: HomeBuscador(),
                  )),
                  _sliver('carrusel', EntradaInicio(
                    id: 'carrusel',
                    child: HomeCarrusel(slides: _vm.slides),
                  )),
                  _sliver('categorias', EntradaInicio(
                    id: 'categorias',
                    child: HomeCategorias(nombres: _vm.nombresCategorias),
                  )),
                  // Las publicaciones van primero (#175): las 3 más recientes
                  // para el cliente; sin sesión, la invitación a entrar.
                  if (auth.esCliente)
                    _sliver('novedades', EntradaInicio(
                      id: 'novedades',
                      child: NovedadesInicio(feed: _feed),
                    ))
                  else if (!auth.isAuthenticated)
                    _sliver('invitacion', const EntradaInicio(
                      id: 'invitacion',
                      child: InvitacionNovedades(),
                    )),
                  _seccion('promo-banner', promos.banner == null
                      ? null
                      : HomePromoBanner(promociones: promos)),
                  _seccion('relampago', promos.relampago.isEmpty
                      ? null
                      : HomeOfertasRelampago(promociones: promos)),
                  _seccion('temporada', promos.temporada.isEmpty
                      ? null
                      : HomeOfertasTemporada(promociones: promos)),
                  _seccion('destacado', promos.destacado.isEmpty
                      ? null
                      : HomePromoDestacado(promociones: promos)),
                  // Destacados arriba de "Pide de nuevo" para mayor visibilidad
                  _seccion('destacados',
                      productos.isLoading || productos.populares.isNotEmpty
                          ? _destacados(productos)
                          : null),
                  _seccion('pide-de-nuevo', auth.isAuthenticated && _vm.hayCompras
                      ? HomeSeccionProductos(
                          title: 'Pide de nuevo',
                          titleIcon: LucideIcons.rotateCcw,
                          productos: _vm.pideDeNuevo(productos.productos),
                        )
                      : null),
                  _seccion('mejor-calificados', productos.mejorCalificados.isEmpty
                      ? null
                      : HomeSeccionProductos(
                          title: 'Mejor calificados',
                          titleIcon: Icons.star_rounded,
                          productos: productos.mejorCalificados,
                        )),
                  _seccion('recien-llegados', productos.nuevos.isEmpty
                      ? null
                      : HomeSeccionProductos(
                          title: 'Recién llegados',
                          titleIcon: LucideIcons.badgeCheck,
                          productos: productos.nuevos,
                        )),
                  _seccion('resenas', _vm.resenasDestacadas.isEmpty
                      ? null
                      : HomeResenasDestacadas(
                          resenas: _vm.resenasDestacadas,
                          titulo: _vm.testimonios?.titulo ??
                              ConfigTestimonios.tituloPorDefecto,
                          subtitulo: _vm.testimonios?.subtitulo,
                        )),
                  _sliver('sucursal', EntradaInicio(
                    id: 'sucursal',
                    child: HomeSucursal(
                      contacto: _vm.contacto,
                      sucursales: _vm.sucursales,
                    ),
                  )),
                  _sliver('por-que', const EntradaInicio(
                    id: 'por-que',
                    child: HomePorQueElegirnos(),
                  )),
                  _sliver('pie', const SizedBox(height: 32)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Destacados: mientras cargan los productos (al abrir o al recargar), un
  /// esqueleto con su misma forma; al llegar, la sección se arma encima, sin
  /// salto de altura.
  Widget _destacados(ProductProvider productos) {
    return AnimatedSize(
      duration: AppMovimiento.reducido(context)
          ? const Duration(milliseconds: 1)
          : AppMovimiento.media,
      curve: AppMovimiento.curvaEstandar,
      alignment: AlignmentDirectional.topStart,
      clipBehavior: Clip.none,
      child: CambioAnimado(
        tipo: TipoCambio.atravesar,
        duracion: AppMovimiento.media,
        child: productos.isLoading
            ? const KeyedSubtree(
                key: ValueKey('esqueleto'),
                child: HomeSeccionProductosEsqueleto(),
              )
            : KeyedSubtree(
                key: const ValueKey('contenido'),
                child: HomeSeccionProductos(
                  title: 'Destacados',
                  titleIcon: Icons.star_rounded,
                  productos: productos.populares,
                ),
              ),
      ),
    );
  }

  // Cada sección tiene su sliver con llave: las que aparecen o se van no
  // le cambian su estado a las demás (el carrusel no vuelve al primer slide
  // ni una lista pierde su scroll).
  Widget _sliver(String id, Widget child) =>
      SliverToBoxAdapter(key: ValueKey('inicio-$id'), child: child);

  /// Sección que puede no estar: su ranura fija abre y cierra el espacio, y
  /// la sección entra al llegar (una sola vez: recargar no la repite).
  Widget _seccion(String id, Widget? seccion) => _sliver(
        id,
        RanuraInicio(
          child: seccion == null ? null : EntradaInicio(id: id, child: seccion),
        ),
      );
}
