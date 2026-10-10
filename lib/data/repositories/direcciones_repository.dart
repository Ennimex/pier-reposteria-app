// lib/data/repositories/direcciones_repository.dart
//
// Única puerta a los datos de direcciones de entrega y zonas de envío. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Contrato (Fase 3.5): vistas, ViewModels y providers dependen de esta
// clase abstracta; la implementación HTTP es DireccionesRepositoryRemote, registrada
// una sola vez en lib/config/dependencies.dart.

abstract class DireccionesRepository {
  /// GET /direcciones (del cliente, con tarifa/cobertura por colonia)
  Future<Map<String, dynamic>> listar();

  /// POST /direcciones
  Future<Map<String, dynamic>> crear(Map<String, dynamic> body);

  /// PUT /direcciones/:id
  Future<Map<String, dynamic>> actualizar(String id, Map<String, dynamic> body);

  /// DELETE /direcciones/:id
  Future<Map<String, dynamic>> eliminar(String id);

  /// GET /zonas-envio/colonias (público): colonias con cobertura y tarifa.
  Future<Map<String, dynamic>> colonias();
}
