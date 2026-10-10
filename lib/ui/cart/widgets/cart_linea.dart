// lib/ui/cart/widgets/cart_linea.dart
//
// Una línea de «Mi Carrito»: imagen, nombre, tamaño, precio unitario (con el
// de lista tachado), promoción, selector de cantidad y subtotal. Se desliza a
// la izquierda para quitarla. Mientras espera al backend ([ocupada]) no
// acepta otro cambio.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/cart_item_model.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/precios_carrito.dart';

class CartLinea extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(linea.lineKey),
      direction:
          ocupada ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(LucideIcons.trash2,
            color: Colors.white, size: 26),
      ),
      onDismissed: (_) => onEliminar(),
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
              onTap: ocupada ? null : onDecrementar,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('${linea.quantity}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
            ),
            _BotonCantidad(
              icono: LucideIcons.plus,
              color: AppColors.pierVerde,
              onTap: ocupada ? null : onIncrementar,
            ),
          ],
        ),
      ],
    );
  }

  Widget _subtotal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '\$${linea.subtotal.toStringAsFixed(0)}',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.pierDoradoOscuro),
        ),
        if (linea.tieneDescuento)
          Text(
            '-\$${linea.ahorroTotal.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: 11,
                color: AppColors.pierVerde,
                fontWeight: FontWeight.w600),
          ),
      ],
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
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icono, size: 16, color: color),
        ),
      ),
    );
  }
}
