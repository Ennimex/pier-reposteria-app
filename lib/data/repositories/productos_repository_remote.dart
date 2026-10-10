// lib/data/repositories/productos_repository_remote.dart
//
// Implementación HTTP de ProductosRepository. Recibe el ApiClient por constructor:
// en la app, el ApiService único de lib/config/dependencies.dart; en
// pruebas, FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/productos_repository.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';

/// Implementación de [ProductosRepository] contra el backend vía [ApiClient].
class ProductosRepositoryRemote implements ProductosRepository {
  ProductosRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> listar() => _api.get(ApiConstants.productos);

  @override
  Future<Map<String, dynamic>> detalle(String id) => _api.get(ApiConstants.productoById(id));

  @override
  Future<Map<String, dynamic>> categorias() => _api.get(ApiConstants.categorias);

  @override
  Future<List<String>> nombresDeCategorias() async {
    final r = await categorias();
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudieron cargar las categorías',
      );
    }
    final data = r['categorias'] ?? r['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<dynamic, dynamic>>()
        .map((c) => (c['nombre'] ?? c['name'] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .toList();
  }

  @override
  Future<Map<String, dynamic>> filtros() => _api.get(ApiConstants.filtros);

  @override
  Future<Map<String, dynamic>> opcionesDeCategoria(String categoriaId) =>
      _api.get(ApiConstants.categoriaOpciones(categoriaId));

  @override
  Future<Map<String, dynamic>> recomendaciones(String productoId) =>
      _api.get(ApiConstants.recomendaciones(productoId));

  @override
  Future<Map<String, dynamic>> promocionesActivas() => _api.get(ApiConstants.promocionesActivas);
}
