// lib/data/repositories/favoritos_repository_remote.dart
//
// Implementación HTTP de FavoritosRepository. Recibe el ApiClient por constructor:
// en la app, el ApiService único de lib/config/dependencies.dart; en
// pruebas, FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/favoritos_repository.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';

/// Implementación de [FavoritosRepository] contra el backend vía [ApiClient].
class FavoritosRepositoryRemote implements FavoritosRepository {
  FavoritosRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> ids() => _api.getAuth(ApiConstants.favoritosIds);

  @override
  Future<List<String>> listarIds() async {
    final r = await ids();
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudieron cargar tus favoritos',
      );
    }
    final data = r['ids'];
    if (data is! List) return const [];
    return data.map((id) => id.toString()).toList();
  }

  @override
  Future<Map<String, dynamic>> listar() => _api.getAuth(ApiConstants.favoritos);

  @override
  Future<List<Product>> listarProductos() async {
    final r = await listar();
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudieron cargar tus favoritos',
      );
    }
    final data = r['favoritos'] ?? r['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<dynamic, dynamic>>()
        .map((j) => Product.fromJson({...Map<String, dynamic>.from(j), 'activo': true}))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> agregar(String productoId) =>
      _api.postAuth(ApiConstants.favoritoById(productoId), {});

  @override
  Future<Map<String, dynamic>> quitar(String productoId) =>
      _api.deleteAuth(ApiConstants.favoritoById(productoId));

  @override
  Future<void> quitarFavorito(String productoId) async {
    final r = await quitar(productoId);
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'Error al quitar de favoritos',
      );
    }
  }
}
