// lib/presentation/screens/client/cart/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/providers/cart_provider.dart';
import '../../../../data/models/product_model.dart';
import '../checkout/checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final cartItems = cart.items.values.toList();

    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Text('Mi Carrito',
                      style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  if (cartItems.isNotEmpty)
                    GestureDetector(
                      onTap: () => _showClearDialog(context, cart),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.2)),
                        ),
                        child: const Text('Vaciar',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),

            if (cartItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(children: [
                  const Icon(Icons.shopping_bag_outlined,
                      size: 13, color: AppColors.pierVerde),
                  const SizedBox(width: 5),
                  Text(
                    '${cart.totalQuantity} producto${cart.totalQuantity == 1 ? '' : 's'}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500),
                  ),
                ]),
              )
            else
              const SizedBox(height: 12),

            // ── CONTENIDO ────────────────────────────────────────
            Expanded(
              child: cartItems.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.separated(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: cartItems.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = cartItems[index];
                        return _buildCartItem(context, item, cart);
                      },
                    ),
            ),

            // ── RESUMEN ──────────────────────────────────────────
            if (cartItems.isNotEmpty)
              _buildSummary(context, cart),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(
      BuildContext context, CartItem item, CartProvider cart) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 26),
      ),
      onDismissed: (_) => cart.removeItem(item.id),
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
            // Imagen
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                item.imagenUrl,
                width: 76, height: 76,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 76, height: 76,
                  color: AppColors.pierArena,
                  child: const Icon(Icons.cake_outlined,
                      color: AppColors.pierVerde, size: 30),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.nombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('\$${item.precio.toStringAsFixed(0)} c/u',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  // Selector cantidad
                  Row(
                    children: [
                      _qtyBtn(
                        icon: item.quantity == 1
                            ? Icons.delete_outline_rounded
                            : Icons.remove_rounded,
                        color: item.quantity == 1
                            ? Colors.red
                            : AppColors.pierVerde,
                        onTap: () => cart.removeSingleItem(item.id),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        child: Text('${item.quantity}',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                      ),
                      _qtyBtn(
                        icon: Icons.add_rounded,
                        color: AppColors.pierVerde,
                        onTap: () => cart.addItem(Product(
                          id: item.id,
                          nombre: item.nombre,
                          precio: item.precio,
                          imagenUrl: item.imagenUrl,
                          descripcion: '',
                          categoria: '',
                        )),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Subtotal
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${(item.precio * item.quantity).toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.pierDoradoOscuro),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context, CartProvider cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: Column(
        children: [
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              Text(
                '\$${cart.totalAmount.toStringAsFixed(0)} MXN',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.pierVerde),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('IVA incluido',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[400])),
            ],
          ),
          const SizedBox(height: 16),

          // Botón checkout
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CheckoutScreen()),
              ),
              icon: const Icon(Icons.payment_rounded,
                  color: Colors.white, size: 20),
              label: const Text('Proceder al Pago',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pierVerde,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              color: AppColors.pierVerde.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shopping_bag_outlined,
                size: 50,
                color: AppColors.pierVerde.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          const Text('Tu carrito está vacío',
              style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('Agrega productos desde el catálogo\npara comenzar tu pedido.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 14, color: Colors.grey[500])),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.storefront_outlined,
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
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Vaciar carrito'),
        content: const Text(
            '¿Estás seguro que deseas eliminar todos los productos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              cart.clearCart();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, elevation: 0),
            child: const Text('Vaciar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}