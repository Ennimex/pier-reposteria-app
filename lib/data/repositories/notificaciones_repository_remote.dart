// lib/data/repositories/notificaciones_repository_remote.dart
//
// Implementación HTTP de NotificacionesRepository. Recibe el ApiClient por constructor:
// en la app, el ApiService único de lib/config/dependencies.dart; en
// pruebas, FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/notificaciones_repository.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';

/// Implementación de [NotificacionesRepository] contra el backend vía [ApiClient].
class NotificacionesRepositoryRemote implements NotificacionesRepository {
  NotificacionesRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> listar() => _api.getAuth(ApiConstants.notificaciones);

  @override
  Future<Map<String, dynamic>> marcarLeida(String id) =>
      _api.putAuth(ApiConstants.marcarNotificacionLeida(id), {});

  @override
  Future<Map<String, dynamic>> marcarTodasLeidas() =>
      _api.putAuth(ApiConstants.notificacionesLeerTodas, {});
}
