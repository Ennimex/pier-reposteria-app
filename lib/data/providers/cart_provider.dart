// lib/data/providers/cart_provider.dart
import 'package:flutter/material.dart';
import '../../core/utils/logger.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../models/product_model.dart';

class CartItem {
  final String id;              // producto_id
  final String? carritoItemId;  // id en tblcarrito_items
  final String nombre;
  final int quantity;
  final double precio;          // precio con descuento ya aplicado (precio_unitario del backend)
  final double precioOriginal;  // precio sin descuento (precio_original del backend)
  final String imagenUrl;
  final bool tieneDescuento;
  final String? promoNombre;    // nombre_temporada de la promoción

  CartItem({
    required this.id,
    this.carritoItemId,
    required this.nombre,
    required this.quantity,
    required this.precio,
    double? precioOriginal,
    required this.imagenUrl,
    this.tieneDescuento = false,
    this.promoNombre,
  }) : precioOriginal = precioOriginal ?? precio;

  CartItem copyWith({
    int? quantity,
    String? carritoItemId,
    double? precio,
    double? precioOriginal,
    bool? tieneDescuento,
    String? promoNombre,
  }) {
    return CartItem(
      id: id,
      carritoItemId: carritoItemId ?? this.carritoItemId,
      nombre: nombre,
      precio: precio ?? this.precio,
      precioOriginal: precioOriginal ?? this.precioOriginal,
      quantity: quantity ?? this.quantity,
      imagenUrl: imagenUrl,
      tieneDescuento: tieneDescuento ?? this.tieneDescuento,
      promoNombre: promoNombre ?? this.promoNombre,
    );
  }

  // ✅ Subtotal calculado con precio ya descontado
  double get subtotal => precio * quantity;

  // ✅ Ahorro total en este item
  double get ahorroTotal =>
      tieneDescuento ? (precioOriginal - precio) * quantity : 0.0;
}

class CartProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  Map<String, CartItem> _items = {};
  bool _synced = false;

  Map<String, CartItem> get items => {..._items};
  int get itemCount => _items.length;
  int get totalQuantity =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  // ✅ Total con descuentos ya aplicados
  double get totalAmount =>
      _items.values.fold(0.0, (sum, item) => sum + item.subtotal);

  // ✅ Total original sin descuentos (para mostrar tachado)
  double get totalOriginal =>
      _items.values.fold(0.0, (sum, item) => sum + item.precioOriginal * item.quantity);

  // ✅ Ahorro total del carrito
  double get totalAhorro => totalOriginal - totalAmount;

  // ✅ Hay algún descuento activo en el carrito
  bool get tieneDescuentos =>
      _items.values.any((item) => item.tieneDescuento);

  bool isInCart(String productId) => _items.containsKey(productId);

  // ── Cargar carrito desde el backend ──────────────────────────────
  Future<void> cargarDesdeBackend() async {
    final result = await _api.getAuth(ApiConstants.carrito);
    if (result['success'] != true) return;

    final carrito = result['carrito'] as Map<String, dynamic>?;
    final items = List<Map<String, dynamic>>.from(carrito?['items'] ?? []);

    _items = {};
    for (final item in items) {
      final productoId = item['producto_id']?.toString() ?? '';

      // ✅ NUEVO: precio_unitario ya viene con descuento del backend
      final precioFinal = double.tryParse(
              item['precio_unitario']?.toString() ?? '0') ?? 0;

      // ✅ NUEVO: precio_original es el precio sin descuento
      final precioOriginal = double.tryParse(
              item['precio_original']?.toString() ?? '0') ?? precioFinal;

      _items[productoId] = CartItem(
        id: productoId,
        carritoItemId: item['carrito_item_id']?.toString(),
        nombre: item['nombre'] ?? '',
        precio: precioFinal,
        precioOriginal: precioOriginal,
        quantity: int.tryParse(item['cantidad']?.toString() ?? '1') ?? 1,
        imagenUrl: item['imagen_url'] ?? '',
        // ✅ NUEVO: tiene_descuento del backend
        tieneDescuento: item['tiene_descuento'] == true,
        promoNombre: item['promo_nombre']?.toString(),
      );
    }
    _synced = true;
    notifyListeners();
    PierLog.info('Carrito cargado: ${_items.length} items');
  }

  // ── Agregar al carrito (local + backend) ─────────────────────────
  Future<void> addItem(Product product, [int quantity = 1]) async {
    PierLog.info('Agregando al carrito: ${product.nombre} (x$quantity)');

    // Actualizar localmente primero (optimistic — sin descuento aún)
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
        precioOriginal: product.precio,
        quantity: quantity,
        imagenUrl: product.imagenUrl,
      );
    }
    notifyListeners();

    final result = await _api.postAuth(ApiConstants.carrito, {
      'producto_id': int.tryParse(product.id) ?? product.id,
      'cantidad': quantity,
      'tamano': 'chico',
    });

    if (result['success'] != true) {
      PierLog.error(
          'Error al agregar al carrito backend: ${result['message']}');
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
      // Recargar para obtener carritoItemId + descuentos actualizados
      await cargarDesdeBackend();
    }
  }

  // ── Reducir cantidad (local + backend) ───────────────────────────
  Future<void> removeSingleItem(String productId) async {
    if (!_items.containsKey(productId)) return;
    final item = _items[productId]!;
    PierLog.info('Reduciendo cantidad: $productId');

    if (item.quantity > 1) {
      _items.update(
          productId, (e) => e.copyWith(quantity: e.quantity - 1));
      notifyListeners();

      if (item.carritoItemId != null) {
        await _api.putAuth(
          ApiConstants.carritoItem(item.carritoItemId!),
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
      await _api.deleteAuth(ApiConstants.carritoItem(item.carritoItemId!));
    }
  }

  // ── Vaciar carrito (local + backend) ─────────────────────────────
  Future<void> clearCart() async {
    PierLog.info('Vaciando carrito');
    _items = {};
    _synced = false;
    notifyListeners();
    await _api.deleteAuth(ApiConstants.carrito);
  }
}