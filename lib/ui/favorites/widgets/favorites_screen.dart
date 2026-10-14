// lib/ui/favorites/widgets/favorites_screen.dart
//
// «Mis Favoritos». Movimiento: los esqueletos salen solo en la primera carga
// (al volver del detalle la cuadrícula se queda) y dan paso al contenido con
// un fundido a través; las tarjetas entran en cascada una sola vez (buscar no
// las repite) y se hunden al tocarlas; su foto vuela al detalle; el «+» hace
// un pulso, pasa a palomita y regresa, y lanza la miniatura al carrito; la
// campana de «Avísame» se mece; el contador rueda; el estado vacío se arma
// en ondas con un latido del corazón.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/data/repositories/demanda_repository.dart';
import 'package:pier_pasteleria/data/repositories/favoritos_repository.dart';
import 'package:pier_pasteleria/data/repositories/productos_repository.dart';
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
import 'package:pier_pasteleria/ui/favorites/view_model/favorites_view_model.dart';
import 'package:pier_pasteleria/ui/orders/widgets/movimiento_pedidos.dart';
import 'package:pier_pasteleria/ui/products/widgets/product_detail_screen.dart';
import 'package:provider/provider.dart';

// Icono de fallback según nombre de categoría
IconData _iconForCategoria(String nombre) {
  switch (nombre.toLowerCase()) {
    case 'pasteles':
      return LucideIcons.cake;
    case 'roscas':
      return LucideIcons.donut;
    case 'pays':
      return LucideIcons.chartPie;
    case 'postres':
      return LucideIcons.cookie;
    case 'cafetería':
    case 'cafeteria':
      return LucideIcons.coffee;
    case 'bebidas':
      return LucideIcons.cupSoda;
    case 'panes':
      return LucideIcons.croissant;
    default:
      return LucideIcons.sandwich;
  }
}

class FavoritesScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const FavoritesScreen({super.key, this.viewModel});

  final FavoritesViewModel? viewModel;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  // El State es dueño del ViewModel (lo crea, lo carga y lo libera).
  late final FavoritesViewModel _vm = widget.viewModel ??
      FavoritesViewModel(
        favoritosRepo: context.read<FavoritosRepository>(),
        productosRepo: context.read<ProductosRepository>(),
        registrarInteres: context.read<DemandaRepository>().registrarClicAgotado,
      );
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_vm.cargar());
    // Asegura que promociones estén disponibles para mostrar precios con descuento.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<ProductProvider>().cargarProductos());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _quitarFavorito(Product product) async {
    final ok = await _vm.quitar(product);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Error al quitar de favoritos'),
          backgroundColor: Colors.red),
    );
  }

  /// "Avísame": registra el interés en un producto agotado (demanda no
  /// atendida) y lo confirma. Espejo del botón Avísame de la web.
  void _avisarme(Product p) {
    _vm.avisarme(p);
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

  /// Lo que hace el «+» de una tarjeta. [botonContext] es el del botón
  /// tocado: de ahí sale la miniatura que vuela al carrito si el backend
  /// acepta el alta. Devuelve true si se pidió el alta (el botón lo celebra
  /// al toque); el aviso de «agregado» espera a que el backend la acepte.
  bool _addToCart(Product p, BuildContext botonContext) {
    // Agotado: el botón es "Avísame" (registra interés)
    if (p.agotado) {
      _avisarme(p);
      return false;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      Navigator.push(context,
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()))
          .ignore();
      return false;
    }
    unawaited(_confirmarAlta(p, botonContext));
    return true;
  }

  /// Espera al backend: si acepta el alta, la miniatura vuela al carrito y
  /// se avisa «agregado»; si la rechaza, se muestra el motivo y no vuela
  /// nada. Mientras responde, la insignia del carrito espera a la miniatura
  /// en lugar de rebotar.
  Future<void> _confirmarAlta(Product p, BuildContext botonContext) async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final error = await VueloAlCarrito.lanzarAlConfirmar(
      botonContext,
      cart.addItem(p),
      imagenUrl: p.imagenUrl,
    );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error));
      return;
    }
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
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildContenido(context),
    );
  }

  Widget _buildContenido(BuildContext context) {
    final filtered = _vm.filtrados;
    final favoritos = _vm.favoritos;
    final searchQuery = _vm.busqueda;
    final prov = context.watch<ProductProvider>();
    // Los esqueletos solo cuando no hay nada que mostrar (la primera carga):
    // al regresar del detalle la lista recarga por detrás y la cuadrícula se
    // queda donde estaba, lista para recibir la foto que regresa.
    final esqueletos = _vm.cargando && favoritos.isEmpty;
    final espera = esperaDeLlegada(context);

    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        // De los esqueletos al contenido con un fundido a través (los
        // esqueletos salen del árbol al terminar). Mientras hay contenido su
        // Key no cambia: el buscador conserva el foco y el teclado.
        child: CambioAnimado(
          tipo: TipoCambio.atravesar,
          child: esqueletos
              ? KeyedSubtree(
                  key: const ValueKey('esqueletos'),
                  child: GridView.count(
                    padding: const EdgeInsets.fromLTRB(16, 80, 16, 40),
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    children: List.generate(
                        4, (_) => const ProductSkeletonCard()),
                  ),
                )
              : KeyedSubtree(
                  key: const ValueKey('contenido'),
                  // Cada tarjeta entra una sola vez: buscar, volver del
                  // detalle o recargar no repiten la cascada.
                  child: AmbitoEntradas(
                    child: CustomScrollView(
                      slivers: [
                        // ── HEADER ──────────────────────────────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            child: Row(
                              children: [
                                PresionEscala(
                                  escala: AppMovimiento.escalaPresionChica,
                                  child: GestureDetector(
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
                                onChanged: _vm.buscar,
                                decoration: InputDecoration(
                                  hintText: 'Buscar en favoritos...',
                                  hintStyle: TextStyle(
                                      color: Colors.grey[400], fontSize: 14),
                                  prefixIcon: Icon(LucideIcons.search,
                                      color: AppColors.pierVerde, size: 22),
                                  suffixIcon: searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(LucideIcons.x,
                                              color: Colors.grey, size: 18),
                                          onPressed: () {
                                            _searchController.clear();
                                            _vm.buscar('');
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
                        if (favoritos.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                              child: Row(children: [
                                Icon(Icons.favorite,
                                    size: 13, color: AppColors.pierVerde),
                                const SizedBox(width: 6),
                                // Rueda hacia abajo al filtrar y hacia arriba al
                                // borrar la búsqueda.
                                ContadorRodante(
                                  valor: searchQuery.isEmpty
                                      ? favoritos.length
                                      : filtered.length,
                                  texto: searchQuery.isEmpty
                                      ? '${favoritos.length} producto${favoritos.length == 1 ? '' : 's'} guardado${favoritos.length == 1 ? '' : 's'}'
                                      : '${filtered.length} resultado${filtered.length == 1 ? '' : 's'}',
                                  estilo: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500),
                                ),
                              ]),
                            ),
                          ),

                        // ── GRID ────────────────────────────────────────
                        if (favoritos.isEmpty)
                          SliverFillRemaining(child: _buildEmptyState(espera))
                        else if (filtered.isEmpty)
                          SliverFillRemaining(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // La lupa llega un poco inclinada y se endereza.
                                  EntradaSuave(
                                    escalaInicial: 0.85,
                                    desplazamiento: Offset.zero,
                                    child: MovimientoUnaVez(
                                      duracion: AppMovimiento.enfasis,
                                      builder: (context, avance, lupa) =>
                                          RotationTransition(
                                        turns: avance.drive(_lupaSeEndereza),
                                        child: lupa,
                                      ),
                                      child: Icon(LucideIcons.searchX,
                                          size: 56, color: Colors.grey[300]),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  EntradaSuave(
                                    orden: 1,
                                    child: Text('Sin resultados para "$searchQuery"',
                                        style: TextStyle(
                                            color: Colors.grey[500], fontSize: 15)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                            sliver: SliverGrid(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => EntradaSuave(
                                  key: ValueKey(_idTarjeta(filtered[index])),
                                  id: _idTarjeta(filtered[index]),
                                  retraso: espera,
                                  // Solo la primera pantalla entra en cascada.
                                  animar: index < AppMovimiento.pasosMaximos,
                                  child: _buildCard(filtered[index], prov),
                                ),
                                childCount: filtered.length,
                                // Con la Key de cada tarjeta, filtrar o quitar un
                                // favorito no reconstruye a las demás (no recargan
                                // su foto ni vuelven a entrar).
                                findChildIndexCallback: (clave) {
                                  final i = filtered.indexWhere(
                                      (p) => ValueKey(_idTarjeta(p)) == clave);
                                  return i < 0 ? null : i;
                                },
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
                ),
        ),
      ),
    );
  }

  // La lupa de «Sin resultados»: de un poco inclinada a derecha, con rebote.
  static final Animatable<double> _lupaSeEndereza = Tween<double>(
    begin: -0.05,
    end: 0,
  ).chain(CurveTween(curve: AppMovimiento.curvaRebote));

  static String _idTarjeta(Product p) => 'favorito-${p.id}';

  // ── CARD ──────────────────────────────────────────────────────────
  /// La tarjeta se hunde un poco al tocarla (el corazón y el «+» se hunden
  /// solos, sin hundirla) y su foto vuela al detalle.
  Widget _buildCard(Product p, ProductProvider prov) {
    final tienePromo = prov.tieneDescuento(p.id);
    final precioFinal = prov.precioConDescuento(p.id, p.precio);
    return PresionEscala(
      child: GestureDetector(
        onTap: () => unawaited(Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => ProductDetailScreen(product: p)),
        ).then((_) => _vm.cargarFavoritos())),
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
                      // La foto vuela al detalle (misma etiqueta de siempre,
                      // producto-img-<id>) enderezando sus esquinas; si llega
                      // de internet aparece con un fundido corto.
                      child: FotoProductoHero(
                        productoId: p.id,
                        imagenUrl: p.imagenUrl,
                        radio: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                        child: Image.network(
                          p.imagenUrl,
                          fit: BoxFit.cover,
                          frameBuilder: (_, foto, cuadro, sincrona) =>
                              FotoQueAparece(
                                  foto: foto, cuadro: cuadro, sincrona: sincrona),
                          errorBuilder: (_, _, _) => ColoredBox(
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
                      // El corazón se aprieta al tocarlo (quitarlo es
                      // inmediato: la tarjeta se va).
                      child: PresionEscala(
                        escala: AppMovimiento.escalaPresionChica,
                        child: GestureDetector(
                          onTap: () => unawaited(_quitarFavorito(p)),
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
                          _BotonAgregar(
                            producto: p,
                            onTap: (botonContext) => _addToCart(p, botonContext),
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

  // Cierra Favoritos y cambia a la pestaña del catálogo (si hay navegación
  // por pestañas arriba; si no, solo cierra).
  void _irAlMenu() {
    Navigator.pop(context);
    try {
      context.read<NavigationProvider>().goCatalogo();
    } on ProviderNotFoundException {
      // Abierta fuera del shell con pestañas.
    }
  }

  // ── EMPTY STATE ───────────────────────────────────────────────────
  // Latido doble del corazón del estado vacío (termina en 1): cada golpe
  // sube con la curva de entrada y baja con la de salida; el último se
  // asienta con la estándar.
  static final Animatable<double> _latido = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 1.14)
            .chain(CurveTween(curve: AppMovimiento.curvaEntrada)),
        weight: 18,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.14, end: 1)
            .chain(CurveTween(curve: AppMovimiento.curvaSalida)),
        weight: 18,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 1.1)
            .chain(CurveTween(curve: AppMovimiento.curvaEntrada)),
        weight: 18,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.1, end: 1)
            .chain(CurveTween(curve: AppMovimiento.curvaEstandar)),
        weight: 46,
      ),
    ],
  );

  /// Se arma una sola vez, después de [espera]: los círculos se abren en
  /// onda desde el centro, el corazón late dos veces, los textos y el botón
  /// suben y el panel de categorías llega desde abajo con sus círculos uno
  /// tras otro.
  Widget _buildEmptyState(Duration espera) {
    // Categorías del backend (o de respaldo), con su icono por nombre.
    final cats = _vm.categoriasSugeridas;

    Widget onda(int orden, Widget circulo) => EntradaSuave(
          orden: orden,
          retraso: espera,
          escalaInicial: 0.85,
          desplazamiento: Offset.zero,
          child: circulo,
        );

    return Column(
      children: [
        const Spacer(),
        Stack(
          alignment: Alignment.center,
          children: [
            onda(2, Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                color: AppColors.pierVerde.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            )),
            onda(1, Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                color: AppColors.pierVerde.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            )),
            onda(0, Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              // Cuando las ondas terminan de abrirse, el corazón late.
              child: MovimientoUnaVez(
                retraso: espera + AppMovimiento.entrada,
                duracion: AppMovimiento.relleno,
                builder: (context, avance, corazon) => ScaleTransition(
                  scale: avance.drive(_latido),
                  child: corazon,
                ),
                child: Icon(Icons.favorite_rounded,
                    size: 34,
                    color: AppColors.pierVerde.withValues(alpha: 0.5)),
              ),
            )),
          ],
        ),
        const SizedBox(height: 28),
        EntradaSuave(
          orden: 3,
          retraso: espera,
          child: const Text('Sin favoritos aún',
              style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
        ),
        const SizedBox(height: 10),
        EntradaSuave(
          orden: 4,
          retraso: espera,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Explora nuestro menú y guarda tus postres preferidos para pedirlos después.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey[500], height: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 32),
        EntradaSuave(
          orden: 5,
          retraso: espera,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _irAlMenu,
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
        ),
        const Spacer(),

        // ── EXPLORA POR CATEGORÍA ──────────────────────────────
        EntradaSuave(
          orden: 6,
          retraso: espera,
          desplazamiento: const Offset(0, AppMovimiento.distanciaLarga),
          child: Container(
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
                  children: [
                    for (final (i, nombre) in cats.indexed)
                      // Uno tras otro, cuando el panel ya está llegando.
                      EntradaSuave(
                        orden: 6,
                        retraso: espera + AppMovimiento.paso * (i + 1),
                        escalaInicial: 0.85,
                        desplazamiento:
                            const Offset(0, AppMovimiento.distanciaCorta),
                        child: PresionEscala(
                          escala: AppMovimiento.escalaPresionChica,
                          child: GestureDetector(
                            onTap: _irAlMenu,
                            child: Column(children: [
                              Container(
                                width: 62, height: 62,
                                decoration: BoxDecoration(
                                  color: AppColors.pierArena,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.grey.withValues(alpha: 0.2)),
                                ),
                                child: Icon(_iconForCategoria(nombre),
                                    color: AppColors.pierVerde, size: 26),
                              ),
                              const SizedBox(height: 6),
                              Text(nombre,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500)),
                            ]),
                          ),
                        ),
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
}

/// El «+» de una tarjeta de favoritos. Al agregar hace un pulso (se hunde,
/// rebota y asienta en su tamaño) y el ícono pasa a palomita y regresa a
/// «+»; si el producto está agotado («Avísame») la campana se mece. Se
/// hunde al presionarlo. Solo decora: lo que pasa al tocarlo lo decide
/// [onTap], que dice si se agregó.
class _BotonAgregar extends StatefulWidget {
  const _BotonAgregar({required this.producto, required this.onTap});

  final Product producto;

  /// Recibe el contexto de este botón (de ahí sale la miniatura que vuela
  /// al carrito) y devuelve true si el producto se agregó.
  final bool Function(BuildContext botonContext) onTap;

  @override
  State<_BotonAgregar> createState() => _BotonAgregarState();
}

class _BotonAgregarState extends State<_BotonAgregar>
    with SingleTickerProviderStateMixin {
  // Al agregar, la palomita dura lo que vuela la miniatura al carrito
  // (AppMovimiento.vuelo) y el «+» vuelve cuando el carrito la recibe; el
  // pulso de AppMovimiento ocupa sus primeros 400 ms, como en los demás
  // botones de agregar.
  static final Animatable<double> _pulso = AppMovimiento.pulso.chain(
    CurveTween(
      curve: Interval(
        0,
        AppMovimiento.empuje.inMicroseconds /
            AppMovimiento.vuelo.inMicroseconds,
      ),
    ),
  );
  // «Avísame»: la campana se mece con el ritmo de la de Notificaciones.
  static const Animatable<double> _vaiven = Balanceo();

  late final AnimationController _control;

  @override
  void initState() {
    super.initState();
    _control = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  void _alTocar() {
    final agrego = widget.onTap(context);
    if (!mounted || AppMovimiento.reducido(context)) return;
    final agotado = widget.producto.agotado;
    // Sin sesión (se abrió el inicio de sesión) no hay nada que celebrar.
    if (!agrego && !agotado) return;
    _control
      ..duration = agotado ? AppMovimiento.relleno : AppMovimiento.vuelo
      ..forward(from: 0).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final agotado = widget.producto.agotado;
    return PresionEscala(
      escala: AppMovimiento.escalaPresionChica,
      child: GestureDetector(
        onTap: _alTocar,
        child: ScaleTransition(
          scale: agotado ? kAlwaysCompleteAnimation : _control.drive(_pulso),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: agotado ? AppColors.pierDorado : AppColors.pierVerde,
              borderRadius: BorderRadius.circular(10),
            ),
            child: agotado
                // La campana cuelga de arriba y se mece.
                ? RotationTransition(
                    turns: _control.drive(_vaiven),
                    alignment: Alignment.topCenter,
                    child: const Icon(LucideIcons.bellRing,
                        color: Colors.white, size: 22),
                  )
                : AnimatedBuilder(
                    animation: _control,
                    builder: (context, _) {
                      final palomita = _control.isAnimating;
                      return CambioAnimado(
                        tipo: TipoCambio.escalar,
                        alineacion: Alignment.center,
                        child: Icon(
                            palomita ? LucideIcons.check : LucideIcons.plus,
                            key: ValueKey<bool>(palomita),
                            color: Colors.white,
                            size: 22),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
