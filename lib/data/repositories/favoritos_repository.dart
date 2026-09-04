// lib/data/repositories/favoritos_repository.dart
//
// Única puerta a los datos de favoritos del cliente. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Recibe un ApiClient por constructor: en la app es ApiService, en pruebas
// FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';

class FavoritosRepository {
  final ApiClient _api;
  FavoritosRepository({ApiClient? api}) : _api = api ?? ApiService();

  /// GET /favoritos/ids: solo ids (para pintar corazones).
  Future<Map<String, dynamic>> ids() => _api.getAuth(ApiConstants.favoritosIds);

  /// GET /favoritos: productos completos.
  Future<Map<String, dynamic>> listar() => _api.getAuth(ApiConstants.favoritos);

  /// POST /favoritos/:id
  Future<Map<String, dynamic>> agregar(String productoId) =>
      _api.postAuth(ApiConstants.favoritoById(productoId), {});

  /// DELETE /favoritos/:id
  Future<Map<String, dynamic>> quitar(String productoId) =>
      _api.deleteAuth(ApiConstants.favoritoById(productoId));
}
