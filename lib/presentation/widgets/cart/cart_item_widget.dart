import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/cart_item_model.dart';

class CartItemWidget extends StatelessWidget {
  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const CartItemWidget({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Imagen del producto
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.product.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[300],
                    child: const Icon(Icons.cake, size: 40),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),

            // Información del producto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.product.category,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${item.product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.pierVerde,
                    ),
                  ),
                ],
              ),
            ),

            // Controles de cantidad
            Column(
              children: [
                // Botón eliminar
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                  iconSize: 20,
                ),
                const SizedBox(height: 8),

                // Contador
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botón decrementar
                      InkWell(
                        onTap: onDecrement,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.remove,
                            size: 16,
                            color: AppColors.pierVerde,
                          ),
                        ),
                      ),

                      // Cantidad
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          item.quantity.toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // Botón incrementar
                      InkWell(
                        onTap: onIncrement,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.add,
                            size: 16,
                            color: AppColors.pierVerde,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}