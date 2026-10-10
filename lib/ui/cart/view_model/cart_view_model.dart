// lib/ui/cart/view_model/cart_view_model.dart
//
// Estado de «Mi Carrito» (MVVM, Fase 5): la carga inicial (con error y
// reintento), cambiar cantidades, quitar líneas y vaciar. Las líneas viven en
// CartProvider, que comparten el catálogo, el detalle, el badge y el checkout;
// este ViewModel lo observa y devuelve a la vista el motivo de cada rechazo
// del backend. Mientras una línea espera respuesta no acepta otro cambio, para
// que las cantidades no lleguen al backend en desorden.
import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/domain/models/cart_item_model.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';

class CartViewModel extends ChangeNotifier {
  CartViewModel({
    required CartProvider carrito,
    required bool Function() sesionIniciada,
  })  : _carrito = carrito,
        _sesionIniciada = sesionIniciada {
    _carrito.addListener(_avisar);
  }

  final CartProvider _carrito;
  final bool Function() _sesionIniciada;
  final Set<String> _ocupadas = {};
  bool _cerrado = false;
  bool _cargando = true;
  String? _errorCarga;

  bool get cargando => _cargando;

  /// Por qué no se pudo cargar el carrito; solo cuando no hay nada que
  /// mostrar (si ya había líneas, se quedan en pantalla).
  String? get errorCarga => _carrito.itemCount == 0 ? _errorCarga : null;

  List<CartItem> get lineas => _carrito.items.values.toList();
  int get totalProductos => _carrito.totalQuantity;
  double get total => _carrito.totalAmount;
  double get totalOriginal => _carrito.totalOriginal;
  double get ahorro => _carrito.totalAhorro;
  bool get tieneDescuentos => _carrito.tieneDescuentos;

  /// La línea espera la respuesta de un cambio anterior.
  bool ocupada(CartItem linea) => _ocupadas.contains(linea.lineKey);

  /// Trae el carrito del backend. Sin sesión no hay carrito que pedir.
  Future<void> cargar() async {
    if (!_sesionIniciada()) {
      _cargando = false;
      notifyListeners();
      return;
    }
    _cargando = true;
    _errorCarga = null;
    notifyListeners();
    try {
      await _carrito.cargarDesdeBackend();
    } on ApiException catch (e) {
      _errorCarga = e.message;
    }
    if (_cerrado) return;
    _cargando = false;
    notifyListeners();
  }

  /// Una unidad más de [linea]. Devuelve el motivo si el backend la rechaza.
  Future<String?> incrementar(CartItem linea) => _cambiar(
      linea, () => _carrito.cambiarCantidad(linea.lineKey, linea.quantity + 1));

  /// Una unidad menos; con la última se quita la línea.
  Future<String?> decrementar(CartItem linea) => _cambiar(
      linea, () => _carrito.cambiarCantidad(linea.lineKey, linea.quantity - 1));

  Future<String?> eliminar(CartItem linea) =>
      _cambiar(linea, () => _carrito.removeItem(linea.lineKey));

  Future<String?> vaciar() => _carrito.clearCart();

  Future<String?> _cambiar(
    CartItem linea,
    Future<String?> Function() accion,
  ) async {
    if (!_ocupadas.add(linea.lineKey)) return null;
    notifyListeners();
    try {
      return await accion();
    } finally {
      _ocupadas.remove(linea.lineKey);
      _avisar();
    }
  }

  void _avisar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    _carrito.removeListener(_avisar);
    super.dispose();
  }
}
