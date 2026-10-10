// lib/data/repositories/direcciones_repository_remote.dart
//
// Implementación HTTP de DireccionesRepository. Recibe el ApiClient por constructor:
// en la app, el ApiService único de lib/config/dependencies.dart; en
// pruebas, FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/direcciones_repository.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';

/// Implementación de [DireccionesRepository] contra el backend vía [ApiClient].
class DireccionesRepositoryRemote implements DireccionesRepository {
  DireccionesRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> listar() => _api.getAuth(ApiConstants.direcciones);

  @override
  Future<Map<String, dynamic>> crear(Map<String, dynamic> body) =>
      _api.postAuth(ApiConstants.direcciones, body);

  @override
  Future<Map<String, dynamic>> actualizar(String id, Map<String, dynamic> body) =>
      _api.putAuth(ApiConstants.direccionById(id), body);

  @override
  Future<Map<String, dynamic>> eliminar(String id) =>
      _api.deleteAuth(ApiConstants.direccionById(id));

  @override
  Future<Map<String, dynamic>> colonias() => _api.get(ApiConstants.zonasColonias);
}
