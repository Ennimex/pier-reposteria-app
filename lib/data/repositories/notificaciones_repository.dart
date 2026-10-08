// lib/data/repositories/notificaciones_repository.dart
//
// Única puerta a los datos de notificaciones del usuario. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Recibe un ApiClient por constructor: en la app es ApiService, en pruebas
// FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';

class NotificacionesRepository {
  final ApiClient _api;
  NotificacionesRepository({ApiClient? api}) : _api = api ?? ApiService();

  /// GET /notificaciones
  Future<Map<String, dynamic>> listar() => _api.getAuth(ApiConstants.notificaciones);

  /// PUT /notificaciones/:id/leer
  Future<Map<String, dynamic>> marcarLeida(String id) =>
      _api.putAuth(ApiConstants.marcarNotificacionLeida(id), {});

  /// PUT /notificaciones/leer-todas
  Future<Map<String, dynamic>> marcarTodasLeidas() =>
      _api.putAuth(ApiConstants.notificacionesLeerTodas, {});
}
