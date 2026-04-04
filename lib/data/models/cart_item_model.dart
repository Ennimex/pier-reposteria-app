import 'product_model.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(
        json['producto'] as Map<String, dynamic>? ?? json,
      ),
      quantity: int.tryParse(json['cantidad']?.toString() ??
              json['quantity']?.toString() ??
              '1') ??
          1,
    );
  }

  double get subtotal => product.precio * quantity;
}