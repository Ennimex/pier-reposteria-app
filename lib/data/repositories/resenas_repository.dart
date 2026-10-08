// lib/data/repositories/resenas_repository.dart
//
// Única puerta a los datos de reseñas. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Recibe un ApiClient por constructor: en la app es ApiService, en pruebas
// FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';

class ResenasRepository {
  final ApiClient _api;
  ResenasRepository({ApiClient? api}) : _api = api ?? ApiService();

  /// GET /resenas/mis-resenas
  Future<Map<String, dynamic>> misResenas() => _api.getAuth(ApiConstants.misResenas);

  /// GET /resenas/destacadas (público, home)
  Future<Map<String, dynamic>> destacadas() => _api.get(ApiConstants.resenasDestacadas);

  /// GET /resenas/producto/:id (público, solo aprobadas)
  Future<Map<String, dynamic>> porProducto(String productoId) =>
      _api.get(ApiConstants.resenasPorProducto(productoId));

  /// POST /resenas: {producto_id, rating, titulo, comentario}
  Future<Map<String, dynamic>> crear(Map<String, dynamic> body) =>
      _api.postAuth(ApiConstants.crearResena, body);

  /// PUT /resenas/:id (solo la propia)
  Future<Map<String, dynamic>> editar(String id, Map<String, dynamic> body) =>
      _api.putAuth(ApiConstants.editarResena(id), body);

  /// POST /resenas/:id/like ("útil")
  Future<Map<String, dynamic>> like(String id) => _api.postAuth(ApiConstants.likeResena(id), {});
}
