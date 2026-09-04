// lib/ui/core/ui/product_card.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/auth/widgets/login_screen.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                    child: Image.network(
                      product.imagenUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                            child: Icon(LucideIcons.cake,
                                color: Colors.grey, size: 40)),
                      ),
                    ),
                  ),
                  if (product.popular)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.pierDorado,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Popular',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${product.precio.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: AppColors.pierVerde,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Consumer<CartProvider>(
                        builder: (context, cart, _) {
                          final isInCart =
                              cart.isInCart(product.id);
                          return GestureDetector(
                            onTap: () {
                              final auth =
                                  Provider.of<AuthProvider>(
                                      context,
                                      listen: false);
                              if (!auth.isAuthenticated) {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const LoginScreen()));
                                return;
                              }
                              cart.addItem(product);
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(SnackBar(
                                  content: Text(
                                      '${product.nombre} agregado'),
                                  backgroundColor:
                                      AppColors.pierVerde,
                                  duration:
                                      const Duration(seconds: 1),
                                ));
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isInCart
                                    ? AppColors.pierVerde
                                    : AppColors.pierVerde
                                        .withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isInCart
                                    ? LucideIcons.check
                                    : LucideIcons.shoppingCart,
                                color: isInCart
                                    ? Colors.white
                                    : AppColors.pierVerde,
                                size: 18,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}