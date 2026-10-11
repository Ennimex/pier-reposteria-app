// lib/data/repositories/notificaciones_repository.dart
//
// Única puerta a los datos de notificaciones del usuario. Tipado en la Fase 5
// de MVVM: devuelve modelos y lanza ApiException con el mensaje del backend.
// Contrato (Fase 3.5): vistas, ViewModels y providers dependen de esta
// clase abstracta; la implementación HTTP es NotificacionesRepositoryRemote, registrada
// una sola vez en lib/config/dependencies.dart.
import 'package:pier_pasteleria/domain/models/notificacion.dart';

abstract class NotificacionesRepository {
  /// GET /notificaciones: las 50 más recientes, la más nueva primero.
  Future<List<Notificacion>> listar();

  /// PUT /notificaciones/:id/leer
  Future<void> marcarLeida(String id);

  /// PUT /notificaciones/leer-todas
  Future<void> marcarTodasLeidas();
}
