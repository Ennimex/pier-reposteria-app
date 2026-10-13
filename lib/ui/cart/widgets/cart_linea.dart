// lib/ui/cart/widgets/cart_linea.dart
//
// Una línea de «Mi Carrito»: imagen, nombre, tamaño, precio unitario (con el
// de lista tachado), promoción, selector de cantidad y subtotal. Se desliza a
// la izquierda para quitarla. Mientras espera al backend ([ocupada]) no
// acepta otro cambio.
//
// Movimiento: los botones − / + se hunden al tocarlos y se atenúan suave
// mientras la línea espera; la cantidad y el subtotal ruedan como un
// odómetro (suben al aumentar, bajan al disminuir); el − se vuelve bote de
// basura con un pop cuando queda una sola unidad; la foto aparece con un
// fundido al llegar de la red, y al deslizar, el bote del fondo crece justo
// cuando soltar ya quitaría la línea.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/cart_item_model.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_pasteleria/ui/core/ui/precios_carrito.dart';

class CartLinea extends StatefulWidget {
  const CartLinea({
    required this.linea,
    required this.ocupada,
    required this.onIncrementar,
    required this.onDecrementar,
    required this.onEliminar,
    super.key,
  });

  final CartItem linea;
  final bool ocupada;
  final VoidCallback onIncrementar;
  final VoidCallback onDecrementar;
  final VoidCallback onEliminar;

  @override
  State<CartLinea> createState() => _CartLineaState();
}

class _CartLineaState extends State<CartLinea> {
  // Si soltar ahora quitaría la línea (umbral del Dismissible alcanzado).
  final ValueNotifier<bool> _umbral = ValueNotifier<bool>(false);

  // Sentido del último cambio de cantidad: los números ruedan hacia arriba
  // al aumentar y hacia abajo al disminuir.
  int _sentido = 1;

  @override
  void didUpdateWidget(CartLinea oldWidget) {
    super.didUpdateWidget(oldWidget);
    final antes = oldWidget.linea.quantity;
    final ahora = widget.linea.quantity;
    if (antes != ahora) _sentido = ahora > antes ? 1 : -1;
  }

  @override
  void dispose() {
    _umbral.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linea = widget.linea;
    return Dismissible(
      key: ValueKey(linea.lineKey),
      direction:
          widget.ocupada ? DismissDirection.none : DismissDirection.endToStart,
      onUpdate: (detalles) => _umbral.value = detalles.reached,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: _BoteUmbral(alcanzado: _umbral),
      ),
      onDismissed: (_) => widget.onEliminar(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                linea.imagenUrl,
                width: 76, height: 76,
                fit: BoxFit.cover,
                // La foto que llega de la red aparece con un fundido; la que
                // ya estaba en caché se pinta al instante.
                frameBuilder: (context, hijo, cuadro, sincrona) => sincrona
                    ? hijo
                    : AnimatedOpacity(
                        opacity: cuadro == null ? 0 : 1,
                        duration: AppMovimiento.duracion(
                            context, AppMovimiento.corta),
                        curve: AppMovimiento.curvaEntrada,
                        child: hijo,
                      ),
                errorBuilder: (_, _, _) => Container(
                  width: 76, height: 76,
                  color: AppColors.pierArena,
                  child: Icon(LucideIcons.cake,
                      color: AppColors.pierVerde, size: 30),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: _info()),
            _subtotal(),
          ],
        ),
      ),
    );
  }

  Widget _info() {
    final linea = widget.linea;
    final ocupada = widget.ocupada;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(linea.nombre,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        Text(
          linea.tamano == 'grande' ? 'Grande' : 'Chico',
          style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        PrecioUnitario(linea: linea),
        if (linea.tieneDescuento && linea.promoNombre != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.pierVerde.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: AppColors.pierVerde.withValues(alpha: 0.25)),
            ),
            child: Text(
              linea.promoNombre!,
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.pierVerdeOscuro,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            _BotonCantidad(
              icono: linea.quantity == 1 ? LucideIcons.trash2 : LucideIcons.minus,
              color: linea.quantity == 1 ? AppColors.error : AppColors.pierVerde,
              onTap: ocupada ? null : widget.onDecrementar,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              // Odómetro: la cifra nueva entra desde abajo (o desde arriba
              // al disminuir) dentro de su ventana.
              child: ClipRect(
                child: CambioAnimado(
                  tipo: TipoCambio.subir,
                  direccion: _sentido,
                  alineacion: Alignment.center,
                  child: Text('${linea.quantity}',
                      key: ValueKey(linea.quantity),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                ),
              ),
            ),
            _BotonCantidad(
              icono: LucideIcons.plus,
              color: AppColors.pierVerde,
              onTap: ocupada ? null : widget.onIncrementar,
            ),
          ],
        ),
      ],
    );
  }

  Widget _subtotal() {
    final linea = widget.linea;
    final subtotal = '\$${linea.subtotal.toStringAsFixed(0)}';
    final ahorro = '-\$${linea.ahorroTotal.toStringAsFixed(0)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        CambioAnimado(
          tipo: TipoCambio.subir,
          direccion: _sentido,
          alineacion: AlignmentDirectional.centerEnd,
          child: Text(
            subtotal,
            key: ValueKey(subtotal),
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.pierDoradoOscuro),
          ),
        ),
        if (linea.tieneDescuento)
          CambioAnimado(
            tipo: TipoCambio.subir,
            direccion: _sentido,
            alineacion: AlignmentDirectional.centerEnd,
            child: Text(
              ahorro,
              key: ValueKey(ahorro),
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.pierVerde,
                  fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

/// Bote del fondo al deslizar: crece cuando el arrastre ya pasó el umbral
/// (soltar quitaría la línea) y vuelve a su tamaño si el dedo regresa.
class _BoteUmbral extends StatelessWidget {
  const _BoteUmbral({required this.alcanzado});

  final ValueListenable<bool> alcanzado;

  @override
  Widget build(BuildContext context) {
    final reducido = AppMovimiento.reducido(context);
    return ValueListenableBuilder<bool>(
      valueListenable: alcanzado,
      builder: (context, listo, hijo) => AnimatedScale(
        scale: listo && !reducido ? 1.25 : 1,
        duration: AppMovimiento.rapida,
        curve: AppMovimiento.curvaRebote,
        child: hijo,
      ),
      child: const Icon(LucideIcons.trash2, color: Colors.white, size: 26),
    );
  }
}

/// Botón cuadrado de − / + ; sin [onTap] se ve atenuado.
class _BotonCantidad extends StatelessWidget {
  const _BotonCantidad({
    required this.icono,
    required this.color,
    required this.onTap,
  });

  final IconData icono;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rapida = AppMovimiento.duracion(context, AppMovimiento.rapida);
    final activo = onTap != null;
    // El atenuado de «esperando al backend» ya no salta: se desvanece. Sin
    // onTap tampoco se hunde (IgnorePointer solo apaga la respuesta táctil;
    // el botón ya no hacía nada).
    return AnimatedOpacity(
      opacity: activo ? 1 : 0.4,
      duration: rapida,
      child: IgnorePointer(
        ignoring: !activo,
        child: PresionEscala(
          escala: AppMovimiento.escalaPresionChica,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: rapida,
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              // − ↔ bote: el ícono nuevo entra con un pop.
              child: CambioAnimado(
                tipo: TipoCambio.escalar,
                alineacion: Alignment.center,
                child: Icon(icono, key: ValueKey(icono), size: 16, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
