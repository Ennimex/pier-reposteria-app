// lib/data/repositories/direcciones_repository_remote.dart
//
// Implementación HTTP de DireccionesRepository. Recibe el ApiClient por constructor:
// en la app, el ApiService único de lib/config/dependencies.dart; en
// pruebas, FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/direcciones_repository.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/domain/models/direccion_model.dart';
import 'package:pier_pasteleria/domain/models/zona_colonia.dart';

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

  @override
  Future<List<DireccionCliente>> listarDirecciones() async {
    final r = await listar();
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudieron cargar tus direcciones',
      );
    }
    final data = r['direcciones'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(DireccionCliente.fromJson)
        .toList();
  }

  @override
  Future<DireccionCliente> guardarDireccion(
    Map<String, dynamic> datos, {
    String? id,
  }) async {
    final r = id == null ? await crear(datos) : await actualizar(id, datos);
    final direccion = r['direccion'];
    if (r['success'] != true || direccion is! Map) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudo guardar la dirección',
      );
    }
    return DireccionCliente.fromJson(Map<String, dynamic>.from(direccion));
  }

  @override
  Future<void> eliminarDireccion(String id) async {
    final r = await eliminar(id);
    if (r['success'] != true) {
      throw ApiException(r['message']?.toString() ?? 'No se pudo eliminar');
    }
  }

  @override
  Future<List<ZonaColonia>> listarColonias() async {
    final r = await colonias();
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudieron cargar las colonias',
      );
    }
    final data = r['colonias'];
    if (data is! List) return const [];
    return data.whereType<Map<dynamic, dynamic>>().map(ZonaColonia.fromJson).toList();
  }
}
