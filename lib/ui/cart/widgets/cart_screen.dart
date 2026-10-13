// lib/ui/cart/widgets/cart_screen.dart
//
// «Mi Carrito» (MVVM, Fase 5): encabezado con «Vaciar», cuántos productos y
// cuánto se ahorra, las líneas (cart_linea.dart) y el pie con el total
// (cart_resumen.dart). El estado vive en CartViewModel; si el backend rechaza
// un cambio (p. ej. sin stock) se avisa con un SnackBar.
//
// Movimiento: un solo Scaffold con el encabezado fijo; el cuerpo (cargando,
// error, vacío o la lista) cambia con un fundido a través, sin saltos. La
// primera vez que se ve, las líneas entran en cascada y el pie sube al
// final; una línea que llega después (agregada desde el catálogo) entra
// sola en la siguiente visita. Si el backend rechaza un cambio, esa línea se
// sacude junto con el aviso.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/cart_item_model.dart';
import 'package:pier_pasteleria/ui/cart/view_model/cart_view_model.dart';
import 'package:pier_pasteleria/ui/cart/widgets/cart_linea.dart';
import 'package:pier_pasteleria/ui/cart/widgets/cart_resumen.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/checkout_screen.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class CartScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const CartScreen({super.key, this.viewModel});

  final CartViewModel? viewModel;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final CartViewModel _vm = widget.viewModel ??
      CartViewModel(
        carrito: context.read<CartProvider>(),
        sesionIniciada: () => context.read<AuthProvider>().isAuthenticated,
      );

  // Rechazos del backend por línea: cada uno sacude esa línea una vez.
  final Map<String, int> _rechazos = {};

  // Último «N productos» mostrado: el nuevo rueda hacia arriba si sube y
  // hacia abajo si baja.
  int? _conteoPrevio;
  int _sentidoConteo = 1;

  // Líneas que ya estaban en la lista. Si llega una que no estaba (agregada
  // desde el catálogo, o devuelta por un rechazo del backend), el ámbito de
  // entradas abre otra tanda y solo esa línea entra; las que se construyen
  // al hacer scroll siguen llegando quietas.
  final Set<String> _clavesConocidas = {};
  int _tandaLineas = 0;

  // Si la pantalla ya se vio alguna vez. La pestaña del carrito se construye
  // oculta al abrir la app: las entradas del carrito vacío se montan la
  // primera vez que se abre (antes no hay nada que animar).
  bool _vista = false;

  @override
  void initState() {
    super.initState();
    unawaited(_vm.cargar());
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  /// Corre [accion] y, si el backend la rechazó, muestra el motivo (y
  /// sacude la [linea] que lo causó).
  Future<void> _hacer(
    Future<String?> Function() accion, {
    String? linea,
  }) async {
    final motivo = await accion();
    if (motivo == null || !mounted) return;
    if (linea != null) {
      setState(() => _rechazos[linea] = (_rechazos[linea] ?? 0) + 1);
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(motivo),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _carrito(context),
    );
  }

  // Un solo Scaffold (nunca dos en escena: los SnackBar se duplicarían) con
  // el encabezado fijo; solo el cuerpo cambia de estado.
  Widget _carrito(BuildContext context) {
    final lineas = _vm.lineas;
    final cargando = _vm.cargando;
    final error = _vm.errorCarga;
    // Visible ahora (se reconstruye al mostrarse u ocultarse la pestaña).
    final visible = TickerMode.valuesOf(context).enabled;
    final primeraVista = visible && !_vista;
    if (visible) _vista = true;
    // Lo que se monta con la pestaña oculta, o justo cuando se abre por
    // primera vez, espera a que la pestaña empiece a aparecer; lo que llega
    // con la pantalla ya a la vista entra de inmediato.
    final retraso = !visible || primeraVista
        ? AppMovimiento.trasPestana
        : Duration.zero;
    final Widget cuerpo;
    if (cargando) {
      cuerpo = const KeyedSubtree(
        key: ValueKey('cargando'),
        child: _EsqueletoCarrito(),
      );
    } else if (error != null) {
      cuerpo = KeyedSubtree(key: const ValueKey('error'), child: _error(error));
    } else if (lineas.isEmpty) {
      cuerpo = KeyedSubtree(
        key: const ValueKey('vacio'),
        child: _vacio(context, retraso),
      );
    } else {
      cuerpo = KeyedSubtree(
        key: const ValueKey('lista'),
        child: _lista(context, lineas, retraso),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        child: Column(
          children: [
            _encabezado(context, hayLineas: !cargando && lineas.isNotEmpty),
            Expanded(
              child: CambioAnimado(tipo: TipoCambio.atravesar, child: cuerpo),
            ),
          ],
        ),
      ),
    );
  }

  Widget _encabezado(BuildContext context, {required bool hayLineas}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          const Expanded(
            child: Text('Mi Carrito',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
          ),
          // «Vaciar» llega con un pop y se va encogiéndose.
          CambioAnimado(
            tipo: TipoCambio.escalar,
            alineacion: AlignmentDirectional.centerEnd,
            child: hayLineas
                ? PresionEscala(
                    key: const ValueKey('vaciar'),
                    escala: AppMovimiento.escalaPresionChica,
                    child: GestureDetector(
                      onTap: () => _confirmarVaciar(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.2)),
                        ),
                        child: const Text('Vaciar',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.error,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('sin-vaciar')),
          ),
        ],
      ),
    );
  }

  /// Sentido del cambio de «N productos» (1 si subió, -1 si bajó).
  int _sentido(int total) {
    final previo = _conteoPrevio;
    if (previo != null && previo != total) {
      _sentidoConteo = total > previo ? 1 : -1;
    }
    _conteoPrevio = total;
    return _sentidoConteo;
  }

  /// Tanda de entradas de las líneas: cambia cuando aparece una línea que no
  /// estaba en la lista anterior.
  int _tanda(List<CartItem> lineas) {
    final actuales = {for (final linea in lineas) linea.lineKey};
    if (_clavesConocidas.isNotEmpty &&
        !_clavesConocidas.containsAll(actuales)) {
      _tandaLineas++;
    }
    _clavesConocidas
      ..clear()
      ..addAll(actuales);
    return _tandaLineas;
  }

  /// Conteo, líneas en cascada y el pie con el total.
  Widget _lista(BuildContext context, List<CartItem> lineas, Duration retraso) {
    return Column(
      children: [
        EntradaSuave(retraso: retraso, child: _conteo()),
        Expanded(
          // Cada línea entra una sola vez: volver a la pestaña, recargar o
          // hacer scroll no la repite.
          child: AmbitoEntradas(
            generacion: _tanda(lineas),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: lineas.length,
              // Con la clave de cada línea, quitar una no reconstruye las de
              // abajo: conservan su estado y no vuelven a entrar.
              findItemIndexCallback: (clave) {
                final i =
                    lineas.indexWhere((l) => ValueKey(l.lineKey) == clave);
                return i < 0 ? null : i;
              },
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final linea = lineas[index];
                final clave = linea.lineKey;
                return EntradaSuave(
                  key: ValueKey(clave),
                  id: clave,
                  retraso: retraso,
                  child: Sacudida(
                    disparo: _rechazos[clave],
                    child: CartLinea(
                      linea: linea,
                      ocupada: _vm.ocupada(linea),
                      onIncrementar: () =>
                          _hacer(() => _vm.incrementar(linea), linea: clave),
                      onDecrementar: () =>
                          _hacer(() => _vm.decrementar(linea), linea: clave),
                      onEliminar: () =>
                          _hacer(() => _vm.eliminar(linea), linea: clave),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // El pie sube desde abajo al final de la cascada.
        EntradaSuave(
          orden: lineas.length,
          retraso: retraso,
          desplazamiento: const Offset(0, AppMovimiento.distanciaLarga),
          child: CartResumen(
            viewModel: _vm,
            onPagar: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CheckoutScreen()),
            ),
          ),
        ),
      ],
    );
  }

  /// «3 productos» y, si hay descuentos, «Ahorras $20».
  Widget _conteo() {
    final total = _vm.totalProductos;
    final productos = '$total producto${total == 1 ? '' : 's'}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(children: [
        Icon(LucideIcons.shoppingBag, size: 13, color: AppColors.pierVerde),
        const SizedBox(width: 5),
        CambioAnimado(
          tipo: TipoCambio.subir,
          direccion: _sentido(total),
          child: Text(
            productos,
            key: ValueKey(productos),
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500),
          ),
        ),
        // El chip del ahorro aparece con un pop y su monto cuenta.
        CambioAnimado(
          tipo: TipoCambio.escalar,
          child: _vm.tieneDescuentos
              ? Row(
                  key: const ValueKey('ahorro'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 10),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.pierVerde.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.pierVerde.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.tag,
                              size: 11, color: AppColors.pierVerde),
                          const SizedBox(width: 4),
                          MontoAnimado(
                            valor: _vm.ahorro,
                            formato: (v) =>
                                'Ahorras \$${v.toStringAsFixed(0)}',
                            estilo: TextStyle(
                                fontSize: 11,
                                color: AppColors.pierVerdeOscuro,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey('sin-ahorro')),
        ),
      ]),
    );
  }

  Widget _error(String mensaje) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.wifiOff,
                      size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(mensaje,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _vm.cargar,
                    icon: Icon(LucideIcons.refreshCw,
                        size: 16, color: AppColors.pierVerde),
                    label: Text('Reintentar',
                        style: TextStyle(color: AppColors.pierVerde)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Carrito vacío: la bolsa, los textos y el botón llegan en cascada. Con
  /// la pestaña todavía sin abrirse se pintan quietos (no hay nada que
  /// animar); la cascada se monta la primera vez que se ve.
  Widget _vacio(BuildContext context, Duration retraso) {
    Widget entrada(int orden, Widget hijo, {double escalaInicial = 1}) =>
        _vista
            ? EntradaSuave(
                orden: orden,
                retraso: retraso,
                escalaInicial: escalaInicial,
                child: hijo,
              )
            : hijo;
    return Column(
      children: [
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animación Lottie (asset local recoloreado a la paleta Pier).
                // En bucle, pero quieta con movimiento reducido (su primer
                // cuadro es la bolsa en reposo) y pausada si la pestaña se
                // oculta.
                entrada(
                  0,
                  escalaInicial: 0.9,
                  Lottie.asset(
                    'assets/lottie/empty_cart.json',
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                    animate: !AppMovimiento.reducido(context),
                  ),
                ),
                const SizedBox(height: 8),
                entrada(
                  1,
                  const Text('Tu carrito está vacío',
                      style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                ),
                const SizedBox(height: 8),
                entrada(
                  2,
                  const Text(
                      'Agrega productos desde el catálogo\npara comenzar tu pedido.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                ),
                const SizedBox(height: 28),
                entrada(
                  3,
                  ElevatedButton.icon(
                    onPressed: () =>
                        context.read<NavigationProvider>().goCatalogo(),
                    icon: const Icon(LucideIcons.store,
                        color: Colors.white, size: 18),
                    label: const Text('Ver Catálogo',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pierVerde,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _confirmarVaciar(BuildContext context) {
    unawaited(showDialog<void>(
      context: context,
      animationStyle: AppMovimiento.estiloDialogo(context),
      builder: (dialogContext) => EntradaDialogo(
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Vaciar carrito'),
          content: const Text(
              '¿Estás seguro que deseas eliminar todos los productos?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                unawaited(_hacer(_vm.vaciar));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error, elevation: 0),
              child:
                  const Text('Vaciar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    ));
  }
}

/// Mientras carga: tres líneas en blanco con el brillo de la paleta, con la
/// forma del carrito que viene (sin textos ni íconos). Cambia a las líneas
/// reales con el fundido del cuerpo.
class _EsqueletoCarrito extends StatelessWidget {
  const _EsqueletoCarrito();

  @override
  Widget build(BuildContext context) {
    // Las tres líneas miden ~390 dp: en una pantalla baja (celular de lado,
    // pantalla dividida) se recortan en vez de desbordar la columna.
    return const ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: double.infinity,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LineaFantasma(),
              SizedBox(height: 12),
              _LineaFantasma(),
              SizedBox(height: 12),
              _LineaFantasma(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineaFantasma extends StatelessWidget {
  const _LineaFantasma();

  static Widget _barra(double alto, double ancho, {double radio = 6}) =>
      Container(
        height: alto,
        width: ancho,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radio),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      // El brillo solo pinta las formas de adentro (la tarjeta queda
      // blanca); con movimiento reducido las formas quedan quietas.
      child: RepaintBoundary(
        child: Shimmer.fromColors(
          baseColor: AppColors.pierArenaOscuro,
          highlightColor: Colors.white.withValues(alpha: 0.9),
          enabled: !AppMovimiento.reducido(context),
          child: Row(
            children: [
              _barra(76, 76, radio: 12),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _barra(14, 120),
                    const SizedBox(height: 6),
                    _barra(10, 50),
                    const SizedBox(height: 10),
                    _barra(10, 70),
                    const SizedBox(height: 10),
                    _barra(28, 104, radio: 8),
                  ],
                ),
              ),
              _barra(16, 40),
            ],
          ),
        ),
      ),
    );
  }
}
