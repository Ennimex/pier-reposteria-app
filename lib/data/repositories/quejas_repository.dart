// lib/data/repositories/quejas_repository.dart
//
// Única puerta a los datos de quejas y sugerencias. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Recibe un ApiClient por constructor: en la app es ApiService, en pruebas
// FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';

class QuejasRepository {
  final ApiClient _api;
  QuejasRepository({ApiClient? api}) : _api = api ?? ApiService();

  /// GET /quejas/mis-quejas
  Future<Map<String, dynamic>> misQuejas() => _api.getAuth(ApiConstants.misQuejas);

  /// POST /quejas: {tipo, categoria, asunto, descripcion, pedido_id?}
  Future<Map<String, dynamic>> crear(Map<String, dynamic> body) =>
      _api.postAuth(ApiConstants.crearQueja, body);
}
