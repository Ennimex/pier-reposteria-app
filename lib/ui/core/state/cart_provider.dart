// lib/ui/core/state/cart_provider.dart
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:pier_pasteleria/data/repositories/carrito_repository.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';

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
  final String tamano;          // 'chico' | 'grande' — el backend cobra según esto

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
    this.tamano = 'chico',
  }) : precioOriginal = precioOriginal ?? precio;

  // Clave única de línea: un mismo producto en chico y grande son dos líneas.
  String get lineKey => '${id}_$tamano';

  CartItem copyWith({
    int? quantity,
    String? carritoItemId,
    double? precio,
    double? precioOriginal,
    bool? tieneDescuento,
    String? promoNombre,
    String? tamano,
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
      tamano: tamano ?? this.tamano,
    );
  }

  // ✅ Subtotal calculado con precio ya descontado
  double get subtotal => precio * quantity;

  // ✅ Ahorro total en este item
  double get ahorroTotal =>
      tieneDescuento ? (precioOriginal - precio) * quantity : 0.0;
}

class CartProvider with ChangeNotifier {
  final CarritoRepository _repo;

  CartProvider({CarritoRepository? repo})
      : _repo = repo ?? CarritoRepository();
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

  // Verdadero si el producto está en el carrito en CUALQUIER tamaño.
  bool isInCart(String productId) =>
      _items.values.any((item) => item.id == productId);

  // ── Cargar carrito desde el backend ──────────────────────────────
  Future<void> cargarDesdeBackend() async {
    final result = await _repo.obtener();
    if (result['success'] != true) return;

    final carrito = result['carrito'] as Map<String, dynamic>?;
    final items = List<Map<String, dynamic>>.from(carrito?['items'] ?? []);

    _items = {};
    for (final item in items) {
      final productoId = item['producto_id']?.toString() ?? '';
      final tamano = item['tamano']?.toString() ?? 'chico';

      // ✅ NUEVO: precio_unitario ya viene con descuento del backend
      final precioFinal = double.tryParse(
              item['precio_unitario']?.toString() ?? '0') ?? 0;

      // ✅ NUEVO: precio_original es el precio sin descuento
      final precioOriginal = double.tryParse(
              item['precio_original']?.toString() ?? '0') ?? precioFinal;

      // Key por línea (producto + tamaño): chico y grande coexisten.
      _items['${productoId}_$tamano'] = CartItem(
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
        tamano: tamano,
      );
    }
    _synced = true;
    notifyListeners();
    PierLog.info('Carrito cargado: ${_items.length} items');
  }

  // ── Agregar al carrito (local + backend) ─────────────────────────
  // [tamano] 'chico'|'grande'; [precioUnitario] precio base del tamaño elegido
  // (solo para el optimista local; el backend recalcula con descuento al recargar).
  Future<void> addItem(Product product,
      [int quantity = 1,
      String tamano = 'chico',
      double? precioUnitario]) async {
    PierLog.info('Agregando al carrito: ${product.nombre} ($tamano x$quantity)');

    final key = '${product.id}_$tamano';
    final precio = precioUnitario ?? product.precio;

    // Actualizar localmente primero (optimistic — sin descuento aún)
    if (_items.containsKey(key)) {
      _items.update(
        key,
        (e) => e.copyWith(quantity: e.quantity + quantity),
      );
    } else {
      _items[key] = CartItem(
        id: product.id,
        nombre: product.nombre,
        precio: precio,
        precioOriginal: precio,
        quantity: quantity,
        imagenUrl: product.imagenUrl,
        tamano: tamano,
      );
    }
    notifyListeners();

    final result = await _repo.agregar(
      productoId: int.tryParse(product.id) ?? product.id,
      cantidad: quantity,
      tamano: tamano,
    );

    if (result['success'] != true) {
      PierLog.error(
          'Error al agregar al carrito backend: ${result['message']}');
      // Revertir si falló
      final current = _items[key];
      if (current != null) {
        if (current.quantity <= quantity) {
          _items.remove(key);
        } else {
          _items.update(
            key,
            (e) => e.copyWith(quantity: e.quantity - quantity),
          );
        }
      }
      notifyListeners();
    } else {
      // Recargar para obtener carritoItemId + descuentos actualizados
      await cargarDesdeBackend();
    }
  }

  // ── Reducir cantidad (local + backend) ───────────────────────────
  // [lineKey] es item.lineKey (producto + tamaño).
  Future<void> removeSingleItem(String lineKey) async {
    if (!_items.containsKey(lineKey)) return;
    final item = _items[lineKey]!;
    PierLog.info('Reduciendo cantidad: $lineKey');

    if (item.quantity > 1) {
      _items.update(
          lineKey, (e) => e.copyWith(quantity: e.quantity - 1));
      notifyListeners();

      if (item.carritoItemId != null) {
        await _repo.actualizarCantidad(
            item.carritoItemId!, item.quantity - 1);
      }
    } else {
      await removeItem(lineKey);
    }
  }

  // ── Eliminar item (local + backend) ──────────────────────────────
  // [lineKey] es item.lineKey (producto + tamaño).
  Future<void> removeItem(String lineKey) async {
    final item = _items[lineKey];
    if (item == null) return;
    PierLog.info('Eliminando del carrito: $lineKey');

    _items.remove(lineKey);
    notifyListeners();

    if (item.carritoItemId != null) {
      await _repo.eliminarItem(item.carritoItemId!);
    }
  }

  // ── Vaciar carrito (local + backend) ─────────────────────────────
  Future<void> clearCart() async {
    PierLog.info('Vaciando carrito');
    _items = {};
    _synced = false;
    notifyListeners();
    await _repo.vaciar();
  }

  // ── Limpiar solo en memoria (logout) ─────────────────────────────
  // A diferencia de clearCart, NO borra el carrito del backend: ahí debe
  // persistir para cuando el usuario vuelva a iniciar sesión. Solo se
  // deja de mostrar en el dispositivo.
  void limpiarLocal() {
    _items = {};
    _synced = false;
    notifyListeners();
  }
}