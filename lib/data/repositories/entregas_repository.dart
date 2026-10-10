// lib/data/repositories/entregas_repository.dart
//
// Única puerta a los datos de entregas del repartidor. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Contrato (Fase 3.5): vistas, ViewModels y providers dependen de esta
// clase abstracta; la implementación HTTP es EntregasRepositoryRemote, registrada
// una sola vez en lib/config/dependencies.dart.

abstract class EntregasRepository {
  /// GET /entregas/mis-entregas (asignadas / en camino)
  Future<Map<String, dynamic>> misEntregas();

  /// GET /entregas/disponibilidad
  Future<Map<String, dynamic>> disponibilidad();

  /// PUT /entregas/disponibilidad
  Future<Map<String, dynamic>> cambiarDisponibilidad(bool disponible);

  /// GET /entregas/disponibles: pool de pedidos 'listo' a domicilio.
  Future<Map<String, dynamic>> disponibles();

  /// POST /entregas/aceptar: el primero que acepta gana (409 si ya se tomó).
  Future<Map<String, dynamic>> aceptar(String pedidoId);

  /// PUT /entregas/:id/estado: body {estado, evidencia_url?, motivo_fallo?}
  Future<Map<String, dynamic>> cambiarEstado(String entregaId, Map<String, dynamic> body);

  /// POST /entregas/:id/llegue: avisa al cliente sin cambiar estado.
  Future<Map<String, dynamic>> avisarLlegada(String entregaId);

  /// POST /upload/imagen (tipo entrega): evidencia de la entrega.
  Future<Map<String, dynamic>> subirEvidencia(String filePath);
}
