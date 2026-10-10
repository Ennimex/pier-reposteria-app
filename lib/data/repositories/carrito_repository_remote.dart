// lib/data/repositories/carrito_repository_remote.dart
//
// Implementación HTTP de CarritoRepository. Recibe el ApiClient por constructor:
// en la app, el ApiService único de lib/config/dependencies.dart; en
// pruebas, FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/carrito_repository.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';

/// Implementación de [CarritoRepository] contra el backend vía [ApiClient].
class CarritoRepositoryRemote implements CarritoRepository {
  CarritoRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> obtener() => _api.getAuth(ApiConstants.carrito);

  @override
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

  @override
  Future<Map<String, dynamic>> actualizarCantidad(String itemId, int cantidad) =>
      _api.putAuth(ApiConstants.carritoItem(itemId), {'cantidad': cantidad});

  @override
  Future<Map<String, dynamic>> eliminarItem(String itemId) =>
      _api.deleteAuth(ApiConstants.carritoItem(itemId));

  @override
  Future<Map<String, dynamic>> vaciar() => _api.deleteAuth(ApiConstants.carrito);
}
