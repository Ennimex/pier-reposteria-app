// lib/data/providers/cart_provider.dart
import 'package:flutter/material.dart';
import '../models/product_model.dart';

class CartItem {
  final String id;
  final String nombre;
  final int quantity;
  final double precio;
  final String imagenUrl;

  CartItem({
    required this.id,
    required this.nombre,
    required this.quantity,
    required this.precio,
    required this.imagenUrl,
  });

  CartItem copyWith({int? quantity}) {
    return CartItem(
      id: id,
      nombre: nombre,
      precio: precio,
      quantity: quantity ?? this.quantity,
      imagenUrl: imagenUrl,
    );
  }
}

class CartProvider with ChangeNotifier {
  Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => {..._items};

  int get itemCount => _items.length;

  int get totalQuantity {
    return _items.values
        .fold(0, (sum, item) => sum + item.quantity);
  }

  double get totalAmount {
    return _items.values
        .fold(0.0, (sum, item) => sum + item.precio * item.quantity);
  }

  bool isInCart(String productId) => _items.containsKey(productId);

  void addItem(Product product, [int quantity = 1]) {
    if (_items.containsKey(product.id)) {
      _items.update(
        product.id,
        (existing) => existing.copyWith(
            quantity: existing.quantity + quantity),
      );
    } else {
      _items[product.id] = CartItem(
        id: product.id,
        nombre: product.nombre,
        precio: product.precio,
        quantity: quantity,
        imagenUrl: product.imagenUrl,
      );
    }
    notifyListeners();
  }

  void removeSingleItem(String productId) {
    if (!_items.containsKey(productId)) return;
    if (_items[productId]!.quantity > 1) {
      _items.update(productId,
          (existing) => existing.copyWith(quantity: existing.quantity - 1));
    } else {
      _items.remove(productId);
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void clearCart() {
    _items = {};
    notifyListeners();
  }
}