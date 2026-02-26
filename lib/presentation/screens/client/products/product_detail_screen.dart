import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/product_model.dart';
import '../../../../data/providers/cart_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({
    Key? key,
    required this.product,
  }) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1; // Estado local para la cantidad a agregar

  void _incrementQuantity() {
    setState(() {
      _quantity++;
    });
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
      });
    }
  }

  void _addToCart() {
    // 1. Obtenemos el provider (sin escuchar cambios, solo para ejecutar la función)
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    
    // 2. Agregamos el producto
    cartProvider.addItem(widget.product, _quantity);

    // 3. Mostramos confirmación visual
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('¡Agregaste $_quantity ${widget.product.name} al carrito!'),
        backgroundColor: AppColors.pierVerde,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'DESHACER',
          textColor: AppColors.pierDorado,
          onPressed: () {
            cartProvider.removeSingleItem(widget.product.id);
          },
        ),
      ),
    );
    
    // Opcional: Si quieres que regrese al menú al agregar, descomenta esto:
    // Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // AppBar transparente para que la imagen luzca
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.pierVerde),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Imagen del Producto (Hero para animación suave)
            Hero(
              tag: widget.product.id,
              child: Container(
                height: 350,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.pierArena.withOpacity(0.3),
                  image: DecorationImage(
                    image: NetworkImage(widget.product.imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            
            // 2. Panel de Detalles (Bordes redondeados hacia arriba)
            Container(
              transform: Matrix4.translationValues(0.0, -40.0, 0.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Barra pequeña decorativa
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Nombre y Precio
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.product.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '\$${widget.product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.pierDorado, // Uso del dorado para el precio
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),

                  // Descripción
                  Text(
                    widget.product.description,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Selector de Cantidad
                  Row(
                    children: [
                      const Text(
                        'Cantidad',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      _buildQuantityButton(Icons.remove, _decrementQuantity),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '$_quantity',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildQuantityButton(Icons.add, _incrementQuantity),
                    ],
                  ),
                  
                  const SizedBox(height: 40), // Espacio extra abajo
                ],
              ),
            ),
          ],
        ),
      ),
      
      // Botón de Agregar (Sticky en la parte inferior)
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _addToCart,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pierVerde,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Agregar al Carrito - \$${(widget.product.price * _quantity).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: AppColors.pierVerde),
        onPressed: onTap,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }
}