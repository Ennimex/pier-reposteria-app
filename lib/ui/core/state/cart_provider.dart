// lib/ui/core/state/cart_provider.dart
//
// Carrito compartido de la app (catálogo, detalle, badge, checkout y la
// pantalla del carrito). Los cambios se ven al instante y se confirman con el
// backend vía CarritoRepository; si el backend los rechaza se revierten y la
// acción devuelve el motivo («Solo quedan 2 unidades») para que la vista lo
// muestre. Devuelve null cuando todo salió bien.
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/carrito_repository.dart';
import 'package:pier_pasteleria/domain/models/cart_item_model.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/utils/logger.dart';

class CartProvider with ChangeNotifier {
  CartProvider({required CarritoRepository repo}) : _repo = repo;

  final CarritoRepository _repo;
  Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => {..._items};
  int get itemCount => _items.length;
  int get totalQuantity =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  // ✅ Total con descuentos ya aplicados
  double get totalAmount =>
      _items.values.fold<double>(0, (sum, item) => sum + item.subtotal);

  // ✅ Total original sin descuentos (para mostrar tachado)
  double get totalOriginal =>
      _items.values.fold<double>(0, (sum, item) => sum + item.precioOriginal * item.quantity);

  // ✅ Ahorro total del carrito
  double get totalAhorro => totalOriginal - totalAmount;

  // ✅ Hay algún descuento activo en el carrito
  bool get tieneDescuentos =>
      _items.values.any((item) => item.tieneDescuento);

  // Verdadero si el producto está en el carrito en CUALQUIER tamaño.
  bool isInCart(String productId) =>
      _items.values.any((item) => item.id == productId);

  // ── Cargar carrito desde el backend ──────────────────────────────
  /// Trae las líneas del backend (precios ya con descuento). Si falla lanza
  /// ApiException y conserva lo que ya tenía.
  Future<void> cargarDesdeBackend() async {
    final lineas = await _repo.obtener();
    // Key por línea (producto + tamaño): chico y grande coexisten.
    _items = {for (final linea in lineas) linea.lineKey: linea};
    notifyListeners();
    PierLog.info('Carrito cargado: ${_items.length} items');
  }

  // ── Agregar al carrito (local + backend) ─────────────────────────
  // [tamano] 'chico'|'grande'; [precioUnitario] precio base del tamaño elegido
  // (solo para el optimista local; el backend recalcula con descuento al recargar).
  Future<String?> addItem(Product product,
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
        quantity: quantity,
        imagenUrl: product.imagenUrl,
        tamano: tamano,
      );
    }
    notifyListeners();

    try {
      await _repo.agregar(
        productoId: int.tryParse(product.id) ?? product.id,
        cantidad: quantity,
        tamano: tamano,
      );
    } on ApiException catch (e) {
      PierLog.error('Error al agregar al carrito backend: ${e.message}');
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
      return e.message;
    }
    // Recargar para obtener carritoItemId + descuentos actualizados
    await _recargar();
    return null;
  }

  // ── Cambiar cantidad (local + backend) ───────────────────────────
  /// Deja la línea [lineKey] (item.lineKey: producto + tamaño) en [cantidad];
  /// menos de 1 la elimina. Si el backend la rechaza (stock) vuelve a la
  /// cantidad anterior.
  Future<String?> cambiarCantidad(String lineKey, int cantidad) async {
    final item = _items[lineKey];
    if (item == null) return null;
    if (cantidad < 1) return removeItem(lineKey);
    PierLog.info('Cambiando cantidad: $lineKey -> $cantidad');

    _items[lineKey] = item.copyWith(quantity: cantidad);
    notifyListeners();

    final itemId = item.carritoItemId;
    if (itemId == null) return null;
    try {
      await _repo.actualizarCantidad(itemId, cantidad);
      return null;
    } on ApiException catch (e) {
      if (_items.containsKey(lineKey)) {
        _items[lineKey] = item;
        notifyListeners();
      }
      return e.message;
    }
  }

  // ── Eliminar item (local + backend) ──────────────────────────────
  // [lineKey] es item.lineKey (producto + tamaño).
  Future<String?> removeItem(String lineKey) async {
    final item = _items[lineKey];
    if (item == null) return null;
    PierLog.info('Eliminando del carrito: $lineKey');

    _items.remove(lineKey);
    notifyListeners();

    final itemId = item.carritoItemId;
    if (itemId == null) return null;
    try {
      await _repo.eliminarItem(itemId);
      return null;
    } on ApiException catch (e) {
      _items[lineKey] = item;
      notifyListeners();
      return e.message;
    }
  }

  // ── Vaciar carrito (local + backend) ─────────────────────────────
  /// Si el backend no lo vacía, recarga lo que de verdad quedó.
  Future<String?> clearCart() async {
    PierLog.info('Vaciando carrito');
    _items = {};
    notifyListeners();
    try {
      await _repo.vaciar();
      return null;
    } on ApiException catch (e) {
      await _recargar();
      return e.message;
    }
  }

  // ── Limpiar solo en memoria (logout) ─────────────────────────────
  // A diferencia de clearCart, NO borra el carrito del backend: ahí debe
  // persistir para cuando el usuario vuelva a iniciar sesión. Solo se
  // deja de mostrar en el dispositivo.
  void limpiarLocal() {
    _items = {};
    notifyListeners();
  }

  /// Recarga sin fallar: si el backend no responde se queda lo que hay.
  Future<void> _recargar() async {
    try {
      await cargarDesdeBackend();
    } on ApiException catch (e) {
      PierLog.error('No se pudo recargar el carrito: ${e.message}');
    }
  }
}
