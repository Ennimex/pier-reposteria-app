// lib/data/providers/cart_provider.dart
import 'package:flutter/material.dart';
import '../../core/utils/logger.dart';
import '../../core/services/api_service.dart';
import '../models/product_model.dart';

class CartItem {
  final String id;          // producto_id
  final String? carritoItemId; // id en tblcarrito_items (para update/delete)
  final String nombre;
  final int quantity;
  final double precio;
  final String imagenUrl;

  CartItem({
    required this.id,
    this.carritoItemId,
    required this.nombre,
    required this.quantity,
    required this.precio,
    required this.imagenUrl,
  });

  CartItem copyWith({int? quantity, String? carritoItemId}) {
    return CartItem(
      id: id,
      carritoItemId: carritoItemId ?? this.carritoItemId,
      nombre: nombre,
      precio: precio,
      quantity: quantity ?? this.quantity,
      imagenUrl: imagenUrl,
    );
  }
}

class CartProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  Map<String, CartItem> _items = {};
  bool _synced = false;

  Map<String, CartItem> get items => {..._items};
  int get itemCount => _items.length;
  int get totalQuantity =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);
  double get totalAmount =>
      _items.values.fold(0.0, (sum, item) => sum + item.precio * item.quantity);
  bool isInCart(String productId) => _items.containsKey(productId);

  // ── Cargar carrito desde el backend ──────────────────────────────
  Future<void> cargarDesdeBackend() async {
    final result = await _api.getAuth('/carrito');
    if (result['success'] != true) return;

    final carrito = result['carrito'] as Map<String, dynamic>?;
    final items = List<Map<String, dynamic>>.from(carrito?['items'] ?? []);

    _items = {};
    for (final item in items) {
      final productoId = item['producto_id']?.toString() ?? '';
      _items[productoId] = CartItem(
        id: productoId,
        carritoItemId: item['carrito_item_id']?.toString(),
        nombre: item['nombre'] ?? '',
        precio: double.tryParse(item['precio_unitario']?.toString() ?? '0') ?? 0,
        quantity: int.tryParse(item['cantidad']?.toString() ?? '1') ?? 1,
        imagenUrl: item['imagen_url'] ?? '',
      );
    }
    _synced = true;
    notifyListeners();
    PierLog.info('Carrito cargado: ${_items.length} items');
  }

  // ── Agregar al carrito (local + backend) ─────────────────────────
  Future<void> addItem(Product product, [int quantity = 1]) async {
    PierLog.info('Agregando al carrito: ${product.nombre} (x$quantity)');

    // Actualizar localmente primero (optimistic)
    if (_items.containsKey(product.id)) {
      _items.update(
        product.id,
        (e) => e.copyWith(quantity: e.quantity + quantity),
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

    // Persistir en backend
    final result = await _api.postAuth('/carrito', {
      'producto_id': int.tryParse(product.id) ?? product.id,
      'cantidad': quantity,
      'tamano': 'chico',
    });

    if (result['success'] != true) {
      PierLog.error('Error al agregar al carrito backend: ${result['message']}');
      // Revertir si falló
      if (_items[product.id]?.quantity == quantity) {
        _items.remove(product.id);
      } else if (_items.containsKey(product.id)) {
        _items.update(
          product.id,
          (e) => e.copyWith(quantity: e.quantity - quantity),
        );
      }
      notifyListeners();
    } else {
      // Recargar para obtener carritoItemId actualizado
      await cargarDesdeBackend();
    }
  }

  // ── Reducir cantidad (local + backend) ───────────────────────────
  Future<void> removeSingleItem(String productId) async {
    if (!_items.containsKey(productId)) return;
    final item = _items[productId]!;
    PierLog.info('Reduciendo cantidad: $productId');

    if (item.quantity > 1) {
      _items.update(productId, (e) => e.copyWith(quantity: e.quantity - 1));
      notifyListeners();

      if (item.carritoItemId != null) {
        await _api.putAuth(
          '/carrito/${item.carritoItemId}',
          {'cantidad': item.quantity - 1},
        );
      }
    } else {
      await removeItem(productId);
    }
  }

  // ── Eliminar item (local + backend) ──────────────────────────────
  Future<void> removeItem(String productId) async {
    final item = _items[productId];
    if (item == null) return;
    PierLog.info('Eliminando del carrito: $productId');

    _items.remove(productId);
    notifyListeners();

    if (item.carritoItemId != null) {
      await _api.deleteAuth('/carrito/${item.carritoItemId}');
    }
  }

  // ── Vaciar carrito (local + backend) ─────────────────────────────
  Future<void> clearCart() async {
    PierLog.info('Vaciando carrito');
    _items = {};
    _synced = false;
    notifyListeners();
    await _api.deleteAuth('/carrito');
  }
}