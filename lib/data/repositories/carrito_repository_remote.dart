// lib/data/repositories/carrito_repository_remote.dart
//
// Implementación HTTP de CarritoRepository. Recibe el ApiClient por constructor:
// en la app, el ApiService único de lib/config/dependencies.dart; en
// pruebas, FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/carrito_repository.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/domain/models/cart_item_model.dart';

/// Implementación de [CarritoRepository] contra el backend vía [ApiClient].
class CarritoRepositoryRemote implements CarritoRepository {
  CarritoRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<List<CartItem>> obtener() async {
    final r = await _exigir(
      _api.getAuth(ApiConstants.carrito),
      'No se pudo cargar tu carrito',
    );
    final carrito = r['carrito'];
    final items = carrito is Map ? carrito['items'] : null;
    if (items is! List) return const [];
    return items
        .whereType<Map<dynamic, dynamic>>()
        .map((j) => CartItem.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  @override
  Future<void> agregar({
    required dynamic productoId,
    required int cantidad,
    required String tamano,
  }) =>
      _exigir(
        _api.postAuth(ApiConstants.carrito, {
          'producto_id': productoId,
          'cantidad': cantidad,
          'tamano': tamano,
        }),
        'No se pudo agregar al carrito',
      );

  @override
  Future<void> actualizarCantidad(String itemId, int cantidad) => _exigir(
        _api.putAuth(ApiConstants.carritoItem(itemId), {'cantidad': cantidad}),
        'No se pudo cambiar la cantidad',
      );

  @override
  Future<void> eliminarItem(String itemId) => _exigir(
        _api.deleteAuth(ApiConstants.carritoItem(itemId)),
        'No se pudo quitar el producto',
      );

  @override
  Future<void> vaciar() => _exigir(
        _api.deleteAuth(ApiConstants.carrito),
        'No se pudo vaciar el carrito',
      );

  /// La respuesta si trae success: true; si no, ApiException con su mensaje
  /// (o [porDefecto]).
  static Future<Map<String, dynamic>> _exigir(
    Future<Map<String, dynamic>> llamada,
    String porDefecto,
  ) async {
    final r = await llamada;
    if (r['success'] != true) {
      throw ApiException(r['message']?.toString() ?? porDefecto);
    }
    return r;
  }
}
