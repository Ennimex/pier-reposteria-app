// lib/data/repositories/favoritos_repository.dart
//
// Única puerta a los datos de favoritos del cliente. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Recibe un ApiClient por constructor: en la app es ApiService, en pruebas
// FakeApiClient (test/fakes/).
//
// Fase 3: los métodos tipados (listarProductos) lanzan ApiException si el
// backend falla; los crudos siguen para las pantallas aún sin ViewModel.
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';

class FavoritosRepository {
  FavoritosRepository({ApiClient? api}) : _api = api ?? ApiService();

  final ApiClient _api;

  /// GET /favoritos/ids: solo ids (para pintar corazones).
  Future<Map<String, dynamic>> ids() => _api.getAuth(ApiConstants.favoritosIds);

  /// GET /favoritos: productos completos.
  Future<Map<String, dynamic>> listar() => _api.getAuth(ApiConstants.favoritos);

  /// GET /favoritos tipado. Acepta la lista en `favoritos` o `data`; ignora
  /// elementos que no sean objetos. Se marcan disponibles (`activo`: el
  /// backend no manda el campo en este listado).
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

  /// POST /favoritos/:id
  Future<Map<String, dynamic>> agregar(String productoId) =>
      _api.postAuth(ApiConstants.favoritoById(productoId), {});

  /// DELETE /favoritos/:id
  Future<Map<String, dynamic>> quitar(String productoId) =>
      _api.deleteAuth(ApiConstants.favoritoById(productoId));
}
