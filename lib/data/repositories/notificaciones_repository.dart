// lib/data/repositories/notificaciones_repository.dart
//
// Única puerta a los datos de notificaciones del usuario. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Contrato (Fase 3.5): vistas, ViewModels y providers dependen de esta
// clase abstracta; la implementación HTTP es NotificacionesRepositoryRemote, registrada
// una sola vez en lib/config/dependencies.dart.

abstract class NotificacionesRepository {
  /// GET /notificaciones
  Future<Map<String, dynamic>> listar();

  /// PUT /notificaciones/:id/leer
  Future<Map<String, dynamic>> marcarLeida(String id);

  /// PUT /notificaciones/leer-todas
  Future<Map<String, dynamic>> marcarTodasLeidas();
}
