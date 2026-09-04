// lib/data/repositories/reembolsos_repository.dart
//
// Única puerta a los datos de solicitudes de reembolso. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Recibe un ApiClient por constructor: en la app es ApiService, en pruebas
// FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';

class ReembolsosRepository {
  final ApiClient _api;
  ReembolsosRepository({ApiClient? api}) : _api = api ?? ApiService();

  /// GET /reembolsos/mis-reembolsos
  Future<Map<String, dynamic>> misReembolsos() => _api.getAuth(ApiConstants.misReembolsos);

  /// POST /reembolsos: {pedido_id, monto, motivo, descripcion, ...}
  Future<Map<String, dynamic>> crear(Map<String, dynamic> body) =>
      _api.postAuth(ApiConstants.crearReembolso, body);
}
