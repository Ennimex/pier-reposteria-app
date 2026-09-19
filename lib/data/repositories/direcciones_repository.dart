// lib/data/repositories/direcciones_repository.dart
//
// Única puerta a los datos de direcciones de entrega y zonas de envío. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Recibe un ApiClient por constructor: en la app es ApiService, en pruebas
// FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';

class DireccionesRepository {
  final ApiClient _api;
  DireccionesRepository({ApiClient? api}) : _api = api ?? ApiService();

  /// GET /direcciones (del cliente, con tarifa/cobertura por colonia)
  Future<Map<String, dynamic>> listar() => _api.getAuth(ApiConstants.direcciones);

  /// POST /direcciones
  Future<Map<String, dynamic>> crear(Map<String, dynamic> body) =>
      _api.postAuth(ApiConstants.direcciones, body);

  /// PUT /direcciones/:id
  Future<Map<String, dynamic>> actualizar(String id, Map<String, dynamic> body) =>
      _api.putAuth(ApiConstants.direccionById(id), body);

  /// DELETE /direcciones/:id
  Future<Map<String, dynamic>> eliminar(String id) =>
      _api.deleteAuth(ApiConstants.direccionById(id));

  /// GET /zonas-envio/colonias (público): colonias con cobertura y tarifa.
  Future<Map<String, dynamic>> colonias() => _api.get(ApiConstants.zonasColonias);
}
