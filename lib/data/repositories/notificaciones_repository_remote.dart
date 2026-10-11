// lib/data/repositories/notificaciones_repository_remote.dart
//
// Implementación HTTP de NotificacionesRepository. Recibe el ApiClient por constructor:
// en la app, el ApiService único de lib/config/dependencies.dart; en
// pruebas, FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/notificaciones_repository.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/domain/models/notificacion.dart';

/// Implementación de [NotificacionesRepository] contra el backend vía [ApiClient].
class NotificacionesRepositoryRemote implements NotificacionesRepository {
  NotificacionesRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<List<Notificacion>> listar() async {
    final r = _validar(
      await _api.getAuth(ApiConstants.notificaciones),
      'No se pudieron cargar tus notificaciones',
    );
    final lista = r['notificaciones'];
    if (lista is! List) return const [];
    return lista
        .whereType<Map<dynamic, dynamic>>()
        .map((j) => Notificacion.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  @override
  Future<void> marcarLeida(String id) => _marcar(
        ApiConstants.marcarNotificacionLeida(id),
        'No se pudo marcar la notificación como leída',
      );

  @override
  Future<void> marcarTodasLeidas() => _marcar(
        ApiConstants.notificacionesLeerTodas,
        'No se pudieron marcar como leídas',
      );

  /// PUT sin cuerpo que solo tiene que salir bien.
  Future<void> _marcar(String endpoint, String porDefecto) async =>
      _validar(await _api.putAuth(endpoint, {}), porDefecto);

  /// [r] si trae success: true; si no, ApiException con su mensaje (o
  /// [porDefecto]).
  static Map<String, dynamic> _validar(
      Map<String, dynamic> r, String porDefecto) {
    if (r['success'] == true) return r;
    throw ApiException(r['message']?.toString() ?? porDefecto);
  }
}
