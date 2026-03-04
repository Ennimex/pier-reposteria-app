import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../../data/providers/cart_provider.dart';
import '../../../data/providers/auth_provider.dart'; // PARA VALIDAR SESIÓN
import '../../screens/auth/login_screen.dart'; // PARA MANDAR AL LOGIN

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
            // IMAGEN
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      product.imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: Icon(Icons.cake, color: Colors.grey, size: 40)),
                      ),
                    ),
                  ),
                  if (product.popular)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.pierDorado,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Popular',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // INFO
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${product.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppColors.pierVerde,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      
                      // ESTE ES EL BOTÓN PROTEGIDO (CARD)
                      Consumer<CartProvider>(
                        builder: (context, cart, child) {
                          final isInCart = cart.isInCart(product.id);
                          return GestureDetector(
                            onTap: () {
                              // 1. Validamos sesión
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              if (!auth.isAuthenticated) {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                                return; // Cortamos la ejecución
                              }

                              // 2. Si está logueado, agregamos
                              cart.addItem(product);
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${product.name} agregado al carrito'),
                                  backgroundColor: AppColors.pierVerde,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isInCart ? AppColors.pierVerde : AppColors.pierVerde.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isInCart ? Icons.check : Icons.add_shopping_cart,
                                color: isInCart ? Colors.white : AppColors.pierVerde,
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