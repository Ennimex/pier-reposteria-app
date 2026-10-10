// lib/ui/cart/widgets/cart_screen.dart
//
// «Mi Carrito» (MVVM, Fase 5): encabezado con «Vaciar», cuántos productos y
// cuánto se ahorra, las líneas (cart_linea.dart) y el pie con el total
// (cart_resumen.dart). El estado vive en CartViewModel; si el backend rechaza
// un cambio (p. ej. sin stock) se avisa con un SnackBar.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/ui/cart/view_model/cart_view_model.dart';
import 'package:pier_pasteleria/ui/cart/widgets/cart_linea.dart';
import 'package:pier_pasteleria/ui/cart/widgets/cart_resumen.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/checkout_screen.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:provider/provider.dart';

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

  /// Corre [accion] y, si el backend la rechazó, muestra el motivo.
  Future<void> _hacer(Future<String?> Function() accion) async {
    final motivo = await accion();
    if (motivo == null || !mounted) return;
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
      builder: (context, _) => _vm.cargando
          ? Scaffold(
              backgroundColor: AppColors.pierArena,
              body: Center(
                  child: CircularProgressIndicator(color: AppColors.pierVerde)),
            )
          : _carrito(context),
    );
  }

  Widget _carrito(BuildContext context) {
    final lineas = _vm.lineas;
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        child: Column(
          children: [
            _encabezado(context, hayLineas: lineas.isNotEmpty),
            if (lineas.isNotEmpty) _conteo() else const SizedBox(height: 12),
            Expanded(
              child: switch (_vm.errorCarga) {
                final error? => _error(error),
                _ when lineas.isEmpty => _vacio(context),
                _ => ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: lineas.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final linea = lineas[index];
                      return CartLinea(
                        linea: linea,
                        ocupada: _vm.ocupada(linea),
                        onIncrementar: () =>
                            _hacer(() => _vm.incrementar(linea)),
                        onDecrementar: () =>
                            _hacer(() => _vm.decrementar(linea)),
                        onEliminar: () => _hacer(() => _vm.eliminar(linea)),
                      );
                    },
                  ),
              },
            ),
            if (lineas.isNotEmpty)
              CartResumen(
                viewModel: _vm,
                onPagar: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                ),
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
          if (hayLineas)
            GestureDetector(
              onTap: () => _confirmarVaciar(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                ),
                child: const Text('Vaciar',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }

  /// «3 productos» y, si hay descuentos, «Ahorras $20».
  Widget _conteo() {
    final total = _vm.totalProductos;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(children: [
        Icon(LucideIcons.shoppingBag, size: 13, color: AppColors.pierVerde),
        const SizedBox(width: 5),
        Text(
          '$total producto${total == 1 ? '' : 's'}',
          style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500),
        ),
        if (_vm.tieneDescuentos) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.pierVerde.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppColors.pierVerde.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.tag, size: 11, color: AppColors.pierVerde),
                const SizedBox(width: 4),
                Text(
                  'Ahorras \$${_vm.ahorro.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.pierVerdeOscuro,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }

  Widget _error(String mensaje) {
    return Center(
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
    );
  }

  Widget _vacio(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animación Lottie (asset local recoloreado a la paleta Pier)
          Lottie.asset(
            'assets/lottie/empty_cart.json',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 8),
          const Text('Tu carrito está vacío',
              style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text(
              'Agrega productos desde el catálogo\npara comenzar tu pedido.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => context.read<NavigationProvider>().goCatalogo(),
            icon: const Icon(LucideIcons.store, color: Colors.white, size: 18),
            label: const Text('Ver Catálogo',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pierVerde,
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmarVaciar(BuildContext context) {
    unawaited(showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
    ));
  }
}
