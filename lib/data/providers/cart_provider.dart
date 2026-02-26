import 'package:flutter/material.dart';
import '../models/product_model.dart';

class CartItem {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final String imageUrl;

  CartItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.imageUrl,
  });
}

class CartProvider with ChangeNotifier {
  Map<String, CartItem> _items = {};

  Map<String, CartItem> get items {
    return {..._items};
  }

  int get itemCount {
    return _items.length;
  }
  
  // Getter para el badge del icono de carrito
  int get totalQuantity {
    int total = 0;
    _items.forEach((key, item) {
      total += item.quantity;
    });
    return total;
  }

  // --- CÁLCULOS MONETARIOS ---

  // CORRECCIÓN 1: Renombrado de 'total' a 'totalAmount' para que coincida con CheckoutScreen
  double get totalAmount {
    double total = 0.0;
    _items.forEach((key, item) {
      total += item.price * item.quantity;
    });
    return total;
  }

  // Si necesitas mostrar el desglose de impuestos en el futuro, puedes usar esto:
  // (Asumiendo que el precio ya incluye IVA, lo desglosamos en vez de sumarlo)
  double get estimatedTax {
    return totalAmount * 0.16; 
  }

  // Verifica si un producto ya está en el carrito
  bool isInCart(String productId) {
    return _items.containsKey(productId);
  }

  // --- FUNCIONES DE GESTIÓN ---

  void addItem(Product product, [int quantity = 1]) {
    if (_items.containsKey(product.id)) {
      _items.update(
        product.id,
        (existingCartItem) => CartItem(
          id: existingCartItem.id,
          name: existingCartItem.name,
          price: existingCartItem.price,
          quantity: existingCartItem.quantity + quantity,
          imageUrl: existingCartItem.imageUrl,
        ),
      );
    } else {
      _items.putIfAbsent(
        product.id,
        () => CartItem(
          id: product.id,
          name: product.name,
          price: product.price,
          quantity: quantity,
          imageUrl: product.imageUrl,
        ),
      );
    }
    notifyListeners();
  }

  // Método para el botón de (-)
  void removeSingleItem(String productId) {
    if (!_items.containsKey(productId)) {
      return;
    }
    if (_items[productId]!.quantity > 1) {
      _items.update(
        productId,
        (existingCartItem) => CartItem(
          id: existingCartItem.id,
          name: existingCartItem.name,
          price: existingCartItem.price,
          quantity: existingCartItem.quantity - 1,
          imageUrl: existingCartItem.imageUrl,
        ),
      );
    } else {
      _items.remove(productId);
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  // CORRECCIÓN 2: Renombrado de 'clear' a 'clearCart' para coincidir con CheckoutScreen
  void clearCart() {
    _items = {};
    notifyListeners();
  }
}