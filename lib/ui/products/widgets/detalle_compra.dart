// lib/ui/products/widgets/detalle_compra.dart
//
// Compra desde el detalle: selector de tamaño (si hay precio grande) y la
// barra con el total, la cantidad y el botón de añadir ("Avísame" si está
// agotado). Leen y modifican el ProductDetailViewModel. El total y la
// cantidad ruedan como contador al cambiar y la tarjeta de tamaño elegida se
// levanta un poco.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/ui/core/state/product_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/products/view_model/product_detail_view_model.dart';
import 'package:pier_reposteria/ui/products/widgets/movimiento_catalogo.dart';

/// "Selecciona el tamaño": Chico y Grande con su precio (tachado si hay
/// descuento). La elegida se levanta un poco con un rebote y sus textos
/// cambian de color junto con el fondo.
class DetalleSelectorTamano extends StatelessWidget {
  const DetalleSelectorTamano({
    required this.viewModel,
    required this.promociones,
    super.key,
  });

  final ProductDetailViewModel viewModel;
  final ProductProvider promociones;

  /// Cuánto se levanta la tarjeta elegida.
  static const double _elevada = 1.03;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final id = vm.producto.id;
    final tienePromo = promociones.tieneDescuento(id);
    const tamanos = ProductDetailViewModel.tamanos;
    return Row(
      children: List.generate(tamanos.length, (i) {
        final sel = vm.tamano == i;
        final precioTam = vm.precioDeTamano(i);
        final precioFinalTam = tienePromo
            ? promociones.precioConDescuento(id, precioTam)
            : precioTam;
        return Expanded(
          child: PresionEscala(
            child: GestureDetector(
              onTap: () => vm.elegirTamano(i),
              child: AnimatedScale(
                scale: sel ? _elevada : 1,
                duration: AppMovimiento.duracion(context, AppMovimiento.corta),
                curve: AppMovimiento.curvaRebote,
                child: AnimatedContainer(
                  // Mismo ritmo que los textos: con otra curva el blanco
                  // llegaba antes que el verde del fondo.
                  duration: AppMovimiento.duracion(context, AppMovimiento.corta),
                  curve: AppMovimiento.curvaEstandar,
                  margin: EdgeInsets.only(right: i < tamanos.length - 1 ? 10 : 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.pierVerde : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: sel
                            ? AppColors.pierVerde.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.05),
                        blurRadius: sel ? 12 : 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  // Los textos cambian de color junto con el fondo (antes el
                  // blanco aparecía sobre la tarjeta todavía blanca).
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextoEstiloAnimado(tamanos[i],
                          estilo: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: sel ? Colors.white : AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      // Precio por tamaño con tachado si hay descuento
                      if (tienePromo) ...[
                        TextoEstiloAnimado('\$${precioTam.toStringAsFixed(0)}',
                            estilo: TextStyle(
                                fontSize: 11,
                                color: sel
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : AppColors.textSecondary.withValues(alpha: 0.5),
                                decoration: TextDecoration.lineThrough)),
                        TextoEstiloAnimado('\$${precioFinalTam.toStringAsFixed(0)}',
                            estilo: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: sel ? Colors.white : Colors.red.shade600)),
                      ] else
                        TextoEstiloAnimado('\$${precioTam.toStringAsFixed(0)}',
                            estilo: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: sel ? Colors.white : AppColors.pierVerde)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Total (con descuento) × cantidad, contador de piezas y botón de añadir.
class DetalleBarraCompra extends StatelessWidget {
  const DetalleBarraCompra({
    required this.viewModel,
    required this.promociones,
    required this.animacion,
    required this.onAgregar,
    required this.onAvisarme,
    this.claveBoton,
    super.key,
  });

  final ProductDetailViewModel viewModel;
  final ProductProvider promociones;

  /// Rebote del botón al añadir (lo anima la pantalla).
  final Animation<double> animacion;
  final VoidCallback onAgregar;
  final VoidCallback onAvisarme;

  /// Clave del botón de añadir: de ahí sale la miniatura que vuela al
  /// carrito.
  final GlobalKey? claveBoton;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final id = vm.producto.id;
    final agotado = vm.producto.agotado;
    final total =
        promociones.precioConDescuento(id, vm.precioBase) * vm.cantidad;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              // Rueda como contador al cambiar el tamaño o la cantidad y el
              // botón de al lado ajusta su ancho con suavidad.
              TamanoAnimado(
                alineacion: AlignmentDirectional.centerStart,
                child: CifraRodante(
                  valor: total,
                  texto: '\$${total.toStringAsFixed(2)}',
                  estilo: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: promociones.tieneDescuento(id)
                          ? Colors.red.shade600
                          : AppColors.pierVerde),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          _SelectorCantidad(viewModel: vm),
          const SizedBox(width: 12),
          Expanded(
            child: ScaleTransition(
              scale: animacion,
              child: SizedBox(
                key: claveBoton,
                height: 52,
                child: ElevatedButton(
                  // Agotado → "Avísame" (registra interés)
                  onPressed: agotado ? onAvisarme : onAgregar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        agotado ? AppColors.pierDorado : AppColors.pierVerde,
                    disabledBackgroundColor:
                        AppColors.textSecondary.withValues(alpha: 0.35),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final ancho = constraints.maxWidth > 80;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              agotado
                                  ? LucideIcons.bellRing
                                  : LucideIcons.shoppingCart,
                              color: Colors.white,
                              size: 18),
                          if (ancho) ...[
                            const SizedBox(width: 6),
                            Text(agotado ? 'Avísame' : 'Añadir',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Píldora − cantidad +. La cantidad rueda como contador; tocar − en 1 o +
/// en el tope no cambia nada (el ViewModel la acota), así que la píldora da
/// una sacudida corta para que se note el límite.
class _SelectorCantidad extends StatefulWidget {
  const _SelectorCantidad({required this.viewModel});

  final ProductDetailViewModel viewModel;

  @override
  State<_SelectorCantidad> createState() => _SelectorCantidadState();
}

class _SelectorCantidadState extends State<_SelectorCantidad> {
  // Toques en un límite: cada uno dispara la sacudida.
  int _alLimite = 0;

  void _quitar() {
    final vm = widget.viewModel;
    if (vm.cantidad <= 1) setState(() => _alLimite++);
    vm.quitarPieza();
  }

  void _sumar() {
    final vm = widget.viewModel;
    if (vm.cantidad >= ProductDetailViewModel.cantidadMaxima) {
      setState(() => _alLimite++);
    }
    vm.sumarPieza();
  }

  @override
  Widget build(BuildContext context) {
    final cantidad = widget.viewModel.cantidad;
    return Sacudida(
      disparo: _alLimite,
      amplitud: AppMovimiento.distanciaCorta / 2,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.pierArena,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(children: [
          _BotonCantidad(icon: LucideIcons.minus, onTap: _quitar),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: CifraRodante(
              valor: cantidad,
              texto: '$cantidad',
              estilo: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          _BotonCantidad(icon: LucideIcons.plus, onTap: _sumar),
        ]),
      ),
    );
  }
}

class _BotonCantidad extends StatelessWidget {
  const _BotonCantidad({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PresionEscala(
      escala: AppMovimiento.escalaPresionChica,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Icon(icon, color: AppColors.textPrimary, size: 18),
        ),
      ),
    );
  }
}
