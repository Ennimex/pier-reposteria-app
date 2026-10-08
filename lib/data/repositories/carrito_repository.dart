// lib/data/repositories/carrito_repository.dart
//
// Única puerta a los datos de el carrito del cliente (el backend es la fuente de verdad). En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Recibe un ApiClient por constructor: en la app es ApiService, en pruebas
// FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';

class CarritoRepository {
  final ApiClient _api;
  CarritoRepository({ApiClient? api}) : _api = api ?? ApiService();

  /// GET /carrito
  Future<Map<String, dynamic>> obtener() => _api.getAuth(ApiConstants.carrito);

  /// POST /carrito. El backend separa líneas por tamaño y recalcula el
  /// precio unitario; productoId puede ir como int o String.
  Future<Map<String, dynamic>> agregar({
    required dynamic productoId,
    required int cantidad,
    required String tamano,
  }) =>
      _api.postAuth(ApiConstants.carrito, {
        'producto_id': productoId,
        'cantidad': cantidad,
        'tamano': tamano,
      });

  /// PUT /carrito/:itemId
  Future<Map<String, dynamic>> actualizarCantidad(String itemId, int cantidad) =>
      _api.putAuth(ApiConstants.carritoItem(itemId), {'cantidad': cantidad});

  /// DELETE /carrito/:itemId
  Future<Map<String, dynamic>> eliminarItem(String itemId) =>
      _api.deleteAuth(ApiConstants.carritoItem(itemId));

  /// DELETE /carrito (vaciar)
  Future<Map<String, dynamic>> vaciar() => _api.deleteAuth(ApiConstants.carrito);
}
